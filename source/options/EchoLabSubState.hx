package options;

import echo.EchoOptions;

/** Experimental options. Anything here may break; the warning is part of the menu. */
class EchoLabSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Echo Lab (experimental)';
		rpcTitle = 'Echo Lab Menu';

		addOption(new Option('GPU Texture Caching',
			'EXPERIMENTAL: keeps the textures in the video memory to save RAM.\nCan make images look wrong or crash on some devices.',
			'cacheOnGPU', 'bool'));

		var option:Option = new Option('Framerate Cap',
			'EXPERIMENTAL: the maximum frames per second. Browsers follow the screen\'s refresh rate,\nso on the web a higher value only helps screens above 60 Hz.',
			'framerate', 'int');
		option.minValue = 30;
		option.maxValue = 240;
		option.defaultValue = 60;
		option.displayFormat = '%v FPS';
		option.onChange = function()
		{
			if (ClientPrefs.data.framerate > FlxG.drawFramerate)
			{
				FlxG.updateFramerate = ClientPrefs.data.framerate;
				FlxG.drawFramerate = ClientPrefs.data.framerate;
			}
			else
			{
				FlxG.drawFramerate = ClientPrefs.data.framerate;
				FlxG.updateFramerate = ClientPrefs.data.framerate;
			}
		};
		addOption(option);

		addOption(new Option('Always Clean Cache',
			'EXPERIMENTAL: frees the images and sounds every time you change screen.\nSaves memory, but screens and songs take longer to open.',
			'echoLabAlwaysClean', 'bool'));

		super();
	}
}
