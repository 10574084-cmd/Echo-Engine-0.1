package options;

import echo.EchoOptions;

class EchoAccessibilitySubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Accessibility and HUD';
		rpcTitle = 'Echo Accessibility Menu';

		addOption(EchoOptions.bool('Reduce Flashes',
			'If checked, the game and the mods use softer flashes and no strobing lights.',
			function() return !ClientPrefs.data.flashing,
			function(v:Bool) ClientPrefs.data.flashing = !v,
			false));

		addOption(new Option('Reduce Background & Camera Motion',
			'If checked, the camera does not zoom to the beat and the\n"Screen Shake" events (used by many mods) are ignored.',
			'echoReduceMotion', 'bool'));

		addOption(new Option('Hide HUD',
			'If checked, hides most of the on-screen interface during songs\n(health bar, score, icons, time).',
			'hideHud', 'bool'));

		addOption(new Option('Hide Rating Popups',
			'If checked, the "Sick!" ratings and the combo numbers are not shown.',
			'echoHidePopups', 'bool'));

		addOption(new Option('Show Opponent Strums',
			'If unchecked, the opponent\'s arrows are hidden so only yours remain.',
			'opponentStrums', 'bool'));

		addOption(EchoOptions.number('Note Opacity',
			'How see-through the notes are.',
			'percent', 0.2, 1, 0.05,
			function() return ClientPrefs.data.echoNoteAlpha,
			function(v:Float) ClientPrefs.data.echoNoteAlpha = v,
			1));

		var option:Option = new Option('Health Bar Opacity',
			'How see-through the health bar and the icons are.',
			'healthBarAlpha', 'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		addOption(new Option('Accuracy & Performance Info',
			'If checked, shows your accuracy, combo, FPS and memory\nin a small line while you play.',
			'echoInfoOverlay', 'bool'));

		addOption(EchoOptions.action('Customize Keys',
			'Opens the controls menu, where you choose the keys for the notes and the menus.',
			function() openSubState(new ControlsSubState())));

		super();
	}
}
