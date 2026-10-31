#!/usr/bin/env bash
# Run inside the generated Capacitor project (apps/android/build): landscape, full screen, game icon.
set -euo pipefail
ANDROID=android
MANIFEST=$ANDROID/app/src/main/AndroidManifest.xml
STYLES=$ANDROID/app/src/main/res/values/styles.xml

# landscape only (the game is 16:9), and do not restart the game when the phone is rotated or a keyboard appears
python3 - "$MANIFEST" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('<activity', '<activity\n            android:screenOrientation="sensorLandscape"', 1)
open(p, 'w').write(s)
PY

# full screen, also over the camera notch
python3 - "$STYLES" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
extra = '''
        <item name="android:windowFullscreen">true</item>
        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
'''
s = s.replace('<style name="AppTheme.NoActionBarLaunch"', '<style name="AppTheme.NoActionBarLaunch"', 1)
marker = '<style name="AppTheme.NoActionBar" parent="Theme.AppCompat.DayNight.NoActionBar">'
assert marker in s, 'theme not found'
s = s.replace(marker, marker + extra, 1)
open(p, 'w').write(s)
PY

# icon: the game's icon on every density
if command -v convert >/dev/null 2>&1; then
	for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
		dir=$ANDROID/app/src/main/res/mipmap-${d%%:*}
		size=${d##*:}
		for name in ic_launcher.png ic_launcher_round.png ic_launcher_foreground.png; do
			[ -f "$dir/$name" ] && convert ../../../art/iconOG.png -resize ${size}x${size} "$dir/$name"
		done
	done
	# the adaptive icon (Android 8+) would hide the plain icon: remove it so the files above are used
	rm -rf $ANDROID/app/src/main/res/mipmap-anydpi-v26
fi
