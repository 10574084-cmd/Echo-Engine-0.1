/*
 * Echo Engine web: "Are you using a phone?" question and on-screen controls.
 *
 * The game only understands the keyboard, so the on-screen buttons simply send the same key presses
 * (arrows = move / notes, Enter = accept / pause, Escape = back).
 *
 * The answer is remembered in localStorage. Add ?phone=1 or ?phone=0 to the address to force an answer,
 * or ?phone=ask to be asked again.
 */
(function () {
	'use strict';

	var STORAGE_KEY = 'echo.usesPhone';
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
			/* on-screen controls */
			'#echo-pad{position:fixed;inset:0;z-index:99990;pointer-events:none;-webkit-user-select:none;user-select:none;touch-action:none}' +
			'#echo-pad .b{position:absolute;pointer-events:auto;touch-action:none;display:flex;align-items:center;justify-content:center;' +
			'font-family:"VCR OSD Mono",monospace,sans-serif;font-size:28px;color:#fff;background:rgba(255,255,255,.18);' +
			'border:3px solid rgba(255,255,255,.55);border-radius:16px;box-sizing:border-box;-webkit-tap-highlight-color:transparent}' +
			'#echo-pad .b.on{background:rgba(255,255,255,.55)}' +
			'#echo-pad .b.play{background:rgba(255,255,255,.10);border-color:rgba(255,255,255,.35)}' +
			'#echo-pad .b.play.on{background:rgba(255,255,255,.45)}' +
			'#echo-pad .menu,#echo-pad .play{display:none}' +
			'#echo-pad.is-menu .menu{display:flex}' +
			'#echo-pad.is-play .play{display:flex}' +
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
			'<div class="echo-small">You will only be asked once. Keyboard: Y = yes, N = no.</div>' +
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
		if (isPhone) startPhoneMode(true);
	}

	// ---------------------------------------------------------------------------------------------
	// On-screen controls
	// ---------------------------------------------------------------------------------------------

	function addButton(parent, cls, label, keyName, style) {
		var def = KEYS[keyName];
		var el = document.createElement('div');
		el.className = 'b ' + cls;
		el.textContent = label;
		for (var k in style) el.style[k] = style[k];
		var active = {}; // pointer ids holding this button down
		var count = 0;
		var pressedAt = 0;

		function down(e) {
			e.preventDefault();
			if (active[e.pointerId]) return;
			active[e.pointerId] = true;
			if (count++ === 0) { pressedAt = Date.now(); sendKey('keydown', def); el.classList.add('on'); }
			try { el.setPointerCapture(e.pointerId); } catch (err) {}
		}
		function up(e) {
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
		el.addEventListener('pointerup', up);
		el.addEventListener('pointercancel', up);
		el.addEventListener('lostpointercapture', up);
		el.addEventListener('contextmenu', function (e) { e.preventDefault(); });
		parent.appendChild(el);
		return el;
	}

	function buildPad() {
		if (root) return;
		root = document.createElement('div');
		root.id = 'echo-pad';
		root.className = 'is-menu';

		var S = 'min(17vmin, 110px)';  // size of a menu button
		// menu: d-pad on the left, A / B on the right
		addButton(root, 'menu', '▲', 'up', { left: 'calc(3vmin + ' + S + ')', bottom: 'calc(3vmin + ' + S + ' * 2)', width: S, height: S });
		addButton(root, 'menu', '▼', 'down', { left: 'calc(3vmin + ' + S + ')', bottom: '3vmin', width: S, height: S });
		addButton(root, 'menu', '◀', 'left', { left: '3vmin', bottom: 'calc(3vmin + ' + S + ')', width: S, height: S });
		addButton(root, 'menu', '▶', 'right', { left: 'calc(3vmin + ' + S + ' * 2)', bottom: 'calc(3vmin + ' + S + ')', width: S, height: S });
		addButton(root, 'menu', 'OK', 'enter', { right: '3vmin', bottom: 'calc(3vmin + ' + S + ')', width: S, height: S });
		addButton(root, 'menu', 'BACK', 'escape', { right: 'calc(3vmin + ' + S + ' * 1.2)', bottom: '3vmin', width: 'calc(' + S + ' * 1.2)', height: 'calc(' + S + ' * 0.8)', fontSize: '20px' });

		// song: four big note buttons along the bottom + a pause button
		var names = [['left', '◀'], ['down', '▼'], ['up', '▲'], ['right', '▶']];
		for (var i = 0; i < 4; i++) {
			addButton(root, 'play', names[i][1], names[i][0], {
				left: (i * 25 + 0.7) + '%', width: '23.6%', bottom: '2vmin', height: '28vh', fontSize: '40px'
			});
		}
		addButton(root, 'play', 'II', 'enter', { right: '2vmin', top: '2vmin', width: 'min(12vmin, 80px)', height: 'min(12vmin, 80px)', fontSize: '24px' });

		document.body.appendChild(root);
	}

	function setPlaying(value) {
		playing = !!value;
		if (root) root.className = playing ? 'is-play' : 'is-menu';
	}

	function startPhoneMode(userGesture) {
		buildPad();
		setPlaying(playing);

		// "rotate your phone" notice (the game is landscape)
		var rotate = document.createElement('div');
		rotate.id = 'echo-rotate';
		rotate.textContent = 'Please rotate your phone to landscape';
		document.body.appendChild(rotate);
		function check() { rotate.style.display = window.innerHeight > window.innerWidth ? 'flex' : 'none'; }
		window.addEventListener('resize', check);
		window.addEventListener('orientationchange', check);
		check();

		// fullscreen + landscape lock where the browser allows it (needs the tap that answered the question)
		if (userGesture) {
			try {
				var el = document.documentElement;
				var req = el.requestFullscreen || el.webkitRequestFullscreen;
				if (req) {
					var p = req.call(el);
					var lock = function () { try { screen.orientation.lock('landscape').catch(function () {}); } catch (e) {} };
					if (p && p.then) p.then(lock, function () {}); else lock();
				}
			} catch (e) {}
		}
	}

	// the game tells which kind of buttons to show
	window.EchoTouch = { setPlaying: setPlaying };

	// ---------------------------------------------------------------------------------------------

	function init() {
		css();
		var forced = param('phone');
		if (forced === '1') { store('1'); }
		else if (forced === '0') { store('0'); }
		var saved = forced === 'ask' ? null : load();

		if (saved === '1') startPhoneMode(false);
		else if (saved === '0') { /* computer: nothing to do */ }
		else ask();
	}

	if (document.body) init();
	else document.addEventListener('DOMContentLoaded', init);
})();
