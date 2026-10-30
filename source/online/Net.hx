package online;

#if html5
import js.Browser;

/**
 * Peer to peer link between two browsers (WebRTC through PeerJS).
 *
 * The site is static (GitHub Pages), so there is no game server: a room code is simply the PeerJS id of the host.
 * PeerJS' public signalling server only helps the two browsers find each other; the game data goes directly between them.
 * The PeerJS script is loaded the first time the online mode is opened.
 *
 * `window.ECHO_ONLINE` can override `scripts` (urls to try) and `peerOptions` (e.g. another signalling server).
 */
class Net
{
	static inline var ID_PREFIX = 'echoengine-';
	static inline var CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
	static inline var CONNECT_TIMEOUT_MS = 20000;

	static var peer:Dynamic = null;
	static var conn:Dynamic = null;
	static var generation = 0; // makes callbacks of an old (closed) link harmless

	public static var connected(default, null):Bool = false;

	/** Called with every message received from the other player. */
	public static var onMessage:Dynamic->Void = null;
	/** Called when the link drops (or the other player leaves) after having been open. */
	public static var onClose:Void->Void = null;

	/** SHA-384 of peerjs@1.5.4/dist/peerjs.min.js: the browser refuses the script if the CDN (or anything in between) changed it. */
	static inline var PEERJS_INTEGRITY = 'sha384-OLBgp1GsljhM2TJ+sbHjaiH9txEUvgdDTAzHv2P24donTt6/529l+9Ua0vFImLlb';

	/**
	 * `window.ECHO_ONLINE` is only honoured when the game runs from this very computer (development). On the public site a
	 * userscript or an extension could otherwise point the game to another script or signalling server.
	 */
	static function config():Dynamic
	{
		var host = Browser.location.hostname;
		var local = host == 'localhost' || host == '127.0.0.1' || host == '[::1]';
		var c:Dynamic = local ? untyped Browser.window.ECHO_ONLINE : null;
		return c != null ? c : {};
	}

	/** Loads the PeerJS script (once). `done(null)` on success, `done(error)` otherwise. */
	public static function loadLibrary(done:String->Void):Void
	{
		if (untyped Browser.window.Peer != null)
		{
			done(null);
			return;
		}

		var urls:Array<String> = config().scripts;
		if (urls == null)
			urls = [
				'https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js',
				'https://cdn.jsdelivr.net/npm/peerjs@1.5.4/dist/peerjs.min.js'
			];

		var tryNext:Void->Void = null;
		var index = 0;
		tryNext = function()
		{
			if (index >= urls.length)
			{
				done('Could not load the online library (is the network blocking it?)');
				return;
			}
			var script = Browser.document.createScriptElement();
			script.src = urls[index++];
			if (config().scripts == null)
			{
				// the default (pinned) library is verified; a development override is not
				script.setAttribute('integrity', PEERJS_INTEGRITY);
				script.setAttribute('crossorigin', 'anonymous');
			}
			script.onload = function(_)
			{
				if (untyped Browser.window.Peer != null) done(null);
				else tryNext();
			};
			script.onerror = function(_) tryNext();
			Browser.document.head.appendChild(script);
		};
		tryNext();
	}

	static function newCode():String
	{
		var code = '';
		for (_ in 0...5)
			code += CODE_CHARS.charAt(Std.random(CODE_CHARS.length));
		return code;
	}

	static function createPeer(id:String):Dynamic
	{
		var options:Dynamic = config().peerOptions;
		if (options == null) options = {};
		return js.Syntax.code("new window.Peer({0}, {1})", id, options);
	}

	/** Normalises what the player typed ("abc 23" -> "ABC23"). */
	public static function cleanCode(text:String):String
	{
		if (text == null) return '';
		var out = '';
		for (i in 0...text.length)
		{
			var c = text.charAt(i).toUpperCase();
			if (CODE_CHARS.indexOf(c) >= 0) out += c;
		}
		return out;
	}

	// ------------------------------------------------------------------------------------------
	// Host
	// ------------------------------------------------------------------------------------------

