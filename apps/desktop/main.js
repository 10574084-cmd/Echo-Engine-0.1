// Echo Engine for PC: the same game that runs on the web, inside a window.
// The game files (folder "www") are served through a private address (app://echo/) so the game sees a normal, secure web page:
// its saves live in the app's own storage and nothing from the internet is needed to start it.
const { app, BrowserWindow, Menu, protocol, net, shell } = require('electron');
const path = require('path');
const { pathToFileURL } = require('url');

const ROOT = path.join(__dirname, 'www');

protocol.registerSchemesAsPrivileged([
	{ scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true, corsEnabled: true } }
]);

function createWindow() {
	const win = new BrowserWindow({
		width: 1280,
		height: 720,
		minWidth: 640,
		minHeight: 360,
		backgroundColor: '#000000',
		autoHideMenuBar: true,
		title: 'Echo Engine',
		webPreferences: {
			contextIsolation: true,
			sandbox: true,
			nodeIntegration: false,
			autoplayPolicy: 'no-user-gesture-required',
			backgroundThrottling: false
		}
	});
	Menu.setApplicationMenu(null);

	// F11 = full screen, as in most games
	win.webContents.on('before-input-event', (event, input) => {
		if (input.type === 'keyDown' && input.key === 'F11') {
			win.setFullScreen(!win.isFullScreen());
			event.preventDefault();
		}
	});

	// the game never opens other windows or leaves its own address (links go to the normal browser)
	win.webContents.setWindowOpenHandler(({ url }) => {
		if (/^https:\/\//.test(url)) shell.openExternal(url);
		return { action: 'deny' };
	});
	win.webContents.on('will-navigate', (event, url) => {
		if (!url.startsWith('app://echo/')) event.preventDefault();
	});

	win.loadURL('app://echo/index.html');

	// used by the build machine to check that the packaged app really starts (never set for players)
	if (process.env.ECHO_SMOKETEST) {
		win.webContents.on('did-fail-load', (e, code, desc) => { console.error('LOAD FAILED', code, desc); app.exit(1); });
		setTimeout(async () => {
			try {
				const ok = await win.webContents.executeJavaScript("!!document.querySelector('canvas')");
				console.log('game canvas present:', ok);
				app.exit(ok ? 0 : 2);
			} catch (e) { console.error(e); app.exit(3); }
		}, 30000);
	}
}

app.whenReady().then(() => {
	protocol.handle('app', (request) => {
		const url = new URL(request.url);
		let rel = decodeURIComponent(url.pathname);
		if (rel === '/' || rel === '') rel = '/index.html';
		const file = path.normalize(path.join(ROOT, rel));
		// never serve anything outside the game folder
		if (file !== ROOT && !file.startsWith(ROOT + path.sep)) return new Response('Forbidden', { status: 403 });
		return net.fetch(pathToFileURL(file).toString());
	});
	createWindow();
	app.on('activate', () => {
		if (BrowserWindow.getAllWindows().length === 0) createWindow();
	});
});

app.on('window-all-closed', () => app.quit());
