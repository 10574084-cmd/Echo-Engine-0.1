package echo;

import flixel.FlxG;

/**
 * "Shader packs": a visual look for the whole game, like the shader packs of Minecraft (Newb and friends).
 *
 * On the web the picture is post-processed by the browser itself instead of by game code: color grading uses the CSS filters of the
 * game canvas, and vignette, glow, blur, scanlines, film grain and color tint are layers on top of it. This runs on the GPU, works in
 * every screen (menus and songs) and on phones, and does not depend on the game's renderer. It has nothing to do with the shaders of
 * mods, which the web cannot run.
 *
 * Developer helper: `?shaderpack=Newb&shaderintensity=0.8` in the address tries a pack without touching the settings.
 */
class EchoShaderPack
{
	/** Name -> [saturation, contrast, brightness, vignette, glow, blur, scanlines, grain, tintR, tintG, tintB] (tint is multiplied) */
	static final PACKS:Map<String, Array<Float>> = [
		'Vibrant'   => [1.40, 1.08, 1.02, 0.15, 0.10, 0.0, 0.0,  0.00, 255, 255, 255],
		'Newb'      => [1.22, 1.12, 1.00, 0.34, 0.40, 0.0, 0.0,  0.05, 255, 246, 226],
		'Cinematic' => [0.88, 1.24, 0.95, 0.55, 0.10, 0.0, 0.0,  0.10, 255, 244, 232],
		'Glow'      => [1.12, 1.04, 1.00, 0.18, 0.85, 0.0, 0.0,  0.00, 255, 255, 255],
		'Dreamy'    => [1.15, 0.98, 1.06, 0.22, 0.55, 0.6, 0.0,  0.00, 255, 238, 255],
		'Retro CRT' => [1.15, 1.10, 1.02, 0.50, 0.12, 0.0, 0.40, 0.08, 235, 255, 240],
		'Sunset'    => [1.15, 1.05, 1.00, 0.32, 0.30, 0.0, 0.0,  0.00, 255, 214, 170],
		'Night'     => [0.95, 1.10, 0.88, 0.48, 0.10, 0.0, 0.0,  0.04, 150, 190, 255],
		'Noir'      => [0.00, 1.30, 1.00, 0.50, 0.10, 0.0, 0.0,  0.12, 255, 255, 255]
	];

	public static final NAMES:Array<String> = ['Off', 'Vibrant', 'Newb', 'Cinematic', 'Glow', 'Dreamy', 'Retro CRT', 'Sunset', 'Night', 'Noir'];

	#if html5
	static var root:js.html.DivElement = null;
	static var layers:Map<String, js.html.DivElement> = new Map();
	static var applied:String = 'Off';
	static var appliedKey:String = '';

	// developer override from the address
	static var urlPack:String = null;
	static var urlIntensity:Float = Math.NaN;

	static final GRAIN = "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>\")";
	#end

	public static function install():Void
	{
		#if html5
		urlPack = js.Syntax.code("(new URLSearchParams(window.location.search)).get('shaderpack')");
		urlIntensity = Std.parseFloat(js.Syntax.code("(new URLSearchParams(window.location.search)).get('shaderintensity') || ''"));
		FlxG.signals.postUpdate.add(update);
		#end
	}

	#if html5
	static function wanted():String
	{
		if (urlPack != null && PACKS.exists(urlPack)) return urlPack;
		if (ClientPrefs.data == null || !ClientPrefs.data.shaders) return 'Off';
		var name = ClientPrefs.data.echoShaderPack;
		if (!PACKS.exists(name)) return 'Off';
		if (ClientPrefs.data.echoShaderSongsOnly && !Std.isOfType(FlxG.state, states.PlayState)) return 'Off';
		return name;
	}

	static function layer(name:String, mixBlend:String):js.html.DivElement
	{
		var el = layers.get(name);
		if (el == null)
		{
			el = js.Browser.document.createDivElement();
			var s:Dynamic = el.style;
			// each layer goes straight on the page (not inside a container): a container would be its own stacking context
			// and the blend modes would have nothing underneath to blend with
			s.position = 'fixed';
			s.left = '0';
			s.top = '0';
			s.width = '100%';
			s.height = '100%';
			s.pointerEvents = 'none';
			s.zIndex = '5';
			s.mixBlendMode = mixBlend;
			js.Browser.document.body.appendChild(el);
			layers.set(name, el);
		}
		return el;
	}

