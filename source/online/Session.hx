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

	static function handle(msg:Dynamic):Void
	{
		if (msg == null) return;
		switch (Std.string(msg.t))
		{
			case 'lobby':
				rivalInLobby = true;
				if (onLobbyChanged != null) onLobbyChanged();
			case 'char':
				rivalChar = Std.string(msg.name);
				rivalCharKnown = true;
				if (onLobbyChanged != null) onLobbyChanged();
			case 'songs':
				rivalSongs = msg.list;
				if (onLobbyChanged != null) onLobbyChanged();
			case 'sel':
				if (!isHost && onSelect != null) onSelect(msg.song, msg.diff);
			case 'start':
				rivalInLobby = false;
				if (!isHost)
				{
					resetRun();
					if (onStart != null) onStart(msg.song, msg.diff);
					else if (msg.force == true) forceJoin(Std.string(msg.song), Std.string(msg.diff));
				}
			case 'evt':
				var name = Std.string(msg.name);
				if (FORCEABLE_EVENTS.indexOf(name) >= 0 && onForcedEvent != null)
					onForcedEvent(name, Std.string(msg.v1).substr(0, 40), Std.string(msg.v2).substr(0, 40));
			case 'stat':
				rivalScore = msg.s;
				rivalMisses = msg.m;
				rivalAccuracy = msg.a;
				rivalBot = msg.bot == true;
			case 'fin':
				rivalScore = msg.s;
				rivalMisses = msg.m;
				rivalAccuracy = msg.a;
				rivalQuit = msg.quit == true;
				rivalBot = msg.bot == true;
				rivalFinished = true;
				if (onRivalFinished != null) onRivalFinished();
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
