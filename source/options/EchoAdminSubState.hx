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

		// forced chart events: only while a song is running (opened from the pause menu)
		var game = states.PlayState.instance;
		if (game != null)
		{
			var names = ['Add Camera Zoom', 'Screen Shake', 'Hey!', 'Change Scroll Speed'];
			var choice = 0;
			var which = EchoOptions.string('Event',
				'The chart event the next option fires.',
				names, function() return names[choice], function(v:String) choice = Std.int(Math.max(0, names.indexOf(v))), names[0]);
			addOption(which);
			addOption(EchoOptions.action('Force Event',
				#if html5 'Runs the event now on your game and on everybody else in the duel (they see "ADMIN FORCED").'
				#else 'Runs the event now.' #end,
				function()
				{
					var values = switch (names[choice])
					{
						case 'Add Camera Zoom': ['0.1', '0.2'];
						case 'Screen Shake': ['0.5, 0.03', '0.5, 0.02'];
						case 'Hey!': ['Both', '0.6'];
						default: ['1.5', '1'];
					};
					game.triggerEvent(names[choice], values[0], values[1], Conductor.songPosition);
					#if html5
					if (online.Session.active) online.Session.sendEvent(names[choice], values[0], values[1]);
					#end
				}));
		}

		#if html5
		addOption(EchoOptions.action('Force Song (info)',
			'In the song list, as the duel\'s host, press F: the song starts for everybody,\neven if the other player is in another menu (they must own the song).',
			function() {}));
		#end

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
