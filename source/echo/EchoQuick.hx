package echo;

#if html5
import flixel.FlxG;
import states.FlashingState;
import states.LoadingState;
import states.MainMenuState;
import states.OutdatedState;
import states.PlayState;
import states.TitleState;
#end

/**
 * Admin quick keys (only after the admin code was accepted, see EchoAdmin):
 *   O = global events menu      P = force everybody to a song (the one the admin picks)      M = global message
 * They open the matching section of the xd menu (Echo Live, see EchoLive / EchoLiveSend) from almost any screen. During a
 * song the game is paused first. They are off in the main menu (the secret words are typed there), in the options
 * (keys are rebound there), in the editors, while loading and in online duels.
 */
class EchoQuick
{
	public static function install():Void
	{
		#if html5
		FlxG.signals.postUpdate.add(update);
		#end
	}

	#if html5
	static function update():Void
	{
		if (ClientPrefs.data == null || !EchoAdmin.isAdmin() || online.Session.active) return;

		var section:String = null;
		if (FlxG.keys.justPressed.O) section = 'events';
		else if (FlxG.keys.justPressed.P) section = 'song';
		else if (FlxG.keys.justPressed.M) section = 'message';
		if (section == null) return;

		var state:Dynamic = FlxG.state;
		if (state == null || state.subState != null || blocked(state)) return;

		if (Std.isOfType(state, PlayState))
		{
			var game:PlayState = cast state;
			if (!game.startedCountdown || !game.canPause || game.endingSong || game.paused) return;
			EchoAdmin.quickOpen = section;
			game.openPauseMenu();
		}
		else
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			state.openSubState(new options.EchoAdminSubState(section));
		}
	}

	static function blocked(state:Dynamic):Bool
	{
		if (Std.isOfType(state, TitleState) || Std.isOfType(state, FlashingState) || Std.isOfType(state, OutdatedState)
			|| Std.isOfType(state, LoadingState) || Std.isOfType(state, MainMenuState)) return true;
		var name = Type.getClassName(Type.getClass(state));
		return StringTools.startsWith(name, 'states.editors') || StringTools.startsWith(name, 'online.') || StringTools.startsWith(name, 'options.');
	}
	#end
}
