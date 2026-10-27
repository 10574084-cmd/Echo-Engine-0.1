package states;

import flixel.FlxState;

import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;

import backend.StageData;

import haxe.io.Path;

/**
	Loading screen.

	On desktop all the assets are local files, so this state is never shown (see `getNextState`).

	On the web only the "default" library (assets/shared + fonts) is downloaded when the page opens.
	Everything else is downloaded right before it is needed (see Project.xml):
	 - the library of the week that is about to be played ("week1", "week2"...)
	 - the Inst / Voices files of the song that is about to be played (the "songs" library only contains a manifest)
	 - the files of mod songs (they live in the virtual file system, so they are already in memory)
**/
class LoadingState extends MusicBeatState
{
	inline static var MIN_TIME = 0.5;

	var target:FlxState;
	var stopMusic = false;
	var directory:String;
	var callbacks:MultiCallback;
	var targetShit:Float = 0;

	function new(target:FlxState, stopMusic:Bool, directory:String)
	{
		super();
		this.target = target;
		this.stopMusic = stopMusic;
		this.directory = directory;
	}

	var funkay:FlxSprite;
	var loadBar:FlxSprite;
	override function create()
	{
		var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xffcaff4d);
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		funkay = new FlxSprite(0, 0).loadGraphic(Paths.getPath('images/funkay.png', IMAGE));
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		add(funkay);
		funkay.antialiasing = ClientPrefs.data.antialiasing;
		funkay.scrollFactor.set();
		funkay.screenCenter();

		loadBar = new FlxSprite(0, FlxG.height - 20).makeGraphic(FlxG.width, 10, 0xffff16d2);
		loadBar.screenCenter(X);
		loadBar.scale.x = 0;
		add(loadBar);

		callbacks = new MultiCallback(onLoad);
		var introComplete = callbacks.add("introComplete");

		if (directory != null && directory.length > 0 && directory != 'shared')
			checkLibrary(directory);

		if (Std.isOfType(target, PlayState) && PlayState.SONG != null)
			checkLoadSong(PlayState.SONG.song);

		var fadeTime = 0.5;
		FlxG.camera.fade(FlxG.camera.bgColor, fadeTime, true);
		new FlxTimer().start(fadeTime + MIN_TIME, function(_) introComplete());

