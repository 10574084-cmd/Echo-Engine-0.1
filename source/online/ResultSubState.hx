package online;

#if html5
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import states.FreeplayState;

/** Shown when a song of an online duel ends: your result against the rival's. */
class ResultSubState extends MusicBeatSubstate
{
	var myScore:Int;
	var myMisses:Int;
	var myAccuracy:Float;

	var verdict:FlxText;
	var mine:FlxText;
	var theirs:FlxText;
	var hint:FlxText;
	var leaving = false;

	public function new(score:Int, misses:Int, accuracy:Float)
	{
		super();
		myScore = score;
		myMisses = misses;
		myAccuracy = accuracy * 100;
	}

	override function create()
	{
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		var bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0.8;
		bg.scrollFactor.set();
		add(bg);

		verdict = text(0, 90, FlxG.width, 72, FlxColor.WHITE);
		mine = text(60, 260, Std.int(FlxG.width / 2 - 80), 36, FlxColor.WHITE);
		theirs = text(Std.int(FlxG.width / 2 + 20), 260, Std.int(FlxG.width / 2 - 80), 36, FlxColor.WHITE);
		hint = text(0, FlxG.height - 90, FlxG.width, 26, 0xFFCCCCCC);

		Session.onRivalFinished = refresh;
		Session.onRivalLeft = refresh;
		refresh();
		super.create();
	}

	function text(x:Float, y:Float, width:Int, size:Int, color:FlxColor):FlxText
	{
		var t = new FlxText(x, y, width, '', size);
		t.setFormat(Paths.font('vcr.ttf'), size, color, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.scrollFactor.set();
		add(t);
		return t;
	}

	static function fmt(accuracy:Float):String
		return Std.string(Math.round(accuracy * 100) / 100) + '%';

	function refresh():Void
	{
		mine.text = 'YOU (${Session.myChar})\n\nScore: $myScore\nMisses: $myMisses\nAccuracy: ${fmt(myAccuracy)}';

		var rivalDone = Session.rivalFinished || Session.rivalLeft;
		if (Session.rivalFinished && !Session.rivalQuit)
			theirs.text = 'RIVAL (${Session.rivalChar})${Session.rivalBot ? ' [BOT]' : ''}\n\nScore: ${Session.rivalScore}\nMisses: ${Session.rivalMisses}\nAccuracy: ${fmt(Session.rivalAccuracy)}';
		else if (rivalDone)
			theirs.text = 'RIVAL (${Session.rivalChar})${Session.rivalBot ? ' [BOT]' : ''}\n\nLeft the song';
		else
			theirs.text = 'RIVAL (${Session.rivalChar})${Session.rivalBot ? ' [BOT]' : ''}\n\nStill playing...\nScore: ${Session.rivalScore}';

		if (!rivalDone)
		{
			verdict.text = 'WAITING FOR YOUR RIVAL';
			verdict.color = FlxColor.WHITE;
			hint.text = 'ENTER: go back to the song list without waiting';
		}
		else
		{
			var win:Int; // 1 = you, -1 = rival, 0 = tie
			if (!Session.rivalFinished || Session.rivalQuit) win = 1;
			else if (myScore != Session.rivalScore) win = myScore > Session.rivalScore ? 1 : -1;
			else win = myAccuracy > Session.rivalAccuracy ? 1 : (myAccuracy < Session.rivalAccuracy ? -1 : 0);

			verdict.text = win == 1 ? 'YOU WIN!' : (win == -1 ? 'YOU LOSE' : 'TIE!');
			verdict.color = win == 1 ? FlxColor.LIME : (win == -1 ? 0xFFFF6666 : FlxColor.YELLOW);
			hint.text = Session.rivalLeft ? 'Your rival left the room.   ENTER: continue' : 'ENTER: back to the song list   -   ESC: leave the room';
		}
	}

	override function update(elapsed:Float)
	{
		if (!leaving)
		{
			if (controls.ACCEPT)
				leave(Session.rivalLeft ? false : true);
			else if (controls.BACK)
				leave(false);
		}
		super.update(elapsed);
	}

	function leave(stayInRoom:Bool):Void
	{
		leaving = true;
		Session.onRivalFinished = null;
		Session.onRivalLeft = null;
		Mods.loadTopMod();
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		PlayState.changedDifficulty = false;
		if (stayInRoom)
			MusicBeatState.switchState(new FreeplayState());
		else
		{
			Session.end(!Session.rivalLeft);
			MusicBeatState.switchState(new OnlineState());
		}
	}
}
#end
