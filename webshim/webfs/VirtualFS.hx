package webfs;

#if !html5
#error "webfs.VirtualFS only exists for the html5 target"
#end

import haxe.io.Bytes;

/**
 * An in-memory file system for the web build.
 *
 * Browsers have no disk access, but a lot of Psych Engine code (mods, weeks, characters, stages...)
 * is written against `sys.FileSystem` / `sys.io.File`. Those two classes are replaced on html5 by thin wrappers
 * (see webshim/sys) that talk to this class, so the engine code keeps working unchanged.
 *
 * Everything lives in RAM (synchronous access is a hard requirement of the engine) and is mirrored
 * into IndexedDB (see `IDBStore`) so imported mods survive page reloads.
 */
class VirtualFS
{
	/** Every file, keyed by its normalized path (forward slashes, no leading "./", no trailing "/"). */
	static var files:Map<String, Bytes> = new Map();

	/** directory path -> names of its direct children. The root directory is "". */
	static var children:Map<String, Map<String, Bool>> = new Map();

	/** Set to true once `init` has finished loading whatever was stored in IndexedDB. */
	public static var ready(default, null):Bool = false;

	/** Fired whenever the contents of the file system change (used by the mods menu to refresh itself). */
	public static var onChange:Array<Void->Void> = [];

	// ------------------------------------------------------------------------------------------
	// Setup
	// ------------------------------------------------------------------------------------------

	/** Loads persisted files from IndexedDB, then calls `onReady` (always, even when storage is unavailable). */
	public static function init(onReady:Void->Void):Void
	{
		if (ready)
		{
			onReady();
			return;
		}

		IDBStore.loadAll(function(loaded:Map<String, Bytes>)
		{
			for (path => data in loaded)
				putFile(path, data);
			ready = true;
			onReady();
		});
	}

	// ------------------------------------------------------------------------------------------
	// sys.FileSystem equivalents
	// ------------------------------------------------------------------------------------------

	public static function normalize(path:String):String
	{
		if (path == null) return "";
		var p = path.split("\\").join("/");
		while (p.indexOf("//") >= 0) p = p.split("//").join("/");
		while (StringTools.startsWith(p, "./")) p = p.substr(2);
		while (StringTools.endsWith(p, "/")) p = p.substr(0, p.length - 1);
		if (p == ".") p = "";
		return p;
	}

	public static function exists(path:String):Bool
	{
		var p = normalize(path);
		return files.exists(p) || children.exists(p) || isAsset(p) || assetDirs().exists(p);
	}

	public static function isDirectory(path:String):Bool
	{
		var p = normalize(path);
		return children.exists(p) || assetDirs().exists(p);
	}

	public static function isFile(path:String):Bool
	{
		var p = normalize(path);
		return files.exists(p) || isAsset(p);
	}

	public static function readDirectory(path:String):Array<String>
	{
		var p = normalize(path);
		var names:Map<String, Bool> = new Map();

		var kids = children.get(p);
		if (kids != null) for (name in kids.keys()) names.set(name, true);

		var assetKids = assetDirs().get(p);
		if (assetKids != null) for (name in assetKids.keys()) names.set(name, true);

		var list = [for (name in names.keys()) name];
		list.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return list;
	}

	public static function createDirectory(path:String):Void
	{
		ensureDirectory(normalize(path));
	}

	public static function deleteFile(path:String):Void
	{
		var p = normalize(path);
		if (!files.exists(p)) return;
		files.remove(p);
		unlink(p);
		IDBStore.remove([p]);
		changed();
	}

	/** Removes a directory and everything inside of it (unlike sys.FileSystem.deleteDirectory, which needs an empty one). */
	public static function deleteDirectoryRecursive(path:String):Void
	{
		var p = normalize(path);
		if (!children.exists(p)) return;

		var removed:Array<String> = [];
		var prefix = p + "/";
		for (file in files.keys())
		{
			if (file == p || StringTools.startsWith(file, prefix))
				removed.push(file);
		}
		for (file in removed)
		{
			files.remove(file);
			unlink(file);
		}

		// drop the now empty directories (deepest first)
		var dirs = [for (dir in children.keys()) if (dir == p || StringTools.startsWith(dir, prefix)) dir];
		dirs.sort(function(a, b) return b.length - a.length);
		for (dir in dirs)
		{
			children.remove(dir);
			unlinkFromParent(dir);
		}

		IDBStore.remove(removed);
		changed();
	}

	// ------------------------------------------------------------------------------------------
	// sys.io.File equivalents
	// ------------------------------------------------------------------------------------------

