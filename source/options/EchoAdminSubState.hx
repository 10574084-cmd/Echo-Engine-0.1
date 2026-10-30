package options;

import echo.EchoAdmin;
import echo.EchoOptions;
#if html5
import echo.EchoLiveSend;
#end
import states.editors.MasterEditorMenu;

/** The hidden admin options (see echo.EchoAdmin). */
class EchoAdminSubState extends BaseOptionsMenu
{
	#if html5
	// what the admin chose last: it stays between openings of the quick menus
	static var liveSong:String = '';
	static var liveDiff:String = 'Normal';
	static var liveMinutes:String = '5';
	static var liveEvent:String = 'Add Camera Zoom';
	static var liveMessage:String = '';
	#end

	/** `section`: "all" (the full xd menu) or one of the quick menus: "events", "song", "message". */
	public function new(section:String = 'all')
	{
		var all = section == 'all';
		title = switch (section)
		{
			case 'events': 'Global events';
			case 'song': 'Force everybody to a song';
			case 'message': 'Global message';
			default: 'xd (admin)';
		};
		rpcTitle = 'Echo Admin Menu';

		if (all && EchoAdmin.editorsAllowed()) addOption(EchoOptions.action('Open Editors',
			'Chart editor, character editor, stage and week editors.\nIn a song or in the main menu you can also press 7 (chart) and 8 (character).',
			function()
			{
				// the editors replace the whole screen: leave the options first
				FlxG.sound.music?.stop();
				MusicBeatState.switchState(new MasterEditorMenu());
			}));

		// forced chart events: only while a song is running (opened from the pause menu)
		var game = states.PlayState.instance;
		if (all && game != null)
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
		if (all) addOption(EchoOptions.action('Force Song (info)',
			'In the song list, as the duel\'s host, press F: the song starts for everybody,\neven if the other player is in another menu (they must own the song).',
			function() {}));
		#end

		if (all) addOption(EchoOptions.bool('Botplay',
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

		if (all) addOption(EchoOptions.bool('God Mode',
			'Your health is always full in offline songs. (Does nothing in duels: nobody dies there.)',
			function() return ClientPrefs.data.echoAdminGod,
			function(v:Bool) ClientPrefs.data.echoAdminGod = v,
			false));


		#if html5
		// Echo Live: announce something to every player (see echo.EchoLive); needs the GitHub token of the owner
		var liveKinds = ['song', 'event', 'message', 'clear'];
		var liveDiffs = ['Easy', 'Normal', 'Hard'];
		var liveMinuteList = ['0', '1', '2', '5', '10', '15', '30', '60'];
		var liveEvents = ['Add Camera Zoom', 'Screen Shake', 'Hey!', 'Change Scroll Speed'];
		var kind = switch (section) { case 'events': 'event'; case 'song': 'song'; case 'message': 'message'; default: 'song'; };
		if (section == 'events' && liveMinutes == '5') liveMinutes = '0'; // quick menus: now, not in 5 minutes
		if (section == 'song' && liveMinutes == '5') liveMinutes = '1';
		if (section == 'message') liveMinutes = '0';

		if (all) addOption(EchoOptions.string('Live: What',
			'song = everybody goes to a song, event = a chart event for those playing,\nmessage = only a notice, clear = cancels the last announcement.',
			liveKinds, function() return kind, function(v:String) kind = v, 'song'));
		if (all || section == 'song') addOption(EchoOptions.action('Live: Song',
			'Folder name of the song everybody will play (e.g. bopeebo, blammed).' + (liveSong == '' ? '' : '\nNow: ' + liveSong),
			function()
			{
				var typed:String = js.Browser.window.prompt('Song folder name (e.g. bopeebo):', liveSong);
				if (typed != null) { liveSong = typed.trim(); liveNote('Song: ' + (liveSong == '' ? '(none)' : liveSong)); }
			}));
		if (all || section == 'song') addOption(EchoOptions.string('Live: Difficulty', 'Difficulty of that song.', liveDiffs, function() return liveDiff, function(v:String) liveDiff = v, 'Normal'));
		if (all || section != 'message') addOption(EchoOptions.string('Live: Minutes', 'Minutes of countdown before it happens (0 = as soon as players see it).', liveMinuteList, function() return liveMinutes, function(v:String) liveMinutes = v, liveMinutes));
		if (all || section == 'events') addOption(EchoOptions.string('Live: Event', 'Chart event for everybody who is playing a song.', liveEvents, function() return liveEvent, function(v:String) liveEvent = v, 'Add Camera Zoom'));
		addOption(EchoOptions.action('Live: Message',
			'Text shown to everybody in the banner (max 140 characters).' + (liveMessage == '' ? '' : '\nNow: ' + liveMessage),
			function()
			{
				var typed:String = js.Browser.window.prompt('Banner text:', liveMessage);
				if (typed != null) { liveMessage = typed.trim(); liveNote('Message: ' + (liveMessage == '' ? '(none)' : liveMessage)); }
			}));
		addOption(EchoOptions.action('Live: GitHub Token',
			'Paste a GitHub fine-grained token (this repository, "Actions: read and write").\nIt stays in this browser only. Leave it empty to forget it.',
			function()
			{
				var typed:String = js.Browser.window.prompt('GitHub token (empty = forget it):', '');
				if (typed != null)
				{
					EchoLiveSend.setToken(typed);
					liveNote(typed.trim() == '' ? 'Token forgotten.' : 'Token saved in this browser.');
				}
			}));
		addOption(EchoOptions.action('Live: SEND TO EVERYBODY',
			'Starts the announcement now. Every player sees the countdown.',
			function()
			{
				var inputs:Dynamic = {kind: kind, minutes: liveMinutes, message: liveMessage};
				var summary = kind;
				switch (kind)
				{
					case 'song':
						if (liveSong == '') { liveNote('Choose the song first (Live: Song).'); return; }
						inputs.song = liveSong;
						inputs.difficulty = liveDiff;
						summary = 'EVERYBODY GOES TO "$liveSong" ($liveDiff) in $liveMinutes min';
					case 'event':
						inputs.event = liveEvent;
						summary = 'EVENT "$liveEvent" for everybody in $liveMinutes min';
					case 'message':
						if (liveMessage == '') { liveNote('Write the message first (Live: Message).'); return; }
						summary = 'MESSAGE "$liveMessage"';
					default:
						summary = 'CANCEL the last announcement';
				}
				if (!js.Browser.window.confirm('Announce to EVERYBODY: $summary?')) return;
				liveNote('Sending...');
				EchoLiveSend.send(inputs, function(error:String) liveNote(error == null ? 'Sent! Players see it within a minute.' : error));
			}));
		#end

		if (all) addOption(EchoOptions.action('Lock Admin',
			'Turns the admin options off and asks for the code again next time.',
			function()
			{
				EchoAdmin.lock();
				close();
			}));

		super();
	}

	#if html5
	var liveText:flixel.text.FlxText;

	function liveNote(text:String):Void
	{
		if (liveText == null)
		{
			liveText = new flixel.text.FlxText(0, 8, FlxG.width, '', 22);
			liveText.setFormat(Paths.font('vcr.ttf'), 22, 0xFFFFFF00, CENTER, flixel.text.FlxText.FlxTextBorderStyle.OUTLINE, 0xFF000000);
			liveText.scrollFactor.set();
			add(liveText);
		}
		liveText.text = text;
	}
	#end
}
