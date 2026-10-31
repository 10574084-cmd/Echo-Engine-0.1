package options;

import echo.EchoOptions;
import echo.EchoShaderPack;

/** Echo Extra > Shader Packs: a visual look for the whole game (see echo.EchoShaderPack). */
class EchoShadersSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Shader Packs';
		rpcTitle = 'Shader Packs Menu';

		addOption(EchoOptions.string('Shader Pack',
			'A look for the whole game, like the shader packs of Minecraft.\nNewb: warm light, glow and soft vignette. Cinematic: dark corners and film grain.\nGlow, Dreamy, Retro CRT, Sunset, Night, Noir and Vibrant change the colors and effects.',
			EchoShaderPack.NAMES,
			function() return ClientPrefs.data.echoShaderPack,
			function(v:String) ClientPrefs.data.echoShaderPack = v,
			'Off'));

		addOption(EchoOptions.number('Shader Intensity',
			'How strong the pack is (0% = no effect, 100% = full).',
			'percent', 0, 1, 0.05,
			function() return ClientPrefs.data.echoShaderIntensity,
			function(v:Float) ClientPrefs.data.echoShaderIntensity = v,
			1));

		addOption(new Option('Glow and Blur',
			'If unchecked, the packs skip the glow and blur. Faster on weak devices.',
			'echoShaderBloom', 'bool'));

		addOption(new Option('Only During Songs',
			'If checked, the pack is only applied while you play a song, not in the menus.',
			'echoShaderSongsOnly', 'bool'));

		addOption(new Option('Shaders (master switch)',
			'If unchecked, every shader effect is off, including these packs.',
			'shaders', 'bool'));

		super();
	}
}