	public static function getBytes(path:String):Bytes
	{
		var p = normalize(path);
		var data = files.get(p);
		if (data != null) return data;
		if (isAsset(p))
		{
			var bytes = openfl.utils.Assets.getBytes(p);
			if (bytes != null) return bytes;
		}
		throw 'File not found: $path';
	}

	public static function getContent(path:String):String
	{
		var p = normalize(path);
		var data = files.get(p);
		if (data != null) return data.toString();
		if (isAsset(p))
		{
			var text = openfl.utils.Assets.getText(p);
			if (text != null) return text;
		}
		throw 'File not found: $path';
	}

	public static function saveBytes(path:String, data:Bytes, persist:Bool = true):Void
	{
		var p = normalize(path);
		putFile(p, data);
		if (persist) IDBStore.put([p => data]);
		changed();
	}

	public static function saveContent(path:String, content:String):Void
	{
		saveBytes(path, Bytes.ofString(content));
	}

	/** Adds many files in one go (used by the mod importer): a single IndexedDB transaction and a single change event. */
	public static function saveMany(entries:Map<String, Bytes>):Void
	{
		var normalized:Map<String, Bytes> = new Map();
		for (path => data in entries)
		{
			var p = normalize(path);
			putFile(p, data);
			normalized.set(p, data);
		}
		IDBStore.put(normalized);
		changed();
	}

	/** Every file path below `dir` (recursive). */
	public static function listFilesRecursive(dir:String):Array<String>
	{
		var p = normalize(dir);
		var prefix = p == "" ? "" : p + "/";
		return [for (file in files.keys()) if (prefix == "" || StringTools.startsWith(file, prefix)) file];
	}

	public static function sizeOf(dir:String):Int
	{
		var total = 0;
		for (file in listFilesRecursive(dir)) total += files.get(file).length;
		return total;
	}

	// ------------------------------------------------------------------------------------------
	// The game's own assets (read only)
	// ------------------------------------------------------------------------------------------
	//
	// On desktop "assets/..." are real files, and some engine code checks them with FileSystem.exists / File.getContent.
	// On the web those files live in Lime's asset libraries, so they are exposed here too.

	static var assetDirIndex:Map<String, Map<String, Bool>> = null;

	/** Call after a Lime asset library has been downloaded so its folders show up in readDirectory / exists. */
	public static function invalidateAssetIndex():Void
	{
		assetDirIndex = null;
	}

	/** True when `p` (already normalized) is a text-readable asset of the game that is currently loaded. */
	static function isAsset(p:String):Bool
	{
		if (!StringTools.startsWith(p, "assets/")) return false;
		return openfl.utils.Assets.exists(p);
	}

	/** directory -> children of every asset id of the loaded libraries (rebuilt when more libraries get loaded). */
	static function assetDirs():Map<String, Map<String, Bool>>
	{
		if (assetDirIndex != null) return assetDirIndex;

		assetDirIndex = new Map();
		for (id in openfl.utils.Assets.list())
		{
			if (id.indexOf(":") >= 0 || !StringTools.startsWith(id, "assets/")) continue;

			var parts = id.split("/");
			var dir = "";
			for (i in 0...parts.length)
			{
				var kids = assetDirIndex.get(dir);
				if (kids == null)
				{
					kids = new Map();
					assetDirIndex.set(dir, kids);
				}
				kids.set(parts[i], true);
				dir = dir == "" ? parts[i] : dir + "/" + parts[i];
			}
		}
		return assetDirIndex;
	}

	// ------------------------------------------------------------------------------------------
	// Internals
	// ------------------------------------------------------------------------------------------

	static function putFile(p:String, data:Bytes):Void
	{
		var slash = p.lastIndexOf("/");
		var parent = slash < 0 ? "" : p.substr(0, slash);
		var name = slash < 0 ? p : p.substr(slash + 1);
		ensureDirectory(parent);
		children.get(parent).set(name, true);
		files.set(p, data);
	}

	static function ensureDirectory(dir:String):Void
	{
		if (children.exists(dir)) return;
		children.set(dir, new Map());
		if (dir == "") return;

		var slash = dir.lastIndexOf("/");
		var parent = slash < 0 ? "" : dir.substr(0, slash);
		var name = slash < 0 ? dir : dir.substr(slash + 1);
		ensureDirectory(parent);
		children.get(parent).set(name, true);
	}

	static function unlink(file:String):Void
	{
		unlinkFromParent(file);
	}

	static function unlinkFromParent(path:String):Void
	{
		var slash = path.lastIndexOf("/");
		var parent = slash < 0 ? "" : path.substr(0, slash);
		var name = slash < 0 ? path : path.substr(slash + 1);
		var kids = children.get(parent);
		if (kids != null) kids.remove(name);
	}

	static function changed():Void
	{
		for (callback in onChange.copy()) callback();
	}
}
