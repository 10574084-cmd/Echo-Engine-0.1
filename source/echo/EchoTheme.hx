package echo;

import flixel.FlxSprite;

/** Menu colour themes (Options > Echo Extra > Echo Extras > Echo Theme). */
class EchoTheme
{
	public static final NAMES:Array<String> = ['Default', 'Midnight', 'Ocean', 'Forest', 'Sunset', 'Candy', 'Mono'];

	static final COLORS:Map<String, Int> = [
		'Midnight' => 0xFF5560C8,
		'Ocean' => 0xFF29A8E8,
		'Forest' => 0xFF48B060,
		'Sunset' => 0xFFFF7A59,
		'Candy' => 0xFFFF77C8,
		'Mono' => 0xFF9A9A9A
	];

	public static function active():Bool
		return ClientPrefs.data.echoTheme != 'Default' && COLORS.exists(ClientPrefs.data.echoTheme);

	/** The colour a menu background should use: the theme's, or `normal` with the Default theme. */
	public static function color(normal:FlxColor):FlxColor
		return active() ? FlxColor.fromInt(COLORS.get(ClientPrefs.data.echoTheme)) : normal;

	/** Tints a menu background. Pictures that are not grey (menuBG) are swapped for the grey one so the colour is the real one. */
	public static function apply(bg:FlxSprite, normal:FlxColor, ?greyImage:Bool = true):Void
	{
		if (active() && !greyImage) bg.loadGraphic(Paths.image('menuDesat'));
		bg.color = color(normal);
	}
}
