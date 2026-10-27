package webfs;

#if !html5
#error "webfs.MediaDecoder only exists for the html5 target"
#end

import haxe.io.Bytes;
import haxe.io.BytesInput;
import lime.media.AudioBuffer;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.utils.ByteArray;

/**
 * Turns the raw bytes of a mod file (kept in the virtual file system) into something the engine can use.
 *
 * Browsers can only decode images asynchronously, but Psych Engine asks for images synchronously
 * (`Paths.image` has to return right away), so PNGs are decoded in plain Haxe with the `format` library.
 *
 * Sounds can be created synchronously from bytes, but they are only usable (length, playback) once the browser has
 * loaded them; `preloadSound` does that and is called from the loading screen for the files a song is going to need.
 */
@:access(openfl.media.Sound)
class MediaDecoder
{
	/**
	 * Sounds created from virtual files, keyed by path. The loading screen preloads a song's audio and the engine asks for it
	 * again once the song starts (after Paths cleared its own caches), so this cache has to outlive Paths' bookkeeping:
	 * a new Sound would start unloaded and report a length of 0.
	 * It only keeps the most recently used files, every one of them holds the whole file as a base64 string.
	 */
	static var sounds:Map<String, Sound> = new Map();
	static var recent:Array<String> = [];
	static inline var MAX_CACHED_SOUNDS = 8;

	// ------------------------------------------------------------------------------------------
	// Images
	// ------------------------------------------------------------------------------------------

	/** Decodes a PNG file of the virtual file system. Returns null (and traces why) when it can't be read. */
	public static function getBitmap(path:String):BitmapData
	{
		try
		{
			return decodePng(VirtualFS.getBytes(path));
		}
		catch (e:Dynamic)
		{
			trace('Could not decode image "$path": $e');
			return null;
		}
	}

	public static function decodePng(bytes:Bytes):BitmapData
	{
		var reader = new format.png.Reader(new BytesInput(bytes));
		reader.checkCRC = false; // a lot faster, and a broken file would fail to inflate anyway
		var png = reader.read();

		var header = format.png.Tools.getHeader(png);
		var width = header.width;
		var height = header.height;

		// extract32 gives BGRA, BitmapData.setPixels wants ARGB
		var bgra = format.png.Tools.extract32(png);
		var argb = Bytes.alloc(width * height * 4);
		var i = 0;
		var length = width * height * 4;
		while (i < length)
		{
			argb.set(i, bgra.get(i + 3));
			argb.set(i + 1, bgra.get(i + 2));
			argb.set(i + 2, bgra.get(i + 1));
			argb.set(i + 3, bgra.get(i));
			i += 4;
		}

		var bitmap = new BitmapData(width, height, true, 0);
		bitmap.setPixels(bitmap.rect, ByteArray.fromBytes(argb));
		return bitmap;
	}

	// ------------------------------------------------------------------------------------------
	// Sounds
	// ------------------------------------------------------------------------------------------

	/** The sound stored at `path`. It is created on the spot but is only fully usable after `preloadSound` finished. */
	public static function getSound(path:String):Sound
	{
		// Paths builds some mod paths with a double slash ("songs//song/Inst.ogg"): the cache must see them as the same file
		path = VirtualFS.normalize(path);
		var sound = sounds.get(path);
		if (sound != null)
		{
			recent.remove(path);
			recent.push(path);
			return sound;
		}

		try
		{
			var buffer = AudioBuffer.fromBytes(VirtualFS.getBytes(path));
			if (buffer == null) return null;
			sound = Sound.fromAudioBuffer(buffer);
			sounds.set(path, sound);
			recent.push(path);
			while (recent.length > MAX_CACHED_SOUNDS)
				sounds.remove(recent.shift());
			return sound;
		}
		catch (e:Dynamic)
		{
			trace('Could not create sound "$path": $e');
			return null;
		}
	}

	/** Makes the browser load the sound (so its length is known and it can start instantly), then calls `onDone`. */
	public static function preloadSound(path:String, onDone:Void->Void):Void
	{
		var sound = getSound(path);
		if (sound == null || sound.__buffer == null || sound.__buffer.src == null)
		{
			onDone();
			return;
		}

		var howl:Dynamic = sound.__buffer.src;
		if (howl.state() == "loaded")
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
		howl.once("load", finish);
		howl.once("loaderror", function(_, error)
		{
			trace('The browser could not load the sound "$path": $error');
			finish();
		});
		howl.load();
	}

	/** True when `getSound(path)` can be used right away (the browser already loaded it). */
	public static function isLoaded(path:String):Bool
	{
		var sound = getSound(path);
		if (sound == null || sound.__buffer == null || sound.__buffer.src == null) return true; // nothing to wait for
		var howl:Dynamic = sound.__buffer.src;
		return howl.state() == "loaded";
	}

	/** Forgets a sound (call it when the file it was made from has been deleted). */
	public static function releaseSound(path:String):Void
	{
		path = VirtualFS.normalize(path);
		sounds.remove(path);
		recent.remove(path);
	}
}
