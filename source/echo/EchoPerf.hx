package echo;

import openfl.system.System;

/** Optimization presets, cache cleaning and the memory watchdog. */
class EchoPerf
{
	public static final PRESETS:Array<String> = ['Low', 'Balanced', 'High', 'Custom'];

	/** Applies a preset to the individual graphics settings (they stay editable; editing one switches the preset to Custom). */
	public static function applyPreset(name:String):Void
	{
		var d = ClientPrefs.data;
		switch (name)
		{
			case 'Low':
				d.shaders = false;      // no shaders / screen effects
				d.lowQuality = true;    // no background details, particles or animated props
				d.antialiasing = false; // cheaper rendering
				d.flashing = false;     // no lighting / flash effects
				d.camZooms = false;
				d.cacheOnGPU = false;
				d.echoShowMemory = false;
			case 'Balanced':
				d.shaders = true;
				d.lowQuality = false;
				d.antialiasing = true;
				d.flashing = true;
				d.camZooms = true;
				d.cacheOnGPU = false;
			case 'High':
				d.shaders = true;
				d.lowQuality = false;
				d.antialiasing = true;
				d.flashing = true;
				d.camZooms = true;
				d.cacheOnGPU = false;
				d.framerate = Std.int(Math.max(d.framerate, 120));
				#if !html5
				FlxG.updateFramerate = FlxG.drawFramerate = d.framerate;
				#end
		}
		d.echoPreset = name;
		ClientPrefs.saveSettings();
	}

	/** The next screen change also frees the images and sounds nobody is using (freeing them while a menu is open would break it). */
	static var pendingClean:Bool = false;

	/**
	 * Clears the media cache now and asks for the full cleaning (images, sounds) to happen when the next screen opens.
	 * The images cannot be freed on the spot: the screen that is open is still drawing them.
	 */
	public static function clearCaches():String
	{
		#if html5
		webfs.MediaDecoder.releaseAll();
		webfs.VirtualFS.invalidateAssetIndex();
		#end
		pendingClean = true;
		System.gc();
		return 'Media cache cleared. Images and sounds are freed when the next screen opens.';
	}

	static inline var AUTO_CLEAN_BYTES:Float = 700 * 1024 * 1024;

	/** Connected to FlxG.signals.preStateCreate: the old screen is gone and the new one has not loaded anything yet. */
	public static function beforeStateCreate(_):Void
	{
		var d = ClientPrefs.data;
		var high = System.totalMemory > AUTO_CLEAN_BYTES;
		if (!pendingClean && !d.echoLabAlwaysClean && !(d.echoAutoClean && high)) return;
		pendingClean = false;
		var before = System.totalMemory;
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		#if html5
		webfs.MediaDecoder.releaseAll();
		#end
		trace('echo: cache cleaned (' + flixel.util.FlxStringUtil.formatBytes(Math.max(0, before - System.totalMemory)) + ' freed)');
	}
}
