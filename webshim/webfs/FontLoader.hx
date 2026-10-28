package webfs;

#if !html5
#error "webfs.FontLoader only exists for the html5 target"
#end

import haxe.io.Bytes;

/**
 * Makes the fonts that come inside mods (`mods/<mod>/fonts/*.ttf|otf|woff|woff2`) usable.
 *
 * `Paths.font("x.ttf")` returns the file's path, and Flixel/OpenFL hand that string to the browser as a CSS font family
 * name, so each font is registered (with the browser's `FontFace` API) under its own virtual path.
 * Registration is asynchronous: `registerAll` calls back when every font is ready (or after a timeout), and it runs
 * before the game starts and after each mod import, so text created afterwards already finds its font.
 */
class FontLoader
{
	/** Path -> the bytes that were registered, so a re-imported (changed) font is registered again. */
	static var registered:Map<String, Bytes> = new Map();
	static var faces:Map<String, Dynamic> = new Map();
	static inline var TIMEOUT_MS = 5000;

	static function isFont(path:String):Bool
	{
		var p = path.toLowerCase();
		return StringTools.endsWith(p, ".ttf") || StringTools.endsWith(p, ".otf") || StringTools.endsWith(p, ".woff") || StringTools.endsWith(p, ".woff2");
	}

	static function supported():Bool
	{
		return js.Syntax.code("typeof FontFace !== 'undefined' && !!document.fonts");
	}

	/** Registers every font found in the mods folder that is not registered yet, then calls `onDone`. */
	public static function registerAll(onDone:Void->Void):Void
	{
		if (!supported())
		{
			onDone();
			return;
		}

		var pending:Array<Dynamic> = [];
		var present = new Map<String, Bool>();
		for (path in VirtualFS.listFilesRecursive('mods'))
		{
			if (!isFont(path) || path.indexOf('/fonts/') < 0) continue;
			present.set(path, true);
			var bytes = VirtualFS.getBytes(path);
			if (bytes == null || registered.get(path) == bytes) continue;
			pending.push(load(path, bytes));
		}

		// fonts whose files are gone (mod deleted or replaced)
		for (path in [for (p in registered.keys()) p])
			if (!present.exists(path)) forget(path);

		if (pending.length == 0)
		{
			onDone();
			return;
		}

		var finished = false;
		var finish = function()
		{
			if (finished) return;
			finished = true;
			onDone();
		};
		js.Syntax.code("Promise.all({0}).then({1}, {1})", pending, finish);
		js.Browser.window.setTimeout(finish, TIMEOUT_MS);
	}

	static function load(path:String, bytes:Bytes):Dynamic
	{
		forget(path);
		registered.set(path, bytes);
		try
		{
			// the family name is the virtual path itself, exactly what Paths.font() returns
			var face:Dynamic = js.Syntax.code("new FontFace({0}, {1}.getData().slice(0, {1}.length))", path, bytes);
			faces.set(path, face);
			return js.Syntax.code("{0}.load().then(function (f) { document.fonts.add(f); }).catch(function (e) { console.warn('Could not load the font ' + {1}, e); })", face, path);
		}
		catch (e:Dynamic)
		{
			trace('Could not register the font "$path": $e');
			return js.Syntax.code("Promise.resolve()");
		}
	}

	static function forget(path:String):Void
	{
		var face = faces.get(path);
		if (face != null) js.Syntax.code("document.fonts.delete({0})", face);
		faces.remove(path);
		registered.remove(path);
	}
}
