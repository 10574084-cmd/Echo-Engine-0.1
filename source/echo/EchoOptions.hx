package echo;

import options.Option;

/** Builders for options that are not a plain ClientPrefs variable (inverted values, buttons, values kept elsewhere). */
class EchoOptions
{
	// Option wants the name of a ClientPrefs field to read its default from; the real getter/setter are replaced afterwards.
	static inline var ANY_FIELD = 'echoPreset';

	public static function bool(name:String, description:String, get:Void->Bool, set:Bool->Void, defaultValue:Bool):Option
	{
		var o = new Option(name, description, ANY_FIELD, 'bool');
		o.getValue = get;
		o.setValue = function(v:Dynamic) set(v == true);
		o.defaultValue = defaultValue;
		return o;
	}

	public static function string(name:String, description:String, values:Array<String>, get:Void->String, set:String->Void, defaultValue:String):Option
	{
		var o = new Option(name, description, ANY_FIELD, 'string', values);
		o.getValue = get;
		o.setValue = function(v:Dynamic) set(v);
		o.defaultValue = defaultValue;
		o.curOption = Std.int(Math.max(0, values.indexOf(get())));
		return o;
	}

	/** A number between `min` and `max`. `type` is 'float' or 'percent' (percent shows value * 100 %). */
	public static function number(name:String, description:String, type:String, min:Float, max:Float, step:Float, get:Void->Float, set:Float->Void, defaultValue:Float):Option
	{
		var o = new Option(name, description, ANY_FIELD, type);
		o.getValue = get;
		o.setValue = function(v:Dynamic) set(v);
		o.minValue = min;
		o.maxValue = max;
		o.changeValue = step;
		o.defaultValue = defaultValue;
		if (type == 'float')
		{
			o.decimals = 2;
			o.scrollSpeed = (max - min) / 2;
			o.displayFormat = '%v';
		}
		return o;
	}

	/** A "button": pressing ACCEPT runs `run` (the checkbox always goes back to unchecked). */
	public static function action(name:String, description:String, run:Void->Void):Option
	{
		var o = new Option(name, description + '\n(Press ENTER)', ANY_FIELD, 'bool');
		o.getValue = function() return false;
		o.setValue = function(_) {};
		o.defaultValue = false;
		o.isButton = true;
		o.onChange = run;
		return o;
	}
}
