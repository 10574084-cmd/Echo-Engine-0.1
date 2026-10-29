package options;

import echo.EchoAdmin;
import echo.EchoOptions;
import states.editors.MasterEditorMenu;

/** The hidden admin options (see echo.EchoAdmin). */
class EchoAdminSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'xd (admin)';
		rpcTitle = 'Echo Admin Menu';

		if (EchoAdmin.editorsAllowed()) addOption(EchoOptions.action('Open Editors',
			'Chart editor, character editor, stage and week editors.\nIn a song or in the main menu you can also press 7 (chart) and 8 (character).',
			function()
			{
				// the editors replace the whole screen: leave the options first
				FlxG.sound.music?.stop();
				MusicBeatState.switchState(new MasterEditorMenu());
			}));

		addOption(EchoOptions.bool('Botplay',
			'The game plays your side for you, in every song, also in online duels.\nIn a duel your rival sees "[BOT]" next to your score.',
			function() return ClientPrefs.data.echoAdminBot,
			function(v:Bool)
			{
				ClientPrefs.data.echoAdminBot = v;
				// opened from the pause menu: apply it to the song right now
				var game = states.PlayState.instance;
				if (game != null)
				{
					game.cpuControlled = v || ClientPrefs.getGameplaySetting('botplay');
					game.botplayTxt.visible = game.cpuControlled;
					game.botplayTxt.alpha = 1;
					game.botplaySine = 0;
				}
			},
			false));

		addOption(EchoOptions.bool('God Mode',
			'Your health is always full in offline songs. (Does nothing in duels: nobody dies there.)',
			function() return ClientPrefs.data.echoAdminGod,
			function(v:Bool) ClientPrefs.data.echoAdminGod = v,
			false));

		addOption(EchoOptions.action('Lock Admin',
			'Turns the admin options off and asks for the code again next time.',
			function()
			{
				EchoAdmin.lock();
				close();
			}));

		super();
	}
}
