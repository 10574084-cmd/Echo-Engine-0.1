package options;

import echo.EchoStats;
import backend.Highscore;

class EchoStatsSubState extends MusicBeatSubstate
{
	var lines:FlxText;
	var confirmReset:Bool = false;
	var hint:FlxText;

	override function create()
	{
		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = echo.EchoTheme.color(0xFF5BA8F0);
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		var title = new Alphabet(0, 30, 'Stats', true);
		title.screenCenter(X);
		add(title);

		lines = new FlxText(80, 120, FlxG.width - 160, '', 26);
		lines.setFormat(Paths.font('vcr.ttf'), 26, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(lines);

		hint = new FlxText(0, FlxG.height - 50, FlxG.width, '', 22);
		hint.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(hint);

		refresh();
		super.create();
	}

	function refresh():Void
	{
		var s = EchoStats.get();
		var out = new StringBuf();
		out.add('Songs played:       ${s.songsPlayed}\n');
		out.add('Songs completed:    ${s.songsCompleted}\n');
		out.add('Total score:        ${s.totalScore}\n');
		out.add('Notes hit:          ${s.notesHit}      Misses: ${s.misses}\n');
		out.add('Time playing:       ${EchoStats.formatTime(s.seconds)}\n');
		var bestScore:String = s.bestScore > 0 ? '${s.bestScore}  (${s.bestScoreSong})' : '-';
		var bestAcc:String = s.bestAccuracy > 0 ? '${Math.round(s.bestAccuracy * 10000) / 100}%  (${s.bestAccuracySong})' : '-';
		out.add('\nBest score:         $bestScore\n');
		out.add('Best accuracy:      $bestAcc\n');

		// the five best saved scores
		var records:Array<{song:String, score:Int}> = [];
		for (song => score in Highscore.songScores)
			if (score > 0) records.push({song: song, score: score});
		records.sort(function(a, b) return b.score - a.score);
		out.add('\nTop songs:\n');
		if (records.length == 0) out.add('  (play a song to set a record)\n');
		for (i in 0...Std.int(Math.min(5, records.length)))
			out.add('  ${i + 1}. ${prettySong(records[i].song)}   ${records[i].score}\n');

		lines.text = out.toString();
		hint.text = confirmReset ? 'Press RESET again to erase the stats (any other key cancels)' : 'BACK: close   -   RESET: erase the stats';
	}

	static function prettySong(key:String):String
	{
		// saved as "song-name-difficulty"; show it as "Song Name"
		return key.split('-').map(function(w) return w.length > 0 ? w.charAt(0).toUpperCase() + w.substr(1) : w).join(' ');
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK)
		{
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		else if (controls.RESET)
		{
			if (confirmReset)
			{
				EchoStats.reset();
				confirmReset = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
			else
			{
				confirmReset = true;
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			refresh();
		}
		else if (confirmReset && (controls.ACCEPT || controls.UI_UP_P || controls.UI_DOWN_P))
		{
			confirmReset = false;
			refresh();
		}
		super.update(elapsed);
	}
}
