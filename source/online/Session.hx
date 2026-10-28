package online;

#if html5
/**
 * State of an online duel: who is who, what the rival is doing, and the message protocol on top of `Net`.
 *
 * Messages (JSON objects with a field `t`):
 *   lobby   - "I am in the song list" (the host only starts when the rival is there too)
 *   songs   - the songs I have, so the host can't start one the guest doesn't own
 *   sel     - the host moved to this song/difficulty (the guest follows it)
 *   start   - the host started this song
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

	// what the rival is doing in the current song
	public static var rivalScore:Int = 0;
	public static var rivalMisses:Int = 0;
	public static var rivalAccuracy:Float = 0;
	public static var rivalFinished:Bool = false;
	public static var rivalQuit:Bool = false;

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
				}
			case 'stat':
				rivalScore = msg.s;
				rivalMisses = msg.m;
				rivalAccuracy = msg.a;
			case 'fin':
				rivalScore = msg.s;
				rivalMisses = msg.m;
				rivalAccuracy = msg.a;
				rivalQuit = msg.quit == true;
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

	public static function sendStart(song:String, difficulty:String):Void
	{
		rivalInLobby = false;
		resetRun();
		Net.send({t: 'start', song: song, diff: difficulty});
	}

	// ------------------------------------------------------------------------------------------
	// During a song
	// ------------------------------------------------------------------------------------------

	/** Call every frame while playing; sends the live score a few times per second. */
	public static function tick(elapsed:Float, score:Int, misses:Int, accuracy:Float):Void
	{
		sinceStat += elapsed;
		if (sinceStat < 0.2) return;
		sinceStat = 0;
		Net.send({t: 'stat', s: score, m: misses, a: Math.round(accuracy * 10000) / 100});
	}

	public static function sendFinal(score:Int, misses:Int, accuracy:Float, quit:Bool):Void
	{
		Net.send({t: 'fin', s: score, m: misses, a: Math.round(accuracy * 10000) / 100, quit: quit});
	}
}
#end
