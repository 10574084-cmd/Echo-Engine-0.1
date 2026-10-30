package echo;

import flixel.input.keyboard.FlxKey;
import haxe.crypto.Sha256;

/**
 * Hidden "xd" admin options of the Echo Lab.
 *
 *  1. Type `echoass` on the main menu: the "xd" option appears in Options > Echo Extra > Echo Extras > Echo Lab.
 *  2. Press ENTER on it and type the admin code.
 *  3. Admin unlocks: editors (chart editor...), botplay (also online, the rival is told), god mode, Echo Live announcements.
 *  Type `passecho` on the main menu to choose your own code (it asks for the current one first). The new code is kept on
 *  this browser only, as a salted hash; the built-in code stops working once you set one.
 *
 * Only a hash of the code is kept here, but this is a game running on the player's own browser: it is a gate for
 * fun, not security. Anybody who reads the code of the page can get around it.
 */
class EchoAdmin
{
	static inline var SALT = 'echo-xd-dkdk7btr';
	static inline var CODE_HASH = 'ff1786c1a817a3fb87db753aaead0e3430784d80ff35b8102ccc88202004206f';
	static inline var SECRET = 'ECHOASS';
	static inline var CHANGE = 'PASSECHO';
	public static inline var MIN_CODE = 6;

	static var typed:String = '';

	/** Quick menu (O / P / M) that the pause menu must open as soon as it appears: events, song, message. */
	public static var quickOpen:String = null;

	/** The code that opens the admin options (letters only, upper or lower case). */
	public static function check(code:String):Bool
	{
		if (code == null) return false;
		var expected = hasCustomCode() ? ClientPrefs.data.echoAdminHash : CODE_HASH;
		return Sha256.encode(SALT + code.trim().toLowerCase()) == expected;
	}

	public static inline function hasCustomCode():Bool
		return ClientPrefs.data.echoAdminHash != null && ClientPrefs.data.echoAdminHash.length == 64;

	/** Chooses a new admin code. The caller must have checked the current one. Returns false if it is too short. */
	public static function setCode(code:String):Bool
	{
		if (code == null || code.trim().length < MIN_CODE) return false;
		ClientPrefs.data.echoAdminHash = Sha256.encode(SALT + code.trim().toLowerCase());
		ClientPrefs.saveSettings();
		return true;
	}

	#if html5
	/** `passecho`: asks for the current code, then for the new one. Returns what to tell the player. */
	public static function changeCodeDialog():String
	{
		var current:String = js.Browser.window.prompt('Current admin code:', '');
		if (current == null) return 'Cancelled.';
		if (!check(current)) return 'Wrong code.';
		var wanted:String = js.Browser.window.prompt('New admin code (at least $MIN_CODE characters):', '');
		if (wanted == null) return 'Cancelled.';
		if (!setCode(wanted)) return 'Too short: use at least $MIN_CODE characters.';
		lock(); // everybody has to use the new code from now on
		return 'Admin code changed. Use the new one in Echo Lab > xd.';
	}
	#end

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
	 * Call every frame from the main menu. Returns 0 (nothing), 1 (the first letter of a secret word was typed: remember the
	 * menu position, W/A/S/D also move the menu), 2 (`echoass` was typed: the Lab option is unlocked) or
	 * 3 (`passecho` was typed: change the admin code).
	 */
	public static function watchSecret():Int
	{
		var key:Int = FlxG.keys.firstJustPressed();
		if (key < 0) return 0;
		var name:String = FlxKey.toStringMap.get(key);
		if (name == null || name.length != 1) { typed = ''; return 0; }

		typed += name.toUpperCase();
		if (typed.length > CHANGE.length) typed = typed.substr(typed.length - CHANGE.length);
		if (typed.endsWith(CHANGE))
		{
			typed = '';
			return 3;
		}
		if (typed.endsWith(SECRET) && !secretFound())
		{
			typed = '';
			ClientPrefs.data.echoSecret = true;
			ClientPrefs.saveSettings();
			return 2;
		}
		return (typed == SECRET.charAt(0) || typed == CHANGE.charAt(0)) ? 1 : 0;
	}

	public static function lock():Void
	{
		ClientPrefs.data.echoAdmin = false;
		ClientPrefs.data.echoAdminBot = false;
		ClientPrefs.data.echoAdminGod = false;
		ClientPrefs.saveSettings();
	}
}
