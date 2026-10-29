package webfs;

#if !html5
#error "webfs.TouchBridge only exists for the html5 target"
#end

/**
 * Link between the game and the web page's on-screen controls (webshim/html5/echo-touch.js).
 * The page owns the touch settings (they are remembered in localStorage); the game reads and changes them here.
 */
class TouchBridge
{
	static var last:Null<Bool> = null;

	/** Tells the page whether a song is being played (note buttons instead of the menu buttons). */
	public static function setPlaying(playing:Bool):Void
	{
		if (last == playing) return;
		last = playing;
		js.Syntax.code("if (window.EchoTouch) window.EchoTouch.setPlaying({0})", playing);
	}

	public static function getBool(name:String):Bool
		return js.Syntax.code("(window.EchoTouch ? window.EchoTouch.get({0}) : null) === true", name);

	public static function getNumber(name:String):Float
		return js.Syntax.code("Number(window.EchoTouch ? window.EchoTouch.get({0}) : 0) || 0", name);

	public static function getString(name:String):String
		return js.Syntax.code("String(window.EchoTouch ? window.EchoTouch.get({0}) : '')", name);

	public static function set(name:String, value:Dynamic):Void
		js.Syntax.code("if (window.EchoTouch) window.EchoTouch.set({0}, {1})", name, value);

	/** Shows the button editor (drag the buttons, then DONE). */
	public static function edit():Void
		js.Syntax.code("if (window.EchoTouch) window.EchoTouch.edit()");

	public static function reset():Void
		js.Syntax.code("if (window.EchoTouch) window.EchoTouch.reset()");
}
