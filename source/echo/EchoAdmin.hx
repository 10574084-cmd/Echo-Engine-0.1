package echo;

import flixel.input.keyboard.FlxKey;
import haxe.crypto.Sha256;

/**
 * Hidden "xd" admin options of the Echo Lab.
 *
 *  1. Type `echoass` on the main menu: the "xd" option appears in Options > Echo Extra > Echo Extras > Echo Lab.
 *  2. Press ENTER on it and type the admin code.
 *  3. Admin unlocks: editors (chart editor...), botplay (also online, the rival is told), god mode.
 *
 * Only a hash of the code is kept here, but this is a game running on the player's own browser: it is a gate for
 * fun, not security. Anybody who reads the code of the page can get around it.
 */
class EchoAdmin
{
	static inline var SALT = 'echo-xd-dkdk7btr';
	static inline var CODE_HASH = 'ff1786c1a817a3fb87db753aaead0e3430784d80ff35b8102ccc88202004206f';
	static inline var SECRET = 'ECHOASS';

	static var typed:String = '';

	/** The code that opens the admin options (letters only, upper or lower case). */
	public static function check(code:String):Bool
	{
		if (code == null) return false;
		return Sha256.encode(SALT + code.trim().toLowerCase()) == CODE_HASH;
	}

	public static inline function secretFound():Bool
		return ClientPrefs.data.echoSecret;

	public static inline function isAdmin():Bool
		return ClientPrefs.data.echoAdmin;

	static inline function inDuel():Bool
	{
		#if html5
		return online.Session.active;
		#else
		return false;
		#end
	}

	/** Chart editor, character editor and the editors menu: always on desktop, admin only on the web, never in a duel. */
	public static function editorsAllowed():Bool
	{
		if (inDuel()) return false;
		#if html5
		return isAdmin();
		#else
		return true;
		#end
	}

	public static function botplay():Bool
		return isAdmin() && ClientPrefs.data.echoAdminBot;

	public static function god():Bool
		return isAdmin() && ClientPrefs.data.echoAdminGod && !inDuel();

	/**
	 * Call every frame from the main menu. Returns 0 (nothing), 1 (the first letter of the word was typed: remember the
	 * menu position, W/A/S/D also move the menu) or 2 (the last typed letters spell `echoass`: the Lab option is unlocked).
	 */
	public static function watchSecret():Int
	{
		var key:Int = FlxG.keys.firstJustPressed();
		if (key < 0) return 0;
		var name:String = FlxKey.toStringMap.get(key);
		if (name == null || name.length != 1) { typed = ''; return 0; }

		typed += name.toUpperCase();
		if (typed.length > SECRET.length) typed = typed.substr(typed.length - SECRET.length);
		if (typed == SECRET && !secretFound())
		{
			typed = '';
			ClientPrefs.data.echoSecret = true;
			ClientPrefs.saveSettings();
			return 2;
		}
		return typed == SECRET.charAt(0) ? 1 : 0;
	}

	public static function lock():Void
	{
		ClientPrefs.data.echoAdmin = false;
		ClientPrefs.data.echoAdminBot = false;
		ClientPrefs.data.echoAdminGod = false;
		ClientPrefs.saveSettings();
	}
}
