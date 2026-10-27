package webfs;

#if !html5
#error "webfs.ModImporter only exists for the html5 target"
#end

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.zip.Entry;
import haxe.zip.Reader;
import js.Browser;
import js.html.DivElement;
import js.html.InputElement;

typedef ImportResult =
{
	var mods:Array<String>;
	var files:Int;
	var ?error:String;
}

/**
 * Installs mods on the web build: a mod is a .zip (the same ones people already share for the desktop version)
 * that gets unpacked into the virtual file system under "mods/<name>/" and stored in IndexedDB.
 *
 * Accepted layouts:
 *  - MyMod.zip  ->  MyMod/pack.json, MyMod/images/...        (one folder, named after the mod)
 *  - MyMod.zip  ->  pack.json, images/...                    (the mod's files at the root, named after the zip)
 *  - Pack.zip   ->  mods/A/..., mods/B/...  or  A/..., B/... (several mods at once)
 */
class ModImporter
{
	/** Called after every import (successful or not) so menus can refresh themselves. */
	public static var onImported:Array<ImportResult->Void> = [];

	static var queue:Array<{name:String, file:Dynamic}> = [];
	static var working:Bool = false;
	static var dropHandlerInstalled:Bool = false;

	// ------------------------------------------------------------------------------------------
	// Entry points
	// ------------------------------------------------------------------------------------------

	/** Opens the browser's file picker (has to be called while handling a click / key press). */
	public static function pickFiles():Void
	{
		var input:InputElement = cast Browser.document.createElement("input");
		input.type = "file";
		input.accept = ".zip,application/zip,application/x-zip-compressed";
		input.multiple = true;
		input.style.display = "none";
		input.onchange = function(_)
		{
			enqueue(input.files);
			Browser.document.body.removeChild(input);
		};
		// the picker may be dismissed without firing "change", don't leave the element behind forever
		input.addEventListener("cancel", function(_) Browser.document.body.removeChild(input));
		Browser.document.body.appendChild(input);
		input.click();
	}

	/** Lets players drop .zip files anywhere on the page to install them. */
	public static function installDropHandler():Void
	{
		if (dropHandlerInstalled) return;
		dropHandlerInstalled = true;

		Browser.window.addEventListener("dragover", function(e:js.html.DragEvent) e.preventDefault());
		Browser.window.addEventListener("drop", function(e:js.html.DragEvent)
		{
			e.preventDefault();
			if (e.dataTransfer != null) enqueue(e.dataTransfer.files);
		});
	}

	/** Removes a mod (all of its files). */
	public static function deleteMod(folder:String):Void
	{
		VirtualFS.deleteDirectoryRecursive('mods/$folder');
		backend.Mods.updatedOnState = false; // rescan so modsList.txt forgets it
		toast('Removed "$folder".');
	}

	// ------------------------------------------------------------------------------------------
	// Queue
	// ------------------------------------------------------------------------------------------

	static function enqueue(files:js.html.FileList):Void
	{
		if (files == null || files.length == 0) return;

		var rejected = 0;
		for (i in 0...files.length)
		{
			var file = files[i];
			if (StringTools.endsWith(file.name.toLowerCase(), ".zip"))
				queue.push({name: file.name, file: file});
			else
				rejected++;
		}

		if (rejected > 0) toast('Only .zip files can be imported ($rejected skipped).', true);
		if (!working) next();
	}

	static function next():Void
	{
		if (queue.length == 0)
		{
			working = false;
			return;
		}
		working = true;

		var item = queue.shift();
		toast('Reading "${item.name}"...', false, true);

		// give the browser a moment to paint the message before the (blocking) unzip starts
		var read:Dynamic = item.file.arrayBuffer();
		read.then(function(buffer:Dynamic)
		{
			Browser.window.setTimeout(function()
			{
				var result = importZip(item.name, Bytes.ofData(buffer));
				finish(item.name, result);
			}, 60);
		}, function(error:Dynamic)
		{
			finish(item.name, {mods: [], files: 0, error: 'could not read the file ($error)'});
		});
	}

	static function finish(zipName:String, result:ImportResult):Void
	{
		if (result.error != null)
			toast('Could not import "$zipName": ${result.error}', true);
		else if (result.mods.length == 1)
			toast('Imported "${result.mods[0]}" (${result.files} files).');
		else
			toast('Imported ${result.mods.length} mods (${result.files} files).');

		for (callback in onImported.copy()) callback(result);
		next();
	}

	// ------------------------------------------------------------------------------------------
	// Unzipping
	// ------------------------------------------------------------------------------------------

	public static function importZip(zipName:String, data:Bytes):ImportResult
	{
		var entries:List<Entry>;
		try
		{
			entries = Reader.readZip(new BytesInput(data));
		}
		catch (e:Dynamic)
		{
			return {mods: [], files: 0, error: 'it is not a valid .zip file ($e)'};
		}

		// 1. every real file of the archive, with a clean path
		var byPath:Map<String, Entry> = new Map();
		var paths:Array<String> = [];
		for (entry in entries)
		{
			var path = entry.fileName.split("\\").join("/");
			while (StringTools.startsWith(path, "/")) path = path.substr(1);
			if (path == "" || StringTools.endsWith(path, "/")) continue; // directory entry
			if (isJunk(path)) continue;
			byPath.set(path, entry);
			paths.push(path);
		}
		if (paths.length == 0)
			return {mods: [], files: 0, error: "the .zip is empty"};

		// 2. work out which mod(s) it holds and where their files start
		var layout = detectLayout(zipName, paths);

		// 3. unpack
		var toSave:Map<String, Bytes> = new Map();
		var failed:String = null;
		for (path in paths)
		{
			var mod = layout.modOf(path);
			if (mod == null) continue;

			try
			{
				toSave.set('mods/$mod/' + layout.relativePath(path), unzipEntry(byPath.get(path)));
			}
			catch (e:Dynamic)
			{
				failed = '"$path" could not be unpacked ($e)';
				break;
			}
		}
		if (failed != null)
			return {mods: [], files: 0, error: failed};

		// 4. replace older copies of the same mod, then store everything in one go
		for (mod in layout.mods)
			VirtualFS.deleteDirectoryRecursive('mods/$mod');
		VirtualFS.saveMany(toSave);

		backend.Mods.updatedOnState = false; // makes Mods.parseList() rescan the folders and add the new mods

		var count = 0;
		for (_ in toSave) count++;
		return {mods: layout.mods, files: count};
	}

