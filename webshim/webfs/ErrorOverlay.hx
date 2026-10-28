package webfs;

#if !html5
#error "webfs.ErrorOverlay only exists for the html5 target"
#end

import js.Browser;
import js.html.DivElement;
import js.html.Element;

/**
 * Shows script errors on top of the game instead of leaving a black screen with the reason hidden in the browser console.
 * It collects uncaught exceptions, rejected promises and the last lines written with `trace`, and has a button to copy
 * all of it (handy for a bug report).
 */
class ErrorOverlay
{
	static inline var MAX_LOG = 60;

	static var log:Array<String> = [];
	static var errors:Array<String> = [];
	static var panel:DivElement;
	static var body:Element;
	static var installed = false;

	public static function install():Void
	{
		if (installed) return;
		installed = true;

		// keep a copy of what the game traces (the original output keeps working)
		var originalTrace = haxe.Log.trace;
		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos)
		{
			var line = (infos != null ? infos.fileName + ":" + infos.lineNumber + ": " : "") + Std.string(v);
			log.push(line);
			if (log.length > MAX_LOG) log.shift();
			originalTrace(v, infos);
		};

		Browser.window.addEventListener("error", function(e:Dynamic)
		{
			var error:Dynamic = e.error;
			var message = error != null ? describe(error) : Std.string(e.message);
			// the browser reports resources that failed to load through the same event, those are not script errors
			if (error == null && e.message == null) return;
			report(message);
		});
		Browser.window.addEventListener("unhandledrejection", function(e:Dynamic)
		{
			report("Unhandled promise rejection: " + describe(e.reason));
		});
	}

	static function describe(error:Dynamic):String
	{
		if (error == null) return "(unknown error)";
		var text:String = Std.string(error);
		var stack:Dynamic = untyped error.stack;
		if (stack != null && Std.string(stack).indexOf(text) < 0) text += "\n" + Std.string(stack);
		else if (stack != null) text = Std.string(stack);
		return text;
	}

	public static function report(message:String):Void
	{
		// the same error repeats every frame when it happens in the update loop
		if (errors.indexOf(message) >= 0) return;
		errors.push(message);
		if (errors.length > 20) errors.shift();
		show();
	}

	static function fullReport():String
	{
		return errors.join("\n\n") + "\n\n--- last trace lines ---\n" + log.join("\n") + "\n\n--- " + Browser.navigator.userAgent;
	}

	static function show():Void
	{
		if (panel == null)
		{
			panel = Browser.document.createDivElement();
			panel.style.cssText = "position:fixed;left:0;right:0;bottom:0;max-height:45vh;z-index:99999;background:rgba(20,0,0,.93);color:#fdd;"
				+ "font:12px/1.35 monospace;border-top:2px solid #f44;display:flex;flex-direction:column;";

			var bar = Browser.document.createDivElement();
			bar.style.cssText = "display:flex;gap:8px;align-items:center;padding:6px 10px;background:#400;font-weight:bold;";
			bar.appendChild(Browser.document.createTextNode("Psych Engine Web: an error happened"));
			var spacer = Browser.document.createDivElement();
			spacer.style.flex = "1";
			bar.appendChild(spacer);
			bar.appendChild(button("Copy", function(b:Element)
			{
				var text = fullReport();
				try
				{
					js.Syntax.code("navigator.clipboard.writeText({0})", text);
					b.textContent = "Copied";
				}
				catch (e:Dynamic)
				{
					b.textContent = "Copy failed";
				}
			}));
			bar.appendChild(button("Close", function(_) panel.style.display = "none"));
			panel.appendChild(bar);

			body = Browser.document.createDivElement();
			body.style.cssText = "overflow:auto;padding:8px 10px;white-space:pre-wrap;word-break:break-word;";
			panel.appendChild(body);
			Browser.document.body.appendChild(panel);
		}

		panel.style.display = "flex";
		body.textContent = fullReport();
		body.scrollTop = 0;
	}

	static function button(label:String, onClick:Element->Void):Element
	{
		var b = Browser.document.createButtonElement();
		b.textContent = label;
		b.style.cssText = "background:#611;color:#fff;border:1px solid #f88;padding:2px 10px;cursor:pointer;font:inherit;";
		b.onclick = function(_) onClick(b);
		return b;
	}
}
