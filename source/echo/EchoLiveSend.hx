package echo;

#if html5
import haxe.Json;
import js.Browser;

/**
 * Starts the "Echo Live" workflow of the repository from inside the game (xd menu), so nobody has to open GitHub.
 *
 * Security: the game holds no secret. The admin pastes a GitHub fine-grained personal access token (only this repository,
 * only "Actions: read and write") that is kept in this browser's localStorage and is sent only to api.github.com. Without
 * the token nothing can be announced, whatever a userscript or an extension does to the game; and the token can be revoked
 * on GitHub at any time. The announcement itself is validated again by every player (see EchoLive).
 */
class EchoLiveSend
{
	static inline var REPO = '10574084-cmd/Echo-Engine-1.1.0';
	static inline var KEY = 'echo-live-token';

	public static function token():String
	{
		try
		{
			var t = Browser.getLocalStorage().getItem(KEY);
			return t == null ? '' : t;
		}
		catch (e:Dynamic) return '';
	}

	public static function setToken(value:String):Void
	{
		try
		{
			if (value == null || value.trim() == '') Browser.getLocalStorage().removeItem(KEY);
			else Browser.getLocalStorage().setItem(KEY, value.trim());
		}
		catch (e:Dynamic) {}
	}

	/** `done(null)` when GitHub accepted it, otherwise `done(reason)`. */
	public static function send(inputs:Dynamic, done:String->Void):Void
	{
		var t = token();
		if (t == '')
		{
			done('No GitHub token yet: use "Live: GitHub Token" first.');
			return;
		}
		var status = 0;
		var http = new haxe.Http('https://api.github.com/repos/$REPO/actions/workflows/live.yml/dispatches');
		http.setHeader('Authorization', 'Bearer ' + t);
		http.setHeader('Accept', 'application/vnd.github+json');
		http.setHeader('X-GitHub-Api-Version', '2022-11-28');
		http.setHeader('Content-Type', 'application/json');
		http.setPostData(Json.stringify({ref: 'main', inputs: inputs}));
		http.onStatus = function(code) status = code;
		http.onData = function(_) done(status == 204 || status == 200 ? null : 'GitHub answered $status.');
		http.onError = function(msg)
		{
			done(status == 401 || status == 403 ? 'GitHub refused the token ($status). Make a new one with Actions: read and write.'
				: status == 404 ? 'GitHub says 404: the token cannot see this repository.'
				: status == 422 ? 'GitHub rejected the request (422): check the values.'
				: 'Could not reach GitHub (' + msg + ').');
		};
		http.request(true);
	}
}
#end
