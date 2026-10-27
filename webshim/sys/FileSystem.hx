package sys;

/**
 * html5 replacement for sys.FileSystem.
 * Only the calls Psych Engine actually makes are implemented, all of them backed by webfs.VirtualFS.
 *
 * Note: the game's own assets (assets/...) are NOT in the virtual file system, they are served by Lime's asset libraries.
 * Only "mods/..." and a few small save files live here.
 */
class FileSystem
{
	public static inline function exists(path:String):Bool
		return webfs.VirtualFS.exists(path);

	public static inline function isDirectory(path:String):Bool
		return webfs.VirtualFS.isDirectory(path);

	public static inline function readDirectory(path:String):Array<String>
		return webfs.VirtualFS.readDirectory(path);

	public static inline function createDirectory(path:String):Void
		webfs.VirtualFS.createDirectory(path);

	public static inline function deleteFile(path:String):Void
		webfs.VirtualFS.deleteFile(path);

	public static inline function deleteDirectory(path:String):Void
		webfs.VirtualFS.deleteDirectoryRecursive(path);

	public static inline function fullPath(path:String):String
		return webfs.VirtualFS.normalize(path);

	public static inline function absolutePath(path:String):String
		return webfs.VirtualFS.normalize(path);
}
