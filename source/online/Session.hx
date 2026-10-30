package online;

#if html5
/**
 * State of an online duel: who is who, what the rival is doing, and the message protocol on top of `Net`.
 *
 * Messages (JSON objects with a field `t`):
 *   char    - the guest's chosen character (the host is always bf)
 *   lobby   - "I am in the song list" (the host only starts when the rival is there too)
 *   songs   - the songs I have, so the host can't start one the guest doesn't own
 *   sel     - the host moved to this song/difficulty (the guest follows it)
 *   start   - the host started this song (force: true = even if the guest is in another menu)
 *   evt     - an admin forced a chart event (only FORCEABLE_EVENTS are accepted)
 *   stat    - live score while playing
 *   fin     - final result (quit = left before the end)
 *   bye     - leaving the room
 */
class Session
{
	public static var active(default, null):Bool = false;
	public static var isHost(default, null):Bool = false;

	/** Songs the rival owns (lower case), null until the rival said so. */
	public static var rivalSongs:Array<String> = null;
	public static var rivalInLobby:Bool = false;
	public static var rivalLeft:Bool = false;

	/** Who plays as whom: the host is always Boyfriend, the guest picks a character (OnlineCharacterState). */
	public static var myChar:String = 'bf';
	public static var rivalChar:String = 'bf';
	/** False until the guest's choice reached the host. */
	public static var rivalCharKnown:Bool = false;

	// what the rival is doing in the current song
	public static var rivalScore:Int = 0;
	public static var rivalMisses:Int = 0;
	public static var rivalAccuracy:Float = 0;
	public static var rivalFinished:Bool = false;
	public static var rivalQuit:Bool = false;
	/** The rival plays with botplay (admin option): shown next to its score. */
	public static var rivalBot:Bool = false;

	/** Events an admin can force on everybody. Anything else received is ignored. */
	public static final FORCEABLE_EVENTS:Array<String> = ['Add Camera Zoom', 'Screen Shake', 'Hey!', 'Change Scroll Speed'];

	/** A song the host forced on this player while it was somewhere else: Freeplay picks it up and starts it. */
	public static var pendingForce:{song:String, diff:String} = null;
	public static var onForcedEvent:String->String->String->Void = null;

	// callbacks of whichever screen is open
	public static var onSelect:String->String->Void = null;
	public static var onStart:String->String->Void = null;
	public static var onLobbyChanged:Void->Void = null;
	public static var onRivalLeft:Void->Void = null;
	public static var onRivalFinished:Void->Void = null;

	static var sinceStat:Float = 0;

	/** The link is open: from now on the screens of the game work in online mode. */
	public static function begin(host:Bool):Void
	{
		active = true;
		isHost = host;
		rivalSongs = null;
		rivalInLobby = false;
		rivalLeft = false;
		myChar = 'bf';
		rivalChar = 'bf';
		rivalCharKnown = !host; // the guest already knows the host is Boyfriend
		resetRun();
		Net.onMessage = handle;
		Net.onClose = function()
		{
			rivalLeft = true;
			rivalInLobby = false;
			if (onRivalLeft != null) onRivalLeft();
		};
	}

	/** Leaves the room. */
	public static function end(?tellRival:Bool = true):Void
	{
		if (tellRival) Net.send({t: 'bye'});
		Net.onMessage = null;
		Net.onClose = null;
		Net.close();
		active = false;
		onSelect = onStart = null;
		onLobbyChanged = onRivalLeft = onRivalFinished = null;
	}

	public static function resetRun():Void
	{
		rivalScore = 0;
		rivalMisses = 0;
		rivalAccuracy = 0;
		rivalFinished = false;
		rivalQuit = false;
		rivalBot = false;
		sinceStat = 0;
	}

	// ------------------------------------------------------------------------------------------
	// Everything that arrives from the other player is untrusted (a modified client, a userscript or an
	// extension can send anything), so each message is checked before it is used.
	// ------------------------------------------------------------------------------------------

	static var windowStart:Float = 0;
	static var windowCount:Int = 0;

	/** More than 60 messages in one second is not a normal game: drop the excess. */
	static function rateLimited():Bool
	{
		var now = haxe.Timer.stamp();
		if (now - windowStart >= 1)
		{
			windowStart = now;
			windowCount = 0;
		}
		return ++windowCount > 60;
	}

	static function safeText(v:Dynamic, max:Int):String
	{
		if (!Std.isOfType(v, String)) return null;
		var t:String = v;
		if (t.length == 0 || t.length > max) return null;
		for (i in 0...t.length)
		{
			var c = t.charCodeAt(i);
			if (c < 32 || c == 127) return null; // no control characters
		}
		return t;
	}

	static function safeNumber(v:Dynamic, min:Float, max:Float):Null<Float>
	{
		if (!Std.isOfType(v, Float)) return null;
		var n:Float = v;
		if (Math.isNaN(n) || !Math.isFinite(n) || n < min || n > max) return null;
		return n;
	}

