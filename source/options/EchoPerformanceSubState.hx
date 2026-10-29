package options;

import echo.EchoOptions;
import echo.EchoPerf;

class EchoPerformanceSubState extends BaseOptionsMenu
{
	var presetOption:Option;

	public function new()
	{
		title = 'Optimization';
		rpcTitle = 'Echo Optimization Menu';

		presetOption = EchoOptions.string('Optimization Preset',
			'Low: no shaders, no background details, no anti-aliasing, no flashes (fastest).\nBalanced: the normal look.\nHigh: normal look and a higher framerate cap.\nCustom: you changed something below.',
			EchoPerf.PRESETS,
			function() return ClientPrefs.data.echoPreset,
			function(v:String) { if (v != 'Custom') EchoPerf.applyPreset(v); else ClientPrefs.data.echoPreset = 'Custom'; },
			'Balanced');
		presetOption.onChange = function()
		{
			reloadCheckboxes();
			reloadValues();
		};
		addOption(presetOption);

		custom(new Option('Shaders & Visual Effects',
			'If unchecked, disables shaders and the visual effects that use them.',
			'shaders', 'bool'));

		custom(EchoOptions.bool('Background Details & Animations',
			'If unchecked, removes background particles, animated props and other\ndetails of the stages (same as Low Quality).',
			function() return !ClientPrefs.data.lowQuality,
			function(v:Bool) ClientPrefs.data.lowQuality = !v,
			true));

		custom(new Option('Anti-Aliasing',
			'If unchecked, sprites are drawn without smoothing. Faster, but less sharp.',
			'antialiasing', 'bool'));

		custom(new Option('Flashing & Lighting Effects',
			'If unchecked, reduces the flashes and light effects of the game and the mods.',
			'flashing', 'bool'));

		custom(new Option('Camera Zoom Effects',
			'If unchecked, the camera does not zoom on the beat.',
			'camZooms', 'bool'));

		var option:Option = new Option('FPS Counter',
			'If checked, shows the frames per second in the corner.',
			'showFPS', 'bool');
		option.onChange = onChangeCounters;
		addOption(option);

		var option:Option = new Option('Memory Counter',
			'If checked, the counter also shows the memory in use.',
			'echoShowMemory', 'bool');
		addOption(option);

		var option:Option = new Option('Auto Clean Cache',
			'If checked, the cache is cleaned automatically between screens\nwhen the memory use is high (about 700 MB).',
			'echoAutoClean', 'bool');
		addOption(option);

		addOption(EchoOptions.action('Clear Cache & Reload Assets',
			'Frees the images and sounds that are not in use.\nThey are loaded again from the game files when they are needed.',
			function()
			{
				descText.text = EchoPerf.clearCaches();
			}));

		super();
	}

	/** An option that makes the preset become "Custom" when it is changed. */
	function custom(option:Option):Void
	{
		var previous = option.onChange;
		option.onChange = function()
		{
			if (previous != null) previous();
			ClientPrefs.data.echoPreset = 'Custom';
			presetOption.curOption = EchoPerf.PRESETS.indexOf('Custom');
			updateTextFrom(presetOption);
		};
		addOption(option);
	}

	function onChangeCounters()
	{
		if (Main.fpsVar != null) Main.fpsVar.visible = ClientPrefs.data.showFPS;
	}

	/** After a preset: refresh the text of the options that are not checkboxes. */
	function reloadValues()
	{
		for (option in optionsArray)
			if (option.type != 'bool' && option != presetOption) updateTextFrom(option);
	}
}
