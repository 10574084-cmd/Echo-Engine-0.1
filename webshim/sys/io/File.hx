package sys.io;

import haxe.io.Bytes;

/** html5 replacement for sys.io.File, backed by webfs.VirtualFS (see sys.FileSystem). */
class File
{
	public static inline function getContent(path:String):String
		return webfs.VirtualFS.getContent(path);

	public static inline function getBytes(path:String):Bytes
		return webfs.VirtualFS.getBytes(path);

	public static inline function saveContent(path:String, content:String):Void
		webfs.VirtualFS.saveContent(path, content);

	public static inline function saveBytes(path:String, bytes:Bytes):Void
		webfs.VirtualFS.saveBytes(path, bytes);
}
