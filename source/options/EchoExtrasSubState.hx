package options;

import echo.EchoOptions;
import echo.EchoTheme;

class EchoExtrasSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Echo Extras';
		rpcTitle = 'Echo Extras Menu';

		var option:Option = EchoOptions.string('Echo Theme',
			'Changes the colors of the menus.',
			EchoTheme.NAMES,
			function() return ClientPrefs.data.echoTheme,
			function(v:String) ClientPrefs.data.echoTheme = v,
			'Default');
		option.onChange = function() bg.color = EchoTheme.color(0xFFea71fd);
		addOption(option);

		addOption(new Option('Quick Boot',
			'If checked, skips the intro animation of the title screen.',
			'echoQuickBoot', 'bool'));

		addOption(new Option('Echo Live Events',
			'If checked, the Echo Engine team can announce an event for everybody online:\na countdown appears and then you are taken to a song (or a chart event happens).\nYou can skip any of them with F9 or by tapping the banner. Uncheck to ignore them all.',
			'echoLive', 'bool'));

		addOption(new Option('Random Menu Music',
			'If checked, the menus play a random song of the available ones\n(Freaky Menu, Breakfast, Tea Time) instead of always the same.',
			'echoRandomMusic', 'bool'));

		addOption(EchoOptions.action('Stats',
			'Songs played, scores and records.',
			function() openSubState(new EchoStatsSubState())));

		addOption(EchoOptions.action('Echo Lab',
			'Experimental options. They can cause bugs or crashes.',
			function() openSubState(new EchoLabSubState())));

		addOption(EchoOptions.action('About Echo Engine',
			'Version, credits, license and change log.',
			function() openSubState(new EchoAboutSubState())));

		super();
		bg.color = EchoTheme.color(0xFFea71fd);
	}
}
