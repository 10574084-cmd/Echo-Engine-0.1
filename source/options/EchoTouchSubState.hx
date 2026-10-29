package options;

#if html5
import echo.EchoOptions;
import webfs.TouchBridge;

/** On-screen controls for phones. The values are kept by the web page (echo-touch.js) and remembered between visits. */
class EchoTouchSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Touch Controls';
		rpcTitle = 'Echo Touch Controls Menu';

		addOption(EchoOptions.bool('Touch Controls',
			'Shows the on-screen buttons (arrows, OK, BACK and the note buttons).',
			function() return TouchBridge.getBool('enabled'),
			function(v:Bool) TouchBridge.set('enabled', v),
			false));

		addOption(EchoOptions.number('Button Size',
			'How big the buttons are.',
			'float', 0.5, 1.6, 0.05,
			function() return TouchBridge.getNumber('size'),
			function(v:Float) TouchBridge.set('size', v),
			1));

		addOption(EchoOptions.number('Button Spacing',
			'The space between the buttons.',
			'float', 0, 2, 0.1,
			function() return TouchBridge.getNumber('gap'),
			function(v:Float) TouchBridge.set('gap', v),
			1));

		addOption(EchoOptions.number('Button Opacity',
			'How see-through the buttons are.',
			'percent', 0.1, 1, 0.05,
			function() return TouchBridge.getNumber('alpha'),
			function(v:Float) TouchBridge.set('alpha', v),
			0.35));

		addOption(EchoOptions.string('Layout',
			'Classic: arrows on the left, OK/BACK on the right, big note buttons.\nCompact: smaller and closer to the center.\nCustom: the positions you set with "Edit Button Positions".',
			['Classic', 'Compact', 'Custom'],
			function() return TouchBridge.getString('layout'),
			function(v:String) TouchBridge.set('layout', v),
			'Classic'));

		addOption(EchoOptions.action('Edit Button Positions',
			'Close this menu and drag every button to where you want it.\nPress DONE on the screen to save (the layout becomes Custom).',
			function()
			{
				close();
				TouchBridge.edit();
			}));

		addOption(EchoOptions.bool('Vibration',
			'A short vibration when you touch a button (only if your device supports it;\niPhones do not).',
			function() return TouchBridge.getBool('vibration'),
			function(v:Bool) TouchBridge.set('vibration', v),
			false));

		addOption(EchoOptions.bool('Landscape Mode',
			'Asks for full screen and locks the screen to landscape (where the browser allows it).',
			function() return TouchBridge.getBool('landscape'),
			function(v:Bool) TouchBridge.set('landscape', v),
			true));

		addOption(EchoOptions.bool('Prevent Accidental Gestures',
			'Blocks pull-to-refresh, pinch zoom and double-tap zoom, and asks before leaving the page\nwhile a song is playing.',
			function() return TouchBridge.getBool('guard'),
			function(v:Bool) TouchBridge.set('guard', v),
			true));

		addOption(EchoOptions.action('Reset Touch Settings',
			'Puts every touch setting back to its default value.',
			function()
			{
				TouchBridge.reset();
				close();
			}));

		super();
	}
}
#end