	/** haxe.zip.Reader.unzip needs haxe.zip.Uncompress, which does not exist on JS: inflate with the pure Haxe implementation. */
	static function unzipEntry(entry:Entry):Bytes
	{
		if (!entry.compressed) return entry.data;

		var out = Bytes.alloc(entry.fileSize);
		var inflate = new haxe.zip.InflateImpl(new BytesInput(entry.data), false, false); // zip stores raw deflate data (no zlib header)
		var position = 0;
		while (position < entry.fileSize)
		{
			var read = inflate.readBytes(out, position, entry.fileSize - position);
			if (read <= 0) break;
			position += read;
		}
		if (position != entry.fileSize)
			throw "invalid compressed data";
		return out;
	}

	static function isJunk(path:String):Bool
	{
		return StringTools.startsWith(path, "__MACOSX/") || path.indexOf("/__MACOSX/") >= 0
			|| StringTools.endsWith(path, ".DS_Store") || StringTools.endsWith(path, "Thumbs.db");
	}

	static function detectLayout(zipName:String, paths:Array<String>):Layout
	{
		// zip made from a "mods" folder: look inside it
		var prefix = "";
		var allInMods = true;
		for (path in paths)
		{
			if (!StringTools.startsWith(path, "mods/")) allInMods = false;
		}
		if (allInMods) prefix = "mods/";

		var rootFiles = 0;
		var tops:Map<String, Bool> = new Map();
		for (path in paths)
		{
			var rest = path.substr(prefix.length);
			var slash = rest.indexOf("/");
			if (slash < 0) rootFiles++;
			else tops.set(rest.substr(0, slash), true);
		}

		var topNames = [for (name in tops.keys()) name];
		var looksLikeModFolders = rootFiles == 0 && topNames.length > 0;
		for (name in topNames)
		{
			// "images/", "data/"... directly at the root means this is a single mod without its own folder
			if (backend.Mods.ignoreModFolders.contains(name.toLowerCase())) looksLikeModFolders = false;
		}

		if (looksLikeModFolders)
		{
			var mods = [for (name in topNames) sanitize(name)];
			return new Layout(prefix, true, mods, [for (name in topNames) name => sanitize(name)]);
		}

		var modName = sanitize(zipName.substr(0, zipName.length - 4));
		return new Layout(prefix, false, [modName], new Map());
	}

	/** Mod folder names end up in file paths and in modsList.txt ("name|1"), so keep them boring. */
	public static function sanitize(name:String):String
	{
		var clean = ~/[^A-Za-z0-9 _.\-]/g.replace(name, "_");
		clean = StringTools.trim(clean);
		return clean == "" ? "mod" : clean;
	}

	// ------------------------------------------------------------------------------------------
	// Feedback: a small message over the game (works whatever state is running)
	// ------------------------------------------------------------------------------------------

	static var toastElement:DivElement = null;
	static var toastTimer:Int = -1;

	public static function toast(message:String, isError:Bool = false, keep:Bool = false):Void
	{
		trace(message);
		if (toastElement == null)
		{
			toastElement = cast Browser.document.createElement("div");
			var style = toastElement.style;
			style.position = "fixed";
			style.left = "50%";
			style.bottom = "24px";
			style.transform = "translateX(-50%)";
			style.maxWidth = "80%";
			style.padding = "10px 18px";
			style.borderRadius = "8px";
			style.font = "16px sans-serif";
			style.color = "#fff";
			style.zIndex = "10";
			style.pointerEvents = "none";
			Browser.document.body.appendChild(toastElement);
		}

		toastElement.textContent = message;
		toastElement.style.background = isError ? "rgba(170,30,30,0.92)" : "rgba(20,20,20,0.88)";
		toastElement.style.display = "block";

		if (toastTimer >= 0) Browser.window.clearTimeout(toastTimer);
		toastTimer = keep ? -1 : Browser.window.setTimeout(function() toastElement.style.display = "none", isError ? 9000 : 4500);
	}
}

/** Where the mod(s) of a zip live inside of it. */
private class Layout
{
	public var mods(default, null):Array<String>;

	var prefix:String;
	var folderPerMod:Bool;
	var folderToMod:Map<String, String>;

	public function new(prefix:String, folderPerMod:Bool, mods:Array<String>, folderToMod:Map<String, String>)
	{
		this.prefix = prefix;
		this.folderPerMod = folderPerMod;
		this.mods = mods;
		this.folderToMod = folderToMod;
	}

	/** The mod a path of the archive belongs to (null = ignore it). */
	public function modOf(path:String):Null<String>
	{
		var rest = path.substr(prefix.length);
		if (!folderPerMod) return mods[0];

		var slash = rest.indexOf("/");
		return slash < 0 ? null : folderToMod.get(rest.substr(0, slash));
	}

	/** Path of the file relative to the mod folder. */
	public function relativePath(path:String):String
	{
		var rest = path.substr(prefix.length);
		return folderPerMod ? rest.substr(rest.indexOf("/") + 1) : rest;
	}
}
