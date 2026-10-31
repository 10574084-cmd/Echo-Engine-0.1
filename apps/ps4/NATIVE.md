# Native console port (PS4 / OpenOrbis): plan and status

Goal: run Echo Engine as a native program on a jailbroken PS4 (GoldHEN), built with the OpenOrbis toolchain.

1. **Native build without extras** (`-Dnative_lite`): Haxe -> C++ with hxcpp, without Lua, HScript, Discord, videos. Workflow `native.yml`.
2. A minimal Lime/OpenFL app that draws an image on the PS4 (toolchain for hxcpp + SDL2/piglet from OpenOrbis).
3. Audio and gamepad.
4. The full game and its assets inside the PKG.
