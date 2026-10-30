package echo;

#if html5
import flixel.FlxG;
import haxe.Json;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import states.FlashingState;
import states.FreeplayState;
import states.LoadingState;
import states.OutdatedState;
import states.PlayState;
import states.TitleState;
#end

/**
 * Echo Live: an announcement that reaches EVERY player who has the game open, without any game server.
 *
 * How it works: the repository has a branch called `live` that holds one small file, `live.json`. Only people who can run
 * the "Echo Live" workflow of the repository (GitHub Actions > Echo Live > Run workflow) can change it, so nobody else can
 * announce anything: there is no password inside the game and nothing a userscript or an extension could forge.
 * Every copy of the game reads that file every 30 seconds. When there is a new announcement the player sees a countdown
 * banner and, when it reaches zero:
 *   - song:    everybody is taken to Freeplay and the song starts (after the song they are playing, if any),
 *   - event:   a chart event (one of Session.FORCEABLE_EVENTS) runs for everybody who is playing a song,
 *   - message: just a notice.
 * The player can always skip it (F9 or tapping the banner) or turn it off (Options > Echo Extras > Echo Live Events).
 * What is read from the file is validated before use, like everything that comes from the network.
 */
class EchoLive
{
	#if html5
	static inline var URL = 'https://raw.githubusercontent.com/10574084-cmd/Echo-Engine-1.1.0/live/live.json';
	static inline var POLL_EVERY = 30.0; // seconds
	static inline var SONG_GRACE = 600000.0; // a player that opens the game up to 10 minutes late still joins the song

	static var active:Announcement = null;
	static var sincePoll:Float = POLL_EVERY - 4; // first look 4 seconds after the game opened
	static var bar:Sprite = null;
	static var label:TextField = null;

	/** Starts watching. Called once, when the game is created. */
	public static function install():Void
	{
		FlxG.signals.postUpdate.add(update);
	}

	// ------------------------------------------------------------------------------------------
	// Reading and checking live.json
	// ------------------------------------------------------------------------------------------

	static function poll():Void
	{
		try
		{
			// the number changes every 10 seconds so a cached copy is never used
			var http = new haxe.Http(URL + '?t=' + Std.int(Date.now().getTime() / 10000));
			http.onData = onData;
			http.onError = function(_) {};
			http.request(false);
		}
		catch (e:Dynamic) {}
	}

	static function text(v:Dynamic, max:Int, allowEmpty:Bool = false):String
	{
		if (v == null) return allowEmpty ? '' : null;
		if (!Std.isOfType(v, String)) return null;
		var t:String = v;
		if (t.length > max || (t.length == 0 && !allowEmpty)) return null;
		for (i in 0...t.length)
		{
			var c = t.charCodeAt(i);
			if (c < 32 || c == 127) return null;
		}
		return t;
	}

	static function parse(raw:String):Announcement
	{
		var o:Dynamic = null;
		try o = Json.parse(raw) catch (e:Dynamic) return null;
		if (o == null || !Reflect.isObject(o) || Std.isOfType(o, String)) return null;

		var id = text(o.id, 64);
		var kind = text(o.kind, 8);
		if (id == null || kind == null) return null;

		var a:Announcement = {id: id, kind: kind, start: 0, song: '', diff: 'Normal', event: '', v1: '', v2: '', msg: ''};
		var msg = text(o.msg, 140, true);
		if (msg == null) return null;
		a.msg = msg;

		if (kind == 'clear') return a;
		if (kind != 'song' && kind != 'event' && kind != 'message') return null;

		if (!Std.isOfType(o.start, Float)) return null;
		var start:Float = o.start;
		var now = Date.now().getTime();
		if (Math.isNaN(start) || !Math.isFinite(start) || start < 0 || start > now + 86400000.0) return null; // at most one day ahead
		a.start = start;

		if (kind == 'song')
		{
			var song = text(o.song, 60);
			var diff = text(o.diff, 20, true);
			if (song == null || diff == null || !~/^[A-Za-z0-9 _.\-]+$/.match(song)) return null;
			a.song = Paths.formatToSongPath(song);
			if (diff != '') a.diff = diff;
		}
		else if (kind == 'event')
		{
			var event = text(o.event, 30);
			if (event == null || online.Session.FORCEABLE_EVENTS.indexOf(event) < 0) return null;
			a.event = event;
			a.v1 = text(o.v1, 40, true);
			a.v2 = text(o.v2, 40, true);
			if (a.v1 == null || a.v2 == null) return null;
		}
		return a;
	}

	static function onData(raw:String):Void
	{
		if (ClientPrefs.data == null) return;
		var a = parse(raw);
		if (a == null || a.id == ClientPrefs.data.echoLiveSeen) return;
		if (active != null && active.id == a.id) return;

		if (a.kind == 'clear')
		{
			// the organisers cancelled what was announced
			if (active != null) hide();
			active = null;
			remember(a.id);
			return;
		}
		if (Date.now().getTime() > a.start + SONG_GRACE) return; // old news
		active = a;
	}

	static function remember(id:String):Void
	{
		ClientPrefs.data.echoLiveSeen = id;
		try ClientPrefs.saveSettings() catch (e:Dynamic) {}
	}

