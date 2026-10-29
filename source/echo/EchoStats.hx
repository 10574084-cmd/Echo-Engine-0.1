package echo;

/** Numbers shown in Options > Echo Extra > Echo Extras > Stats. Saved with the rest of the game's save data. */
class EchoStats
{
	static function data():Dynamic
	{
		var d:Dynamic = FlxG.save.data.echoStats;
		if (d == null)
		{
			d = {
				songsPlayed: 0, songsCompleted: 0, totalScore: 0, notesHit: 0, misses: 0,
				bestScore: 0, bestScoreSong: '', bestAccuracy: 0.0, bestAccuracySong: '', seconds: 0.0
			};
			FlxG.save.data.echoStats = d;
		}
		return d;
	}

	public static function get():Dynamic
		return data();

	public static function songStarted():Void
	{
		data().songsPlayed++;
		FlxG.save.flush();
	}

	/** `seconds` is how long the player was in the song. */
	public static function songEnded(song:String, completed:Bool, score:Int, hits:Int, misses:Int, accuracy:Float, seconds:Float):Void
	{
		var d = data();
		if (completed) d.songsCompleted++;
		d.totalScore += score;
		d.notesHit += hits;
		d.misses += misses;
		d.seconds += seconds;
		if (completed && score > d.bestScore)
		{
			d.bestScore = score;
			d.bestScoreSong = song;
		}
		if (completed && accuracy > d.bestAccuracy)
		{
			d.bestAccuracy = accuracy;
			d.bestAccuracySong = song;
		}
		FlxG.save.flush();
	}

	public static function reset():Void
	{
		FlxG.save.data.echoStats = null;
		data();
		FlxG.save.flush();
	}

	public static function formatTime(seconds:Float):String
	{
		var total = Std.int(seconds);
		var h = Std.int(total / 3600);
		var m = Std.int((total % 3600) / 60);
		return h > 0 ? '${h}h ${m}m' : '${m}m ${total % 60}s';
	}
}
