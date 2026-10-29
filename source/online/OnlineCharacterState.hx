package online;

#if html5
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import objects.Character;
import objects.HealthIcon;
import states.FreeplayState;
import sys.FileSystem;

/**
 * Player 2 (the one who joined the room) chooses the character to play as.
 * The host always plays as Boyfriend.
 */
class OnlineCharacterState extends MusicBeatState
{
	static inline var ROWS = 11;

	var names:Array<String> = [];
	var cur = 0;
	var rows:Array<FlxText> = [];
	var preview:Character = null;
	var icon:HealthIcon = null;
	var previewName:FlxText;
	var note:FlxText;
	var leaving = false;

	static function listCharacters():Array<String>
	{
		var list:Array<String> = Mods.mergeAllTextsNamed('data/characterList.txt', Paths.getSharedPath());
		var folders:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'characters/');
		for (folder in folders)
			for (file in FileSystem.readDirectory(folder))
				if (file.toLowerCase().endsWith('.json'))
				{
					var name = file.substr(0, file.length - 5);
					if (!list.contains(name)) list.push(name);
				}

		// not for playing: death / game over versions and empty lines
		var out = [for (n in list) if (n.trim() != '' && !n.toLowerCase().contains('dead') && !n.toLowerCase().contains('death')) n.trim()];
		out.sort(function(a, b)
		{
			if (a == 'bf') return -1;
			if (b == 'bf') return 1;
			return a.toLowerCase() < b.toLowerCase() ? -1 : 1;
		});
		return out;
	}

	override function create()
	{
		persistentUpdate = true;
		Mods.loadTopMod();
		names = listCharacters();
		if (names.length == 0) names.push('bf');

		var last:String = FlxG.save.data.echoOnlineChar;
		if (last != null && names.contains(last)) cur = names.indexOf(last);

		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = echo.EchoTheme.color(0xFF3FA9F5);
		bg.screenCenter();
		add(bg);

		add(label(0, 24, FlxG.width, 'CHOOSE YOUR CHARACTER', 44, CENTER));
		add(label(0, 80, FlxG.width, 'The host plays as Boyfriend. You play as the character you pick.', 20, CENTER));

		for (i in 0...ROWS)
		{
			var row = label(70, 150 + i * 44, 520, '', 30, LEFT);
			rows.push(row);
			add(row);
		}

		previewName = label(FlxG.width / 2 + 40, 625, FlxG.width / 2 - 80, '', 30, CENTER);
		add(previewName);
		note = label(0, FlxG.height - 36, FlxG.width, 'UP / DOWN: choose   -   LEFT / RIGHT: jump   -   ENTER: confirm   -   BACK: leave the room', 18, CENTER);
		add(note);

		refreshList();
		showPreview();
		super.create();
	}

	function label(x:Float, y:Float, w:Float, text:String, size:Int, align:FlxTextAlign):FlxText
	{
		var t = new FlxText(x, y, w, text, size);
		t.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.scrollFactor.set();
		return t;
	}

	function refreshList():Void
	{
		var first = Std.int(Math.max(0, Math.min(cur - Std.int(ROWS / 2), names.length - ROWS)));
		for (i in 0...ROWS)
		{
			var idx = first + i;
			var row = rows[i];
			if (idx >= names.length) { row.text = ''; continue; }
			var selected = idx == cur;
			row.text = (selected ? '> ' : '  ') + names[idx];
			row.alpha = selected ? 1 : 0.6;
			row.color = selected ? FlxColor.YELLOW : FlxColor.WHITE;
		}
	}

	function showPreview():Void
	{
		if (preview != null) { remove(preview, true); preview.destroy(); preview = null; }
		if (icon != null) { remove(icon, true); icon.destroy(); icon = null; }

		var name = names[cur];
		previewName.text = name;
		try
		{
			preview = new Character(0, 0, name, true);
			var maxH:Float = 380;
			var maxW:Float = FlxG.width / 2 - 120;
			var s = Math.min(1, Math.min(maxH / Math.max(1, preview.frameHeight), maxW / Math.max(1, preview.frameWidth)));
			preview.scale.set(s, s);
			preview.updateHitbox();
			preview.x = FlxG.width * 0.75 - preview.width / 2;
			preview.y = 150 + (maxH - preview.height);
			preview.dance();
			add(preview);

			icon = new HealthIcon(preview.healthIcon, true);
			icon.setPosition(FlxG.width * 0.75 - icon.width / 2, 505);
			add(icon);
		}
		catch (e:Dynamic)
		{
			// a broken character file: it is still listed, but there is nothing to draw
			trace('online: cannot preview "$name": $e');
			preview = null;
			previewName.text = name + '\n(no preview)';
		}
	}

	function move(by:Int):Void
	{
		var next = Std.int(Math.max(0, Math.min(names.length - 1, cur + by)));
		if (next == cur) return;
		cur = next;
		FlxG.sound.play(Paths.sound('scrollMenu'));
		refreshList();
		showPreview();
	}

	override function beatHit()
	{
		super.beatHit();
		if (preview != null && curBeat % 2 == 0) preview.dance();
	}

	override function update(elapsed:Float)
	{
		if (!leaving)
		{
			if (controls.UI_UP_P) move(-1);
			else if (controls.UI_DOWN_P) move(1);
			else if (controls.UI_LEFT_P) move(-ROWS);
			else if (controls.UI_RIGHT_P) move(ROWS);
			else if (controls.ACCEPT)
			{
				leaving = true;
				FlxG.save.data.echoOnlineChar = names[cur];
				FlxG.save.flush();
				Session.sendChar(names[cur]);
				FlxG.sound.play(Paths.sound('confirmMenu'));
				MusicBeatState.switchState(new FreeplayState());
			}
			else if (controls.BACK)
			{
				leaving = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				Session.end();
				MusicBeatState.switchState(new OnlineState());
			}
		}
		super.update(elapsed);
	}
}
#end