	// ------------------------------------------------------------------------------------------
	// Every frame
	// ------------------------------------------------------------------------------------------

	static function update():Void
	{
		if (ClientPrefs.data == null) return;
		if (!ClientPrefs.data.echoLive)
		{
			if (active != null) active = null;
			hide();
			return;
		}

		sincePoll += FlxG.elapsed;
		if (sincePoll >= POLL_EVERY)
		{
			sincePoll = 0;
			poll();
		}

		if (active == null)
		{
			hide();
			return;
		}
		if (FlxG.keys.justPressed.F9)
		{
			finish();
			return;
		}
		step(Date.now().getTime());
	}

	static function step(now:Float):Void
	{
		var a = active;
		var remaining = (a.start - now) / 1000;
		var game = PlayState.instance;
		var inSong = game != null && !game.endingSong && Std.isOfType(FlxG.state, PlayState);

		if (remaining > 0)
		{
			// do not cover the game while somebody is playing, except for the last seconds
			if (!inSong || remaining <= 20) display(announcement(a, remaining));
			else hide();
			return;
		}

		switch (a.kind)
		{
			case 'message':
				if (now - a.start > 12000) finish();
				else display('ECHO LIVE: ' + a.msg);

			case 'event':
				// an event only makes sense inside a song: whoever is not in one just misses it
				if (inSong) game.forceEvent(a.event, a.v1, a.v2, 'ECHO LIVE: ' + a.event);
				finish();

			case 'song':
				if (now - a.start > SONG_GRACE || online.Session.active)
				{
					finish();
					return;
				}
				if (Std.isOfType(FlxG.state, PlayState))
				{
					display('ECHO LIVE: ' + prettySong(a.song) + ' starts when your song ends   [F9 / tap: skip]');
					return;
				}
				if (!stateIsFree()) return;
				finish();
				FreeplayState.liveForce = {song: a.song, diff: a.diff};
				MusicBeatState.switchState(new FreeplayState());
		}
	}

	/** Not on a screen that must not be interrupted (intro, loading, editors, online setup). */
	static function stateIsFree():Bool
	{
		var s:Dynamic = FlxG.state;
		if (s == null) return false;
		if (Std.isOfType(s, TitleState) || Std.isOfType(s, FlashingState) || Std.isOfType(s, OutdatedState) || Std.isOfType(s, LoadingState)) return false;
		var name = Type.getClassName(Type.getClass(s));
		return !(StringTools.startsWith(name, 'states.editors') || StringTools.startsWith(name, 'online.'));
	}

	static function prettySong(song:String):String
		return song.split('-').join(' ').toUpperCase();

	static function announcement(a:Announcement, remaining:Float):String
	{
		var secs = Math.ceil(remaining);
		var time = Std.int(secs / 60) + ':' + StringTools.lpad(Std.string(secs % 60), '0', 2);
		var what = switch (a.kind)
		{
			case 'song': prettySong(a.song) + ' starts in ' + time + ' - everybody joins!';
			case 'event': a.event + ' in ' + time;
			default: '';
		}
		var head = a.msg != '' ? a.msg + '  |  ' : '';
		return 'ECHO LIVE: ' + head + what + (what == '' ? '' : '   [F9 / tap: skip]');
	}

	/** Done (played, missed or skipped): never show this announcement again. */
	static function finish():Void
	{
		if (active != null) remember(active.id);
		active = null;
		hide();
	}

	// ------------------------------------------------------------------------------------------
	// The banner (an OpenFL layer above the game, so it works in every screen)
	// ------------------------------------------------------------------------------------------

	static function display(message:String):Void
	{
		var stage = Lib.current.stage;
		if (bar == null)
		{
			bar = new Sprite();
			label = new TextField();
			label.defaultTextFormat = new TextFormat('_sans', 18, 0xFFFFFF, true, null, null, null, null, TextFormatAlign.CENTER);
			label.selectable = false;
			label.mouseEnabled = false;
			label.multiline = false;
			label.wordWrap = false;
			label.y = 10;
			label.height = 30;
			bar.addChild(label);
			bar.buttonMode = true;
			bar.addEventListener(MouseEvent.CLICK, function(_) finish());
		}
		if (bar.parent == null || stage.getChildIndex(bar) != stage.numChildren - 1) stage.addChild(bar);

		var w = stage.stageWidth;
		if (label.text != message) label.text = message;
		label.width = w;
		bar.graphics.clear();
		bar.graphics.beginFill(0x000000, 0.8);
		bar.graphics.drawRect(0, 0, w, 44);
		bar.graphics.beginFill(0xFFea71fd & 0xFFFFFF, 1);
		bar.graphics.drawRect(0, 44, w, 3);
		bar.graphics.endFill();
		bar.visible = true;
	}

	static function hide():Void
	{
		if (bar != null && bar.visible) bar.visible = false;
	}
	#else
	public static function install():Void {}
	#end
}

typedef Announcement =
{
	var id:String;
	var kind:String;
	var start:Float;
	var song:String;
	var diff:String;
	var event:String;
	var v1:String;
	var v2:String;
	var msg:String;
}