	static function setup():Bool
	{
		if (root != null) return true;
		root = js.Browser.document.createDivElement(); // only a marker that the first setup is done
		return true;
	}

	static function showLayers(show:Bool):Void
	{
		for (el in layers) (cast el.style : Dynamic).display = show ? 'block' : 'none';
	}

	static function canvas():js.html.Element
		return js.Browser.document.querySelector('#content canvas');

	static function clear():Void
	{
		var c = canvas();
		if (c != null) (cast c.style : Dynamic).filter = '';
		showLayers(false);
		applied = 'Off';
		appliedKey = '';
	}

	static function update():Void
	{
		var name = wanted();
		if (name == 'Off')
		{
			if (applied != 'Off') clear();
			return;
		}
		var intensity = !Math.isNaN(urlIntensity) ? urlIntensity : (ClientPrefs.data != null ? ClientPrefs.data.echoShaderIntensity : 1.0);
		var glowOn = ClientPrefs.data == null || ClientPrefs.data.echoShaderBloom;
		var key = name + '|' + intensity + '|' + glowOn;
		if (key == appliedKey) return; // nothing changed: the browser keeps the look by itself
		if (!setup()) return;
		var c = canvas();
		if (c == null) return;

		var v = PACKS.get(name);
		var k = Math.max(0, Math.min(1, intensity));
		inline function mixTo1(x:Float):Float return 1 + (x - 1) * k;

		(cast c.style : Dynamic).filter = 'saturate(' + mixTo1(v[0]) + ') contrast(' + mixTo1(v[1]) + ') brightness(' + mixTo1(v[2]) + ')';
		showLayers(true);

		// color tint
		var tint = layer('tint', 'multiply');
		var tr = Std.int(255 + (v[8] - 255) * k), tg = Std.int(255 + (v[9] - 255) * k), tb = Std.int(255 + (v[10] - 255) * k);
		(cast tint.style : Dynamic).background = 'rgb($tr,$tg,$tb)';

		// glow: a blurred copy of what is behind, brightened and added on top (only if "Glow and Blur" is on)
		var glow = layer('glow', 'screen');
		var gs:Dynamic = glow.style;
		var glowAmount = glowOn ? v[4] * k : 0.0;
		gs.display = glowAmount > 0 ? 'block' : 'none';
		gs.backdropFilter = 'blur(7px) brightness(1.15)';
		gs.webkitBackdropFilter = 'blur(7px) brightness(1.15)';
		gs.background = 'rgba(0,0,0,0.01)';
		gs.opacity = Std.string(Math.min(1, glowAmount));

		// soft blur (dreamy)
		var blur = layer('blur', 'normal');
		var bs:Dynamic = blur.style;
		var blurAmount = glowOn ? v[5] * k : 0.0;
		bs.display = blurAmount > 0 ? 'block' : 'none';
		bs.backdropFilter = 'blur(2.5px)';
		bs.webkitBackdropFilter = 'blur(2.5px)';
		bs.background = 'rgba(0,0,0,0.01)';
		bs.opacity = Std.string(Math.min(1, blurAmount));

		// vignette
		var vig = layer('vignette', 'normal');
		(cast vig.style : Dynamic).background = 'radial-gradient(ellipse at center, rgba(0,0,0,0) 45%, rgba(0,0,0,' + (v[3] * k) + ') 100%)';

		// scanlines
		var scan = layer('scan', 'multiply');
		var ss:Dynamic = scan.style;
		ss.display = v[6] * k > 0 ? 'block' : 'none';
		ss.background = 'repeating-linear-gradient(to bottom, rgba(0,0,0,' + (v[6] * k) + ') 0px, rgba(0,0,0,' + (v[6] * k) + ') 1px, rgba(0,0,0,0) 1px, rgba(0,0,0,0) 3px)';

		// film grain
		var grain = layer('grain', 'overlay');
		var grs:Dynamic = grain.style;
		grs.display = v[7] * k > 0 ? 'block' : 'none';
		grs.backgroundImage = GRAIN;
		grs.opacity = Std.string(Math.min(1, v[7] * k * 3));

		applied = name;
		appliedKey = key;
	}
	#end
}
