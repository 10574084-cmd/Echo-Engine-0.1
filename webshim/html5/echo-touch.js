/*
 * Echo Engine web: "Are you using a phone?" question and on-screen controls.
 *
 * The game only understands the keyboard, so the on-screen buttons simply send the same key presses
 * (arrows = move / notes, Enter = accept / pause, Escape = back).
 *
 * The settings (enabled, size, spacing, opacity, layout, vibration, landscape, gesture guard and the custom
 * button positions) are remembered in localStorage and can be changed from the game: Options > Echo Extra >
 * Touch Controls (through webfs.TouchBridge).
 *
 * Add ?phone=1 or ?phone=0 to the address to force an answer, or ?phone=ask to be asked again.
 */
(function () {
	'use strict';

	var STORAGE_KEY = 'echo.usesPhone';
	var CFG_KEY = 'echo.touch';
	var DEFAULTS = {
		enabled: null,       // null = not decided yet (follows the "Are you using a phone?" answer)
		size: 1, gap: 1, alpha: 0.35,
		layout: 'Classic',   // Classic | Compact | Custom
		vibration: false, landscape: true, guard: true,
		custom: {}           // button id -> { x, y } as fractions of the screen (top-left corner)
	};
	var KEYS = {
		left: { code: 'ArrowLeft', key: 'ArrowLeft', keyCode: 37 },
		down: { code: 'ArrowDown', key: 'ArrowDown', keyCode: 40 },
		up: { code: 'ArrowUp', key: 'ArrowUp', keyCode: 38 },
		right: { code: 'ArrowRight', key: 'ArrowRight', keyCode: 39 },
		enter: { code: 'Enter', key: 'Enter', keyCode: 13 },
		escape: { code: 'Escape', key: 'Escape', keyCode: 27 }
	};

	var MIN_PRESS_MS = 100;
	var overlayOpen = false;
	var root = null;      // container of the on-screen controls
	var playing = false;  // true while a song is being played (note buttons instead of the d-pad)
	var buttons = [];     // { id, set: 'menu' | 'play', el }
	var rotate = null;
	var editing = false, editSet = 'menu', editBar = null, work = null;
	var fsArmed = false;

	function store(value) {
		try { window.localStorage.setItem(STORAGE_KEY, value); } catch (e) {}
	}
	function load() {
		try { return window.localStorage.getItem(STORAGE_KEY); } catch (e) { return null; }
	}
	function param(name) {
		var m = new RegExp('[?&]' + name + '=([^&#]*)').exec(window.location.search);
		return m ? decodeURIComponent(m[1]) : null;
	}

	// ---------------------------------------------------------------------------------------------
	// Settings
	// ---------------------------------------------------------------------------------------------

	function defaults() {
		var c = {};
		for (var k in DEFAULTS) c[k] = DEFAULTS[k];
		c.custom = {};
		return c;
	}
	function loadCfg() {
		var c = defaults();
		try {
			var raw = window.localStorage.getItem(CFG_KEY);
			if (raw) {
				var o = JSON.parse(raw);
				for (var k in o) if (k in DEFAULTS && o[k] !== undefined) c[k] = o[k];
			}
		} catch (e) {}
		if (c.enabled === null) c.enabled = load() === '1';
		if (!c.custom || typeof c.custom !== 'object') c.custom = {};
		return c;
	}
	var cfg = loadCfg();
	function saveCfg() {
		try { window.localStorage.setItem(CFG_KEY, JSON.stringify(cfg)); } catch (e) {}
	}
	function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

	// ---------------------------------------------------------------------------------------------
	// Keys
	// ---------------------------------------------------------------------------------------------

	function sendKey(type, def) {
		var event = new KeyboardEvent(type, { key: def.key, code: def.code, bubbles: true, cancelable: true });
		// Chrome/Safari ignore keyCode in the constructor, and the engine reads keyCode
		try {
			Object.defineProperty(event, 'keyCode', { get: function () { return def.keyCode; } });
			Object.defineProperty(event, 'which', { get: function () { return def.keyCode; } });
		} catch (e) {}
		window.dispatchEvent(event);
	}

	// While the question is on screen the keyboard must not reach the game (Enter would skip its first screen)
	function blockKeys(event) {
		if (!overlayOpen || !event.isTrusted) return;
		event.stopImmediatePropagation();
		event.preventDefault();
		if (event.type === 'keydown') {
			if (event.key === 'y' || event.key === 'Y') answer(true);
			else if (event.key === 'n' || event.key === 'N' || event.key === 'Enter') answer(false);
		}
	}
	window.addEventListener('keydown', blockKeys, true);
	window.addEventListener('keyup', blockKeys, true);

	// ---------------------------------------------------------------------------------------------
	// The question
	// ---------------------------------------------------------------------------------------------

	var overlay = null;

	function css() {
		var style = document.createElement('style');
		style.textContent =
			'.echo-overlay{position:fixed;inset:0;z-index:100000;background:#000;color:#fff;display:flex;align-items:center;justify-content:center;' +
			'font-family:"VCR OSD Mono",monospace,sans-serif;text-align:center;padding:16px;box-sizing:border-box;-webkit-user-select:none;user-select:none}' +
			'.echo-card{max-width:560px;width:100%}' +
			'.echo-card h1{font-size:34px;margin:0 0 6px;letter-spacing:1px}' +
			'.echo-card p{font-size:16px;line-height:1.4;color:#bbb;margin:10px 0 22px}' +
			'.echo-btn{display:block;width:100%;box-sizing:border-box;margin:12px 0;padding:18px 12px;font:inherit;font-size:22px;color:#fff;' +
			'background:#222;border:3px solid #fff;border-radius:10px;cursor:pointer;touch-action:manipulation}' +
			'.echo-btn:hover,.echo-btn:focus{background:#444;outline:none}' +
			'.echo-btn.main{background:#2a6ed8;border-color:#9cf}' +
			'.echo-small{font-size:13px;color:#888}' +
			/* on-screen controls: the opacity of the whole pad is the "Button Opacity" setting */
			'#echo-pad{position:fixed;inset:0;z-index:99990;pointer-events:none;-webkit-user-select:none;user-select:none;touch-action:none;display:none}' +
			'#echo-pad .b{position:absolute;pointer-events:auto;touch-action:none;display:none;align-items:center;justify-content:center;' +
			'font-family:"VCR OSD Mono",monospace,sans-serif;color:#fff;background:rgba(255,255,255,.5);' +
			'border:3px solid rgba(255,255,255,1);border-radius:16px;box-sizing:border-box;-webkit-tap-highlight-color:transparent}' +
			'#echo-pad .b.on{background:rgba(255,255,255,1);color:#000}' +
			'#echo-pad.is-menu .menu{display:flex}' +
			'#echo-pad.is-play .play{display:flex}' +
			'#echo-pad.editing .b{outline:2px dashed #ffd24a;cursor:grab}' +
			'#echo-pad.editing{opacity:1!important}' +
			'#echo-edit{position:fixed;top:8px;left:50%;transform:translateX(-50%);z-index:100002;display:flex;gap:8px;align-items:center;flex-wrap:wrap;justify-content:center;' +
			'background:rgba(0,0,0,.85);border:2px solid #ffd24a;border-radius:10px;padding:8px 10px;color:#fff;font-family:"VCR OSD Mono",monospace,sans-serif;font-size:15px}' +
			'#echo-edit button{font:inherit;color:#fff;background:#2a6ed8;border:2px solid #9cf;border-radius:8px;padding:8px 12px;touch-action:manipulation}' +
			'#echo-edit button.no{background:#444;border-color:#aaa}' +
			'#echo-rotate{position:fixed;inset:0;z-index:100001;background:#000;color:#fff;display:none;align-items:center;justify-content:center;' +
			'text-align:center;font-family:"VCR OSD Mono",monospace,sans-serif;font-size:24px;padding:24px}';
		document.head.appendChild(style);
	}

	function ask() {
		overlayOpen = true;
		overlay = document.createElement('div');
		overlay.className = 'echo-overlay';
		var touchy = (navigator.maxTouchPoints || 0) > 0 && window.matchMedia && window.matchMedia('(pointer:coarse)').matches;
		overlay.innerHTML =
			'<div class="echo-card">' +
			'<h1>Are you using a phone?</h1>' +
			'<p>Phones get on-screen buttons so the game can be played without a keyboard.</p>' +
			'<button class="echo-btn' + (touchy ? ' main' : '') + '" id="echo-yes">Yes, I am on a phone</button>' +
			'<button class="echo-btn' + (touchy ? '' : ' main') + '" id="echo-no">No, I am on a computer</button>' +
			'<div class="echo-small">You will only be asked once. Keyboard: Y = yes, N = no.<br>You can change it later in Options &gt; Echo Extra &gt; Touch Controls.</div>' +
			'</div>';
		document.body.appendChild(overlay);
		document.getElementById('echo-yes').addEventListener('click', function () { answer(true); });
		document.getElementById('echo-no').addEventListener('click', function () { answer(false); });
	}

	function answer(isPhone) {
		if (!overlayOpen) return;
		overlayOpen = false;
		if (overlay && overlay.parentNode) overlay.parentNode.removeChild(overlay);
		store(isPhone ? '1' : '0');
		cfg.enabled = isPhone;
		saveCfg();
		fsArmed = isPhone && cfg.landscape;
		refresh();
		if (isPhone) goLandscape(); // this tap is the user gesture the browser wants
	}

	// ---------------------------------------------------------------------------------------------
	// Layout
	// ---------------------------------------------------------------------------------------------

	var NOTE_KEYS = ['left', 'down', 'up', 'right'];
	var NOTE_LABELS = ['◀', '▼', '▲', '▶'];

	/** Rectangles (px) of every button for the current layout, size and spacing. */
	function rects() {
		var W = window.innerWidth, H = window.innerHeight, vmin = Math.min(W, H);
		var compact = cfg.layout === 'Compact';
		var u = Math.min(0.17 * vmin, 110) * cfg.size * (compact ? 0.8 : 1);
		var g = 0.012 * vmin * cfg.gap;
		var s = u + g;
		var pad = 0.03 * vmin;
		var mx = compact ? Math.max(pad, 0.1 * W) : pad;
		var r = {};

		// menu: d-pad on the left, OK / BACK on the right
		var by = H - pad - u;
		r.down = { x: mx + s, y: by, w: u, h: u };
		r.left = { x: mx, y: by - s, w: u, h: u };
		r.right = { x: mx + 2 * s, y: by - s, w: u, h: u };
		r.up = { x: mx + s, y: by - 2 * s, w: u, h: u };
		var rx = W - mx;
		r.back = { x: rx - 1.2 * u, y: H - pad - 0.8 * u, w: 1.2 * u, h: 0.8 * u };
		r.ok = { x: rx - u, y: r.back.y - g - u, w: u, h: u };

		// song: four note buttons along the bottom + a pause button
		var nb = H - 0.02 * vmin;
		var nh = Math.min((compact ? 0.2 : 0.28) * H * cfg.size, 0.6 * H);
		var cell = W * 0.986 / 4;
		var bw = compact ? Math.min(cell - g, 0.13 * W * cfg.size) : cell - g;
		var total = 4 * bw + 3 * g;
		var start = compact ? (W - total) / 2 : W * 0.007 + g / 2;
		for (var i = 0; i < 4; i++) {
			r['n' + i] = { x: start + i * (compact ? bw + g : cell), y: nb - nh, w: bw, h: nh };
		}
		var p = Math.min(0.12 * vmin, 80) * cfg.size;
		r.pause = { x: W - 0.02 * vmin - p, y: 0.02 * vmin, w: p, h: p };

		// custom positions (the size and spacing settings still apply)
		var pos = editing ? work : (cfg.layout === 'Custom' ? cfg.custom : null);
		if (pos) {
			for (var id in r) {
				var c = pos[id];
				if (c && isFinite(c.x) && isFinite(c.y)) {
					r[id].x = clamp(c.x * W, 0, Math.max(0, W - r[id].w));
					r[id].y = clamp(c.y * H, 0, Math.max(0, H - r[id].h));
				}
			}
		}
		return r;
	}

	function applyLayout() {
		if (!root) return;
		var r = rects();
		root.style.opacity = String(clamp(cfg.alpha, 0.05, 1));
		buttons.forEach(function (b) {
			var q = r[b.id];
			var st = b.el.style;
			st.left = Math.round(q.x) + 'px';
			st.top = Math.round(q.y) + 'px';
			st.width = Math.round(q.w) + 'px';
			st.height = Math.round(q.h) + 'px';
			var label = b.el.textContent.length > 2 ? 0.26 : 0.34;
			st.fontSize = Math.max(12, Math.round(Math.min(q.w, q.h) * label)) + 'px';
		});
	}

	function refresh() {
		ensureRoot();
		var show = (cfg.enabled || editing) && !overlayOpen;
		root.style.display = show ? 'block' : 'none';
		root.className = (editing ? 'editing ' : '') + 'is-' + (editing ? editSet : (playing ? 'play' : 'menu'));
		applyLayout();
		applyGuard();
		checkRotate();
	}

	function ensureRoot() {
		if (!root) buildPad();
	}

	// ---------------------------------------------------------------------------------------------
	// Buttons
	// ---------------------------------------------------------------------------------------------

	function addButton(id, set, label, keyName) {
		var def = KEYS[keyName];
		var el = document.createElement('div');
		el.className = 'b ' + set;
		el.textContent = label;
		var active = {}; // pointer ids holding this button down
		var count = 0;
		var pressedAt = 0;
		var drag = null;

		function down(e) {
			e.preventDefault();
			try { el.setPointerCapture(e.pointerId); } catch (err) {}
			if (editing) {
				var q = el.getBoundingClientRect();
				drag = { pid: e.pointerId, dx: e.clientX - q.left, dy: e.clientY - q.top };
				return;
			}
			if (active[e.pointerId]) return;
			active[e.pointerId] = true;
			if (count++ === 0) {
				pressedAt = Date.now();
				sendKey('keydown', def);
				el.classList.add('on');
				if (cfg.vibration && navigator.vibrate) { try { navigator.vibrate(12); } catch (err) {} }
				if (fsArmed) goLandscape();
			}
		}
		function move(e) {
			if (!editing || !drag || drag.pid !== e.pointerId) return;
			var W = window.innerWidth, H = window.innerHeight;
			var w = el.offsetWidth, h = el.offsetHeight;
			var x = clamp(e.clientX - drag.dx, 0, Math.max(0, W - w));
			var y = clamp(e.clientY - drag.dy, 0, Math.max(0, H - h));
			work[id] = { x: x / W, y: y / H };
			el.style.left = Math.round(x) + 'px';
			el.style.top = Math.round(y) + 'px';
		}
		function up(e) {
			if (drag && drag.pid === e.pointerId) { drag = null; return; }
			if (!active[e.pointerId]) return;
			delete active[e.pointerId];
			if (--count === 0) {
				el.classList.remove('on');
				// the game reads the keyboard once per frame: a very short tap must stay "down" long enough to be seen
				var wait = Math.max(0, MIN_PRESS_MS - (Date.now() - pressedAt));
				if (wait === 0) sendKey('keyup', def);
				else setTimeout(function () { if (count === 0) sendKey('keyup', def); }, wait);
			}
		}
		el.addEventListener('pointerdown', down);
		el.addEventListener('pointermove', move);
		el.addEventListener('pointerup', up);
		el.addEventListener('pointercancel', up);
		el.addEventListener('lostpointercapture', up);
		el.addEventListener('contextmenu', function (e) { e.preventDefault(); });
		root.appendChild(el);
		buttons.push({ id: id, set: set, el: el });
	}

	function buildPad() {
		if (root) return;
		root = document.createElement('div');
		root.id = 'echo-pad';

		addButton('up', 'menu', '▲', 'up');
		addButton('down', 'menu', '▼', 'down');
		addButton('left', 'menu', '◀', 'left');
		addButton('right', 'menu', '▶', 'right');
		addButton('ok', 'menu', 'OK', 'enter');
		addButton('back', 'menu', 'BACK', 'escape');
		for (var i = 0; i < 4; i++) addButton('n' + i, 'play', NOTE_LABELS[i], NOTE_KEYS[i]);
		addButton('pause', 'play', 'II', 'enter');

		document.body.appendChild(root);
		window.addEventListener('resize', function () { applyLayout(); checkRotate(); });
		window.addEventListener('orientationchange', function () { setTimeout(function () { applyLayout(); checkRotate(); }, 200); });
	}

	function setPlaying(value) {
		playing = !!value;
		if (root) refresh();
	}

	// ---------------------------------------------------------------------------------------------
	// Editing the positions
	// ---------------------------------------------------------------------------------------------

	function startEdit() {
		if (editing) return;
		ensureRoot();
		var r = rects(), W = window.innerWidth, H = window.innerHeight;
		work = {};
		for (var id in r) work[id] = { x: r[id].x / W, y: r[id].y / H };
		editing = true;
		editSet = playing ? 'play' : 'menu';

		editBar = document.createElement('div');
		editBar.id = 'echo-edit';
		editBar.innerHTML =
			'<span id="echo-edit-label"></span>' +
			'<button id="echo-edit-swap"></button>' +
			'<button id="echo-edit-done">DONE</button>' +
			'<button id="echo-edit-cancel" class="no">CANCEL</button>';
		document.body.appendChild(editBar);
		function label() {
			document.getElementById('echo-edit-label').textContent = 'Drag the ' + (editSet === 'menu' ? 'MENU' : 'SONG') + ' buttons';
			document.getElementById('echo-edit-swap').textContent = editSet === 'menu' ? 'Show SONG buttons' : 'Show MENU buttons';
		}
		label();
		document.getElementById('echo-edit-swap').addEventListener('click', function () {
			editSet = editSet === 'menu' ? 'play' : 'menu';
			label();
			refresh();
		});
		document.getElementById('echo-edit-done').addEventListener('click', function () { stopEdit(true); });
		document.getElementById('echo-edit-cancel').addEventListener('click', function () { stopEdit(false); });
		refresh();
	}

	function stopEdit(save) {
		if (!editing) return;
		if (save) {
			cfg.custom = work;
			cfg.layout = 'Custom';
			saveCfg();
		}
		editing = false;
		work = null;
		if (editBar && editBar.parentNode) editBar.parentNode.removeChild(editBar);
		editBar = null;
		refresh();
	}

	// ---------------------------------------------------------------------------------------------
	// Landscape, rotate notice and gesture guard
	// ---------------------------------------------------------------------------------------------

	function goLandscape() {
		fsArmed = false;
		if (!cfg.enabled || !cfg.landscape) return;
		try {
			var el = document.documentElement;
			var req = el.requestFullscreen || el.webkitRequestFullscreen;
			if (req && !document.fullscreenElement && !document.webkitFullscreenElement) {
				var p = req.call(el);
				var lock = function () { try { screen.orientation.lock('landscape').catch(function () {}); } catch (e) {} };
				if (p && p.then) p.then(lock, function () {}); else lock();
			} else {
				try { screen.orientation.lock('landscape').catch(function () {}); } catch (e) {}
			}
		} catch (e) {}
	}

	function checkRotate() {
		if (!rotate) {
			rotate = document.createElement('div');
			rotate.id = 'echo-rotate';
			rotate.textContent = 'Please rotate your phone to landscape';
			document.body.appendChild(rotate);
		}
		var portrait = window.innerHeight > window.innerWidth;
		rotate.style.display = (cfg.enabled && cfg.landscape && portrait && !overlayOpen) ? 'flex' : 'none';
	}

	var guardStyle = null;
	function guardOn() { return cfg.enabled && cfg.guard; }
	function applyGuard() {
		if (guardOn() && !guardStyle) {
			guardStyle = document.createElement('style');
			// no pull-to-refresh / overscroll, no touch scrolling or zooming of the page, no long-press menu
			guardStyle.textContent = 'html,body{overscroll-behavior:none;touch-action:none;-webkit-touch-callout:none;-webkit-user-select:none;user-select:none}';
			document.head.appendChild(guardStyle);
		} else if (!guardOn() && guardStyle) {
			if (guardStyle.parentNode) guardStyle.parentNode.removeChild(guardStyle);
			guardStyle = null;
		}
	}
	document.addEventListener('touchmove', function (e) {
		if (guardOn() && e.touches && e.touches.length > 1) e.preventDefault(); // pinch zoom
	}, { passive: false });
	['gesturestart', 'gesturechange', 'gestureend'].forEach(function (n) {
		document.addEventListener(n, function (e) { if (guardOn()) e.preventDefault(); }); // iOS pinch
	});
	document.addEventListener('contextmenu', function (e) { if (guardOn()) e.preventDefault(); });
	window.addEventListener('beforeunload', function (e) {
		if (guardOn() && playing) { e.preventDefault(); e.returnValue = ''; return ''; }
	});

	// ---------------------------------------------------------------------------------------------
	// What the game can ask for
	// ---------------------------------------------------------------------------------------------

	function get(key) {
		if (key === 'enabled') return !!cfg.enabled;
		return key in DEFAULTS ? cfg[key] : null;
	}

	function set(key, value) {
		if (!(key in DEFAULTS) || key === 'custom') return;
		if (key === 'size') value = clamp(Number(value) || 1, 0.5, 1.6);
		else if (key === 'gap') value = clamp(Number(value), 0, 2);
		else if (key === 'alpha') value = clamp(Number(value) || 0.35, 0.1, 1);
		else if (key === 'layout') value = (value === 'Compact' || value === 'Custom') ? value : 'Classic';
		else value = !!value;
		cfg[key] = value;
		saveCfg();
		if (key === 'enabled') { store(value ? '1' : '0'); fsArmed = value && cfg.landscape; }
		if (key === 'landscape') fsArmed = value && cfg.enabled;
		if (key === 'vibration' && value && navigator.vibrate) { try { navigator.vibrate(30); } catch (e) {} }
		refresh();
	}

	function reset() {
		var keepEnabled = cfg.enabled;
		cfg = defaults();
		cfg.enabled = keepEnabled;
		saveCfg();
		refresh();
	}

	window.EchoTouch = { setPlaying: setPlaying, get: get, set: set, edit: startEdit, reset: reset };

	// ---------------------------------------------------------------------------------------------

	function init() {
		css();
		var forced = param('phone');
		if (forced === '1') { store('1'); cfg.enabled = true; saveCfg(); }
		else if (forced === '0') { store('0'); cfg.enabled = false; saveCfg(); }
		var saved = forced === 'ask' ? null : load();

		if (saved === null && forced !== '0' && forced !== '1') { ask(); }
		fsArmed = !!(cfg.enabled && cfg.landscape);
		refresh();
	}

	if (document.body) init();
	else document.addEventListener('DOMContentLoaded', init);
})();
