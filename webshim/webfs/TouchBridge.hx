package webfs;

#if !html5
#error "webfs.TouchBridge only exists for the html5 target"
#end

/** Tells the web page's on-screen controls (webshim/html5/echo-touch.js) whether a song is being played. */
class TouchBridge
{
	static var last:Null<Bool> = null;

	public static function setPlaying(playing:Bool):Void
	{
		if (last == playing) return;
		last = playing;
		js.Syntax.code("if (window.EchoTouch) window.EchoTouch.setPlaying({0})", playing);
	}
}
