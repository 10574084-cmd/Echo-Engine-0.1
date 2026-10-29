package online;

#if html5
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import js.Browser;
import states.FreeplayState;
import states.MainMenuState;

/**
 * Online lobby: create a room (and share its code) or join one with a code.
 * When both players are connected they go to the song list (Freeplay), where the host picks the song.
 */
class OnlineState extends MusicBeatState
{
	static final ITEMS = ['Create room', 'Join room', 'Back'];

	var items:FlxTypedGroup<Alphabet>;
	var curSelected = 0;
	var title:FlxText;
	var status:FlxText;
	var codeText:FlxText;

	/** 0 = choosing, 1 = hosting (waiting), 2 = connecting as guest, 3 = loading the library */
	var mode = 0;

	override function create()
	{
		persistentUpdate = true;
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));

		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = echo.EchoTheme.color(0xFF3FA9F5);
		bg.screenCenter();
		add(bg);

		title = new FlxText(0, 30, FlxG.width, 'ONLINE  (BETA)', 48);
		title.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(title);

		var sub = new FlxText(0, 90, FlxG.width, '1 vs 1  -  the host plays as Boyfriend, the other player picks a character', 20);
		sub.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(sub);

		items = new FlxTypedGroup<Alphabet>();
		add(items);
		for (i in 0...ITEMS.length)
		{
			var item = new Alphabet(0, 190 + i * 100, ITEMS[i], true);
			item.screenCenter(X);
			items.add(item);
		}

		codeText = new FlxText(0, 500, FlxG.width, '', 64);
		codeText.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(codeText);

		status = new FlxText(40, 580, FlxG.width - 80, '', 24);
		status.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(status);

		// coming back from a duel: the link is not needed any more
		if (Session.active) Session.end();

		changeSelection(0, false);
		super.create();
	}

	function changeSelection(change:Int, sound:Bool = true):Void
	{
		curSelected = (curSelected + change + ITEMS.length) % ITEMS.length;
		if (sound) FlxG.sound.play(Paths.sound('scrollMenu'));
		for (i in 0...items.length)
			items.members[i].alpha = i == curSelected ? 1 : 0.55;
	}

	function say(text:String, isError:Bool = false):Void
	{
		status.text = text;
		status.color = isError ? 0xFFFF8888 : FlxColor.WHITE;
	}

	function resetToMenu(?message:String, isError:Bool = false):Void
	{
		Net.close();
		mode = 0;
		codeText.text = '';
		say(message != null ? message : '', isError);
		for (item in items) item.visible = true;
	}

	function enterLobby(host:Bool):Void
	{
		Session.begin(host);
		FlxG.sound.play(Paths.sound('confirmMenu'));
		// the host is Boyfriend; the player who joins picks a character first
		if (host) MusicBeatState.switchState(new FreeplayState());
		else MusicBeatState.switchState(new OnlineCharacterState());
	}

	function createRoom():Void
	{
		mode = 3;
		for (item in items) item.visible = false;
		say('Connecting to the matchmaking server...');
		Net.loadLibrary(function(error)
		{
			if (error != null)
			{
				resetToMenu(error, true);
				return;
			}
			mode = 1;
			Net.host(function(code)
			{
				codeText.text = code;
				say('Room code: share it with your friend.\nWaiting for a player...   (BACK to cancel)');
			}, function() enterLobby(true), function(message) resetToMenu(message, true));
		});
	}

	function joinRoom():Void
	{
		var typed:String = Browser.window.prompt('Room code:', '');
		if (typed == null) return; // cancelled
		var code = Net.cleanCode(typed);
		if (code == '')
		{
			say('Type the room code your friend shared.', true);
			return;
		}

		mode = 3;
		for (item in items) item.visible = false;
		say('Connecting...');
		Net.loadLibrary(function(error)
		{
			if (error != null)
			{
				resetToMenu(error, true);
				return;
			}
			mode = 2;
			codeText.text = code;
			Net.join(code, function() enterLobby(false), function(message) resetToMenu(message, true));
		});
	}

	override function update(elapsed:Float)
	{
		if (mode == 0)
		{
			if (controls.UI_UP_P) changeSelection(-1);
			if (controls.UI_DOWN_P) changeSelection(1);

			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
			else if (controls.ACCEPT)
			{
				switch (curSelected)
				{
					case 0: createRoom();
					case 1: joinRoom();
					default:
						FlxG.sound.play(Paths.sound('cancelMenu'));
						MusicBeatState.switchState(new MainMenuState());
				}
			}
		}
		else if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			resetToMenu();
		}

		super.update(elapsed);
	}

	override function destroy()
	{
		super.destroy();
	}
}
#end
