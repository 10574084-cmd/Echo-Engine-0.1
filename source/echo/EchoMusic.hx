package echo;

/** "Random Menu Music": picks one of the available menu tracks. */
class EchoMusic
{
	static final TRACKS:Array<String> = ['freakyMenu', 'breakfast', 'tea-time'];

	/** Track that is (or was last) playing as menu music. */
	public static var current:String = 'freakyMenu';
	/** True once the main menu already swapped the title's track for a random one in this visit. */
	public static var randomizedAfterTitle:Bool = false;

	/** Name of the track to use for menu music now. Always freakyMenu unless Random Menu Music is on. */
	public static function menuTrack():String
	{
		if (!ClientPrefs.data.echoRandomMusic) return current = 'freakyMenu';

		var options = [for (t in TRACKS) if (t != current) t];
		current = options[FlxG.random.int(0, options.length - 1)];
		return current;
	}

	/** The main menu calls this when it opens straight after the title screen. */
	public static function onMainMenu():Void
	{
		if (!ClientPrefs.data.echoRandomMusic || randomizedAfterTitle) return;
		randomizedAfterTitle = true;
		FlxG.sound.playMusic(Paths.music(menuTrack()), 0);
		FlxG.sound.music.fadeIn(1, 0, 0.7);
	}
}
