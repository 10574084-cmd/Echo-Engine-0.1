package options;

import echo.EchoOptions;
import echo.EchoTheme;

/** "Echo Extra": the hub with the sections added by Echo Engine. */
class EchoExtraSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Echo Extra';
		rpcTitle = 'Echo Extra Menu';

		addOption(EchoOptions.action('Optimization',
			'Presets (Low / Balanced / High), shaders, effects, FPS counter, memory meter and cache cleaning.',
			function() openSubState(new EchoPerformanceSubState())));

		#if html5
		addOption(EchoOptions.action('Touch Controls',
			'On-screen buttons: size, spacing, opacity, layout, vibration and gestures.',
			function() openSubState(new EchoTouchSubState())));
		#end

		addOption(EchoOptions.action('Accessibility and HUD',
			'Fewer flashes and motion, hide distracting elements, opacity of notes and health bar, keys, info on screen.',
			function() openSubState(new EchoAccessibilitySubState())));

		addOption(EchoOptions.action('Echo Extras',
			'Echo Themes, Quick Boot, Random Menu Music, Stats, Echo Lab and About Echo Engine.',
			function() openSubState(new EchoExtrasSubState())));

		super();
		bg.color = EchoTheme.color(0xFFea71fd);
	}
}
