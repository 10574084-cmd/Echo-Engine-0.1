package webfs;

#if !html5
#error "webfs.IDBStore only exists for the html5 target"
#end

import haxe.io.Bytes;
import js.Browser;
import js.lib.Uint8Array;

/**
 * Tiny IndexedDB wrapper: one object store ("files") keyed by file path, values are the raw bytes.
 * Every operation degrades to a no-op when IndexedDB is unavailable (private mode, blocked storage...),
 * in which case imported mods simply last until the page is closed.
 */
class IDBStore
{
	static inline var DB_NAME = "psych-engine-web";
	static inline var STORE = "files";

	static var db:Dynamic = null;
	static var failed:Bool = false;

	static function open(onOpen:Dynamic->Void):Void
	{
		if (db != null)
		{
			onOpen(db);
			return;
		}
		if (failed)
		{
			onOpen(null);
			return;
		}

		try
		{
			var factory:Dynamic = untyped Browser.window.indexedDB;
			if (factory == null)
			{
				failed = true;
				onOpen(null);
				return;
			}

			var request:Dynamic = factory.open(DB_NAME, 1);
			request.onupgradeneeded = function(_)
			{
				var database:Dynamic = request.result;
				if (!database.objectStoreNames.contains(STORE))
					database.createObjectStore(STORE);
			};
			request.onsuccess = function(_)
			{
				db = request.result;
				onOpen(db);
			};
			request.onerror = function(_)
			{
				failed = true;
				trace("IndexedDB could not be opened, mods will not be saved between sessions.");
				onOpen(null);
			};
			request.onblocked = function(_)
			{
				failed = true;
				onOpen(null);
			};
		}
		catch (e:Dynamic)
		{
			failed = true;
			trace('IndexedDB is not available: $e');
			onOpen(null);
		}
	}

	public static function loadAll(onLoaded:Map<String, Bytes>->Void):Void
	{
		open(function(database)
		{
			var result:Map<String, Bytes> = new Map();
			if (database == null)
			{
				onLoaded(result);
				return;
			}

			try
			{
				var transaction:Dynamic = database.transaction([STORE], "readonly");
				var store:Dynamic = transaction.objectStore(STORE);
				var cursorRequest:Dynamic = store.openCursor();
				cursorRequest.onsuccess = function(_)
				{
					var cursor:Dynamic = cursorRequest.result;
					if (cursor != null)
					{
						var data:Uint8Array = cursor.value;
						result.set(cursor.key, Bytes.ofData(data.buffer));
						Reflect.callMethod(cursor, Reflect.field(cursor, "continue"), []); // "continue" is a Haxe keyword
					}
					else
						onLoaded(result);
				};
				cursorRequest.onerror = function(_) onLoaded(result);
			}
			catch (e:Dynamic)
			{
				trace('Could not read stored files: $e');
				onLoaded(result);
			}
		});
	}

	public static function put(entries:Map<String, Bytes>):Void
	{
		open(function(database)
		{
			if (database == null) return;
			try
			{
				var transaction:Dynamic = database.transaction([STORE], "readwrite");
				var store:Dynamic = transaction.objectStore(STORE);
				for (path => data in entries)
					store.put(new Uint8Array(data.getData()), path);
				transaction.onerror = function(_) trace("Failed to store files (storage quota exceeded?). Mods will not be kept after closing the page.");
			}
			catch (e:Dynamic)
			{
				trace('Could not store files: $e');
			}
		});
	}

	public static function remove(paths:Array<String>):Void
	{
		if (paths.length == 0) return;
		open(function(database)
		{
			if (database == null) return;
			try
			{
				var transaction:Dynamic = database.transaction([STORE], "readwrite");
				var store:Dynamic = transaction.objectStore(STORE);
				for (path in paths)
					Reflect.callMethod(store, Reflect.field(store, "delete"), [path]);
			}
			catch (e:Dynamic)
			{
				trace('Could not remove stored files: $e');
			}
		});
	}
}