	static function handle(msg:Dynamic):Void
	{
		if (msg == null || !Reflect.isObject(msg) || Std.isOfType(msg, String) || rateLimited()) return;
		var type = safeText(msg.t, 8);
		if (type == null) return;

		switch (type)
		{
			case 'lobby':
				rivalInLobby = true;
				if (onLobbyChanged != null) onLobbyChanged();
			case 'char':
				var name = safeText(msg.name, 40);
				if (name == null) return;
				rivalChar = name;
				rivalCharKnown = true;
				if (onLobbyChanged != null) onLobbyChanged();
			case 'songs':
				if (!Std.isOfType(msg.list, Array)) return;
				var raw:Array<Dynamic> = msg.list;
				var list:Array<String> = [];
				for (item in raw.slice(0, 3000))
				{
					var song = safeText(item, 80);
					if (song != null) list.push(song);
				}
				rivalSongs = list;
				if (onLobbyChanged != null) onLobbyChanged();
			case 'sel':
				var song = safeText(msg.song, 80);
				var diff = safeText(msg.diff, 30);
				if (!isHost && onSelect != null && song != null && diff != null) onSelect(song, diff);
			case 'start':
				// only the host decides which song is played
				var song = safeText(msg.song, 80);
				var diff = safeText(msg.diff, 30);
				if (isHost || song == null || diff == null) return;
				rivalInLobby = false;
				resetRun();
				if (onStart != null) onStart(song, diff);
				else if (msg.force == true) forceJoin(song, diff);
			case 'evt':
				var name = safeText(msg.name, 30);
				if (name == null || FORCEABLE_EVENTS.indexOf(name) < 0 || onForcedEvent == null) return;
				var v1 = safeText(msg.v1, 40);
				var v2 = safeText(msg.v2, 40);
				onForcedEvent(name, v1 == null ? '' : v1, v2 == null ? '' : v2);
			case 'stat' | 'fin':
				var score = safeNumber(msg.s, 0, 2000000000);
				var misses = safeNumber(msg.m, 0, 1000000);
				var acc = safeNumber(msg.a, 0, 100);
				if (score == null || misses == null || acc == null) return;
				rivalScore = Std.int(score);
				rivalMisses = Std.int(misses);
				rivalAccuracy = acc;
				rivalBot = msg.bot == true;
				if (type == 'fin')
				{
					rivalQuit = msg.quit == true;
					rivalFinished = true;
					if (onRivalFinished != null) onRivalFinished();
				}
			case 'bye':
				rivalLeft = true;
				rivalInLobby = false;
				if (onRivalLeft != null) onRivalLeft();
		}
	}

	// ------------------------------------------------------------------------------------------
	// Song list
	// ------------------------------------------------------------------------------------------

	/** The guest tells which character it plays as. */
	public static function sendChar(name:String):Void
	{
		myChar = name;
		Net.send({t: 'char', name: name});
	}

	public static function sendLobby(ownedSongs:Array<String>):Void
	{
		Net.send({t: 'songs', list: ownedSongs});
		Net.send({t: 'lobby'});
	}

	public static function rivalHasSong(song:String):Bool
	{
		return rivalSongs == null || rivalSongs.indexOf(song.toLowerCase()) >= 0;
	}

	public static function sendSelect(song:String, difficulty:String):Void
	{
		if (isHost) Net.send({t: 'sel', song: song, diff: difficulty});
	}

	public static function sendStart(song:String, difficulty:String, force:Bool = false):Void
	{
		rivalInLobby = false;
		resetRun();
		Net.send({t: 'start', song: song, diff: difficulty, force: force});
	}

	/** Admin: makes the rival's game run this chart event too. */
	public static function sendEvent(name:String, value1:String, value2:String):Void
		Net.send({t: 'evt', name: name, v1: value1, v2: value2});

	/** The host forced a song while this player was in another menu: go to the song list, it starts there. */
	static function forceJoin(song:String, diff:String):Void
	{
		var game = states.PlayState.instance;
		if (game != null && !game.endingSong) return; // already playing
		pendingForce = {song: song, diff: diff};
		MusicBeatState.switchState(new states.FreeplayState());
	}

	// ------------------------------------------------------------------------------------------
	// During a song
	// ------------------------------------------------------------------------------------------

	/** Call every frame while playing; sends the live score a few times per second. */
	public static function tick(elapsed:Float, score:Int, misses:Int, accuracy:Float, bot:Bool = false):Void
	{
		sinceStat += elapsed;
		if (sinceStat < 0.2) return;
		sinceStat = 0;
		Net.send({t: 'stat', s: score, m: misses, a: Math.round(accuracy * 10000) / 100, bot: bot});
	}

	public static function sendFinal(score:Int, misses:Int, accuracy:Float, quit:Bool, bot:Bool = false):Void
	{
		Net.send({t: 'fin', s: score, m: misses, a: Math.round(accuracy * 10000) / 100, quit: quit, bot: bot});
	}
}
#end