		super.create();
	}

	/** Downloads the Inst / Voices files of a song that comes with the game (mod songs are already in memory). */
	function checkLoadSong(song:String)
	{
		var songFolder:String = 'assets/songs/' + Paths.formatToSongPath(song) + '/';

		#if html5
		// songs that come from mods live in the virtual file system: the browser still has to load their audio
		for (path in modSongSounds(song))
			webfs.MediaDecoder.preloadSound(path, callbacks.add("mod song:" + path));
		#end

		var librariesReady = callbacks.add("songs library");

		Assets.loadLibrary("songs").onComplete(function(_)
		{
			for (id in songSoundIds(songFolder))
			{
				if (Assets.cache.hasSound(id)) continue;

				var callback = callbacks.add("song:" + id);
				Assets.loadSound(id).onComplete(function(_) callback()).onError(function(e)
				{
					trace('Could not load $id: $e');
					callback();
				});
			}
			librariesReady();
		}).onError(function(e)
		{
			trace('Could not open the songs library: $e');
			librariesReady();
		});
	}

	function checkLibrary(library:String)
	{
		if (!libraryNeedsLoading(library)) return;

		var callback = callbacks.add("library:" + library);
		Assets.loadLibrary(library).onComplete(function(_)
		{
			#if html5 webfs.VirtualFS.invalidateAssetIndex(); #end
			callback();
		}).onError(function(e)
		{
			trace('Could not load the library "$library": $e');
			callback();
		});
	}

	/** Ids (in the form "songs:assets/songs/bopeebo/Inst.mp3") of every sound a song's folder has in the songs library. */
	static function songSoundIds(songFolder:String):Array<String>
	{
		var ids:Array<String> = [];
		var library = Assets.getLibrary("songs");
		if (library == null) return ids;

		for (id in library.list(null))
		{
			if (id.startsWith(songFolder) && Path.extension(id).toLowerCase() == Paths.SOUND_EXT)
				ids.push('songs:' + id);
		}
		return ids;
	}

	#if html5
	/** Inst / Voices files of a song inside the mods folder (any mod: the engine picks the right one when playing). */
	static function modSongSounds(song:String):Array<String>
	{
		var songPath = Paths.formatToSongPath(song);
		var pattern = new EReg('^mods/(?:[^/]+/)?songs/' + EReg.escape(songPath) + '/(Inst|Voices)[^/]*\\.(mp3|ogg|wav)$', '');
		return [for (file in webfs.VirtualFS.listFilesRecursive('mods')) if (pattern.match(file)) file];
	}
	#end

	/** True when a library with that name is part of the game but has not been downloaded yet. */
	static function libraryNeedsLoading(library:String):Bool
	{
		@:privateAccess
		if (!LimeAssets.libraryPaths.exists(library)) return false; // not a library of the game (a mod folder, for example)
		return Assets.getLibrary(library) == null;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		funkay.setGraphicSize(Std.int(0.88 * FlxG.width + 0.9 * (funkay.width - 0.88 * FlxG.width)));
		funkay.updateHitbox();
		if(controls.ACCEPT)
		{
			funkay.setGraphicSize(Std.int(funkay.width + 60));
			funkay.updateHitbox();
		}

		if(callbacks != null) {
			targetShit = FlxMath.remapToRange(callbacks.numRemaining / callbacks.length, 1, 0, 0, 1);
			loadBar.scale.x += 0.5 * (targetShit - loadBar.scale.x);
		}
	}

	function onLoad()
	{
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		MusicBeatState.switchState(target);
	}

	inline static public function loadAndSwitchState(target:FlxState, stopMusic = false)
	{
		MusicBeatState.switchState(getNextState(target, stopMusic));
	}

	static function getNextState(target:FlxState, stopMusic = false):FlxState
	{
		var directory:String = 'shared';
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if(weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);

		#if html5
		if (needsDownloads(target, directory))
			return new LoadingState(target, stopMusic, directory);
		#end

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		return target;
	}

	#if html5
	/** Whether something has to be downloaded before `target` can be shown. */
	static function needsDownloads(target:FlxState, directory:String):Bool
	{
		if (directory != 'shared' && libraryNeedsLoading(directory))
			return true;

		if (Std.isOfType(target, PlayState) && PlayState.SONG != null)
		{
			// the songs library is opened on the loading screen, it is cheap (a manifest, no audio)
			if (Assets.getLibrary("songs") == null) return true;

			var songFolder:String = 'assets/songs/' + Paths.formatToSongPath(PlayState.SONG.song) + '/';
			for (id in songSoundIds(songFolder))
			{
				if (!Assets.cache.hasSound(id)) return true;
			}

			for (path in modSongSounds(PlayState.SONG.song))
			{
				if (!webfs.MediaDecoder.isLoaded(path)) return true;
			}
		}
		return false;
	}
	#end

	override function destroy()
	{
		super.destroy();

		callbacks = null;
	}
}

class MultiCallback
{
	public var callback:Void->Void;
	public var logId:String = null;
	public var length(default, null) = 0;
	public var numRemaining(default, null) = 0;

	var unfired = new Map<String, Void->Void>();
	var fired = new Array<String>();

	public function new (callback:Void->Void, logId:String = null)
	{
		this.callback = callback;
		this.logId = logId;
	}

	public function add(id = "untitled")
	{
		id = '$length:$id';
		length++;
		numRemaining++;
		var func:Void->Void = null;
		func = function ()
		{
			if (unfired.exists(id))
			{
				unfired.remove(id);
				fired.push(id);
				numRemaining--;

				if (logId != null)
					log('fired $id, $numRemaining remaining');

				if (numRemaining == 0)
				{
					if (logId != null)
						log('all callbacks fired');
					callback();
				}
			}
			else
				log('already fired $id');
		}
		unfired[id] = func;
		return func;
	}

	inline function log(msg):Void
	{
		if (logId != null)
			trace('$logId: $msg');
	}

	public function getFired() return fired.copy();
	public function getUnfired() return [for (id in unfired.keys()) id];
}
