package options;

import echo.EchoInfo;

/** Version, credits, license and change log. UP/DOWN scroll the text. */
class EchoAboutSubState extends MusicBeatSubstate
{
	static final TEXT:String =
'${EchoInfo.NAME} ${EchoInfo.VERSION}
Built on ${EchoInfo.BASE}.

CREDITS
- Echo Engine: project and web port, with development assistance from Claude.
- Psych Engine: Shadow Mario, Riveren and the Psych Engine contributors.
- Friday Night Funkin\': ninjamuffin99, PhantomArcade, evilsk8r and kawaisprite.
- Libraries: HaxeFlixel, OpenFL and Lime (MIT), flxanimate (MIT),
  PeerJS for the online mode (MIT).

LICENSE
Echo Engine is an independent fan project. It is not official and it is not
affiliated with Friday Night Funkin\', Newgrounds or the creators of Psych Engine.
Psych Engine is released under the Apache License 2.0 (see the LICENSE file of the
project). The game\'s own art, music and trademarks belong to their owners.
Use only mods and content you have permission to use.

CHANGE LOG
BETA 0.1
- Playable in the browser (HTML5), built and published with GitHub Actions.
- Mods: import .zip files, saved in the browser; PNG, audio and font support.
- Online mode: 1 vs 1 duels by room code.
- On-screen controls for phones.
- Echo Extra settings: optimization presets, touch controls, accessibility,
  themes, quick boot, random menu music, stats and the Echo Lab.

KNOWN LIMITS
- Lua and HScript scripts do not run on the web version.
- No videos and no Discord Rich Presence.
';

	var text:FlxText;
	var scroll:Float = 0;

	override function create()
	{
		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = echo.EchoTheme.color(0xFF7C5CFF);
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		text = new FlxText(60, 90, FlxG.width - 120, TEXT, 22);
		text.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(text);

		var top = new FlxSprite().makeGraphic(FlxG.width, 80, FlxColor.BLACK);
		top.alpha = 0.7;
		add(top);
		var title = new Alphabet(0, 5, 'About Echo Engine', true);
		title.scaleX = title.scaleY = 0.8;
		title.updateHitbox();
		title.screenCenter(X);
		add(title);

		var bottom = new FlxSprite(0, FlxG.height - 32).makeGraphic(FlxG.width, 32, FlxColor.BLACK);
		bottom.alpha = 0.7;
		add(bottom);
		var hint = new FlxText(0, FlxG.height - 28, FlxG.width, 'UP / DOWN: scroll   -   BACK: close', 18);
		hint.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(hint);

		super.create();
	}

	override function update(elapsed:Float)
	{
		var speed = FlxG.keys.pressed.SHIFT ? 900 : 360;
		if (controls.UI_UP) scroll -= speed * elapsed;
		if (controls.UI_DOWN) scroll += speed * elapsed;
		if (FlxG.mouse.wheel != 0) scroll -= FlxG.mouse.wheel * 60;
		scroll = FlxMath.bound(scroll, 0, Math.max(0, text.height - (FlxG.height - 140)));
		text.y = 90 - scroll;

		if (controls.BACK)
		{
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		super.update(elapsed);
	}
}
