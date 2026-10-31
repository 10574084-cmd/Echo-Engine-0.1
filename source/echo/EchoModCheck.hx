package echo;

/**
 * The web version cannot run Lua, HScript or shaders (they need native libraries). A mod that builds its stage or its effects with
 * them still loads, but its songs show black backgrounds, missing characters or odd colors. This looks for those files in the
 * mod folders of the song that is about to start, so the player is told why instead of guessing.
 */
class EchoModCheck
{
	static var told:Map<String, Bool> = new Map();

	static function count(folder:String, extensions:Array<String>):Int
	{
		var n = 0;
		try
		{
			if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return 0;
			for (file in FileSystem.readDirectory(folder))
			{
				var lower = file.toLowerCase();
				for (ext in extensions)
					if (StringTools.endsWith(lower, ext)) { n++; break; }
			}
		}
		catch (e:Dynamic) {}
		return n;
	}

	/** null when there is nothing to warn about (or it was already said this session). */
	public static function notice(song:String):String
	{
		#if html5
		var folders:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory != '') folders.push(Mods.currentModDirectory);
		for (g in Mods.getGlobalMods()) if (folders.indexOf(g) < 0) folders.push(g);

		var scripts = 0, shaders = 0;
		var songFolder = Paths.formatToSongPath(song);
		for (mod in folders)
		{
			var base = Paths.mods(mod + '/');
			for (sub in ['scripts', 'stages', 'custom_events', 'custom_notetypes', 'data/' + songFolder, 'characters'])
				scripts += count(base + sub, ['.lua', '.hx']);
			shaders += count(base + 'shaders', ['.frag', '.vert']);
		}
		if (scripts + shaders == 0) return null;

		var key = folders.join('|') + '#' + songFolder;
		if (told.exists(key)) return null;
		told.set(key, true);

		var what = new Array<String>();
		if (scripts > 0) what.push('Lua/HScript: $scripts');
		if (shaders > 0) what.push('shaders: $shaders');
		return EchoLang.t('This mod uses scripts or shaders, which the web version cannot run.\nExpect black backgrounds, missing characters or odd colors.') + '\n(' + what.join(', ') + ')';
		#else
		return null;
		#end
	}
}