	/**
	 * Opens a room. `onReady(code, null)` once the code can be shared, `onJoined()` when the other player connected,
	 * `onFail(message)` if something went wrong.
	 */
	public static function host(onReady:String->Void, onJoined:Void->Void, onFail:String->Void):Void
	{
		close();
		var gen = generation;
		var attempts = 0;

		var open:Void->Void = null;
		open = function()
		{
			var code = newCode();
			var p = createPeer(ID_PREFIX + code);
			peer = p;
			var ready = false;

			p.on('open', function(_)
			{
				if (gen != generation) return;
				ready = true;
				onReady(code);
			});
			p.on('connection', function(c:Dynamic)
			{
				if (gen != generation) return;
				if (conn != null)
				{
					// the room is for two players only
					c.on('open', function() c.close());
					return;
				}
				attach(c, gen, onJoined);
			});
			p.on('error', function(e:Dynamic)
			{
				if (gen != generation) return;
				if (e.type == 'unavailable-id' && !ready && attempts++ < 5)
				{
					p.destroy();
					open();
					return;
				}
				onFail(describe(e));
			});
		};
		open();
	}

	// ------------------------------------------------------------------------------------------
	// Guest
	// ------------------------------------------------------------------------------------------

	public static function join(code:String, onJoined:Void->Void, onFail:String->Void):Void
	{
		close();
		var gen = generation;
		code = cleanCode(code);
		if (code.length < 3)
		{
			onFail('That is not a room code.');
			return;
		}

		var p = createPeer(null);
		peer = p;
		var done = false;
		var timeout = Browser.window.setTimeout(function()
		{
			if (gen != generation || done) return;
			onFail('The room did not answer. Check the code (and that the host is still waiting).');
		}, CONNECT_TIMEOUT_MS);

		p.on('open', function(_)
		{
			if (gen != generation) return;
			var c = p.connect(ID_PREFIX + code, {reliable: true, serialization: 'json'});
			attach(c, gen, function()
			{
				done = true;
				Browser.window.clearTimeout(timeout);
				onJoined();
			});
			c.on('error', function(e:Dynamic)
			{
				if (gen == generation && !done) onFail(describe(e));
			});
		});
		p.on('error', function(e:Dynamic)
		{
			if (gen != generation || done) return;
			Browser.window.clearTimeout(timeout);
			onFail(e.type == 'peer-unavailable' ? 'There is no room with that code.' : describe(e));
		});
	}

	// ------------------------------------------------------------------------------------------

	static function attach(c:Dynamic, gen:Int, onOpen:Void->Void):Void
	{
		conn = c;
		var opened = false;
		var open = function()
		{
			if (gen != generation || opened) return;
			opened = true;
			connected = true;
			onOpen();
		};
		c.on('open', open);
		if (c.open == true) open();
		c.on('data', function(data:Dynamic)
		{
			if (gen == generation && onMessage != null) onMessage(data);
		});
		c.on('close', function()
		{
			if (gen != generation) return;
			var wasOpen = connected;
			connected = false;
			conn = null;
			if (wasOpen && onClose != null) onClose();
		});
	}

	static function describe(e:Dynamic):String
	{
		var type:String = e != null && e.type != null ? Std.string(e.type) : 'error';
		return switch (type)
		{
			case 'network' | 'server-error' | 'socket-error' | 'socket-closed': 'Could not reach the matchmaking server ($type).';
			case 'browser-incompatible': 'This browser does not support WebRTC.';
			default: 'Online error: ' + (e != null && e.message != null ? Std.string(e.message) : type);
		};
	}

	public static function send(message:Dynamic):Void
	{
		if (conn == null || !connected) return;
		try
		{
			conn.send(message);
		}
		catch (e:Dynamic)
		{
			trace('online: could not send a message: $e');
		}
	}

	/** Leaves the room and drops the link. */
	public static function close():Void
	{
		generation++;
		connected = false;
		try
		{
			if (conn != null) conn.close();
		}
		catch (e:Dynamic) {}
		try
		{
			if (peer != null) peer.destroy();
		}
		catch (e:Dynamic) {}
		conn = null;
		peer = null;
	}
}
#end
