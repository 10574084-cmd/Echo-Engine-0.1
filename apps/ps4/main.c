// Echo Engine for PS4 (homebrew, OpenOrbis + GoldHEN): a launcher.
// The game itself is the web version (it needs a browser engine, which the PS4 already has), so this app only opens it
// in the console's own web browser. It does not contain the game and it does not touch any game or system files.
#include <stdio.h>

#define ECHO_URL "https://10574084-cmd.github.io/Echo-Engine-1.2.0/"

// OpenOrbis declares this function without parameters; the real one takes the address to open.
extern int sceSystemServiceLaunchWebBrowser(const char *url);
extern unsigned int sceKernelSleep(unsigned int seconds);

int main(void)
{
	printf("[Echo Engine] opening " ECHO_URL "\n");
	int result = sceSystemServiceLaunchWebBrowser(ECHO_URL);
	printf("[Echo Engine] sceSystemServiceLaunchWebBrowser returned 0x%x\n", (unsigned int)result);
	sceKernelSleep(3);
	return 0;
}
