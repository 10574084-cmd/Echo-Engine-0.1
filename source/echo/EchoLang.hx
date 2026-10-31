package echo;

/**
 * Languages of the menus. `t("English text")` gives the text in the chosen language (English if there is no translation).
 * Options (name + description), menu titles, the pause menu, the welcome screen and the stats are translated;
 * songs, mods, the pictures of the main menu and the online screens stay in English.
 *
 * Alphabet (the big menu font) has no accents or "n with tilde", so the names are written without them.
 * To add a language: add a name to LANGUAGES and a map like SPANISH, and return it from table().
 */
class EchoLang
{
	public static final LANGUAGES:Array<String> = ['Auto', 'English', 'Español'];

	/** "English" or "Español": what is really used (Auto follows the browser). */
	public static function current():String
	{
		var chosen = (ClientPrefs.data != null) ? ClientPrefs.data.echoLang : 'Auto';
		if (chosen == 'English' || chosen == 'Español') return chosen;
		#if html5
		var lang:String = js.Browser.navigator.language;
		if (lang != null && lang.toLowerCase().indexOf('es') == 0) return 'Español';
		#end
		return 'English';
	}

	static var cacheFor:String = null;
	static var cache:Map<String, String> = null;

	static function table():Map<String, String>
	{
		var now = current();
		if (cacheFor != now)
		{
			cacheFor = now;
			cache = now == 'Español' ? SPANISH : null;
		}
		return cache;
	}

	public static function t(text:String):String
	{
		if (text == null) return text;
		var tbl = table();
		if (tbl == null) return text;
		var found = tbl.get(text);
		return found != null ? found : text;
	}

	static final SPANISH:Map<String, String> = [
		'Reduce Flashes' => 'Reducir destellos',
		'If checked, the game and the mods use softer flashes and no strobing lights.' => 'Si esta activado, el juego y los mods usan destellos mas suaves y sin luces estroboscopicas.',
		'Reduce Background & Camera Motion' => 'Reducir movimiento de fondo y camara',
		'If checked, the camera does not zoom to the beat and the\n"Screen Shake" events (used by many mods) are ignored.' => 'Si esta activado, la camara no hace zoom con el ritmo y se ignoran\nlos eventos "Screen Shake" (usados por muchos mods).',
		'Hide HUD' => 'Ocultar HUD',
		'If checked, hides most of the on-screen interface during songs\n(health bar, score, icons, time).' => 'Si esta activado, oculta la mayor parte de la interfaz durante las canciones\n(barra de vida, puntuacion, iconos, tiempo).',
		'Hide Rating Popups' => 'Ocultar puntuaciones',
		'If checked, the "Sick!" ratings and the combo numbers are not shown.' => 'Si esta activado, no se muestran los "Sick!" ni los numeros del combo.',
		'Show Opponent Strums' => 'Mostrar flechas rivales',
		'If unchecked, the opponent\'s arrows are hidden so only yours remain.' => 'Si esta desactivado, las flechas del rival se ocultan y solo quedan las tuyas.',
		'Note Opacity' => 'Opacidad de notas',
		'How see-through the notes are.' => 'Que tan transparentes son las notas.',
		'Health Bar Opacity' => 'Opacidad de la barra de vida',
		'How see-through the health bar and the icons are.' => 'Que tan transparentes son la barra de vida y los iconos.',
		'Accuracy & Performance Info' => 'Info de precision y rendimiento',
		'If checked, shows your accuracy, combo, FPS and memory\nin a small line while you play.' => 'Si esta activado, muestra tu precision, combo, FPS y memoria\nen una linea pequena mientras juegas.',
		'Customize Keys' => 'Personalizar teclas',
		'Opens the controls menu, where you choose the keys for the notes and the menus.' => 'Abre el menu de controles, donde eliges las teclas de las notas y de los menus.',
		'Optimization' => 'Optimizacion',
		'Presets (Low / Balanced / High), shaders, effects, FPS counter, memory meter and cache cleaning.' => 'Preajustes (Low / Balanced / High), shaders, efectos, contador de FPS, medidor de memoria y limpieza de cache.',
		'Touch Controls' => 'Controles tactiles',
		'On-screen buttons: size, spacing, opacity, layout, vibration and gestures.' => 'Botones en pantalla: tamano, espacio, opacidad, disposicion, vibracion y gestos.',
		'Accessibility and HUD' => 'Accesibilidad y HUD',
		'Fewer flashes and motion, hide distracting elements, opacity of notes and health bar, keys, info on screen.' => 'Menos destellos y movimiento, ocultar elementos que distraen, opacidad de notas y barra de vida, teclas, info en pantalla.',
		'Echo Extras' => 'Echo Extras',
		'Echo Themes, Quick Boot, Random Menu Music, Stats, Echo Lab and About Echo Engine.' => 'Temas Echo, arranque rapido, musica de menu aleatoria, estadisticas, Echo Lab y Acerca de Echo Engine.',
		'Echo Theme' => 'Tema Echo',
		'Changes the colors of the menus.' => 'Cambia los colores de los menus.',
		'Quick Boot' => 'Arranque rapido',
		'If checked, skips the intro animation of the title screen.' => 'Si esta activado, se salta la animacion de introduccion de la pantalla de titulo.',
		'Echo Live Events' => 'Eventos Echo Live',
		'If checked, the Echo Engine team can announce an event for everybody online:\na countdown appears and then you are taken to a song (or a chart event happens).\nYou can skip any of them with F9 or by tapping the banner. Uncheck to ignore them all.' => 'Si esta activado, el equipo de Echo Engine puede anunciar un evento para todos:\naparece una cuenta atras y despues te lleva a una cancion (o se lanza un evento del chart).\nPuedes saltarlo con F9 o tocando la barra. Desactivalo para ignorarlos todos.',
		'Title Logo Animation' => 'Animacion del logo',
		'If checked, on the title screen the logo drops from the top to the middle\nwhile Girlfriend gets blurred.' => 'Si esta activado, en la pantalla de titulo el logo cae desde arriba hasta el centro\nmientras Girlfriend se desenfoca.',
		'Random Menu Music' => 'Musica de menu aleatoria',
		'If checked, the menus play a random song of the available ones\n(Freaky Menu, Breakfast, Tea Time) instead of always the same.' => 'Si esta activado, los menus ponen una cancion aleatoria de las disponibles\n(Freaky Menu, Breakfast, Tea Time) en vez de siempre la misma.',
		'Stats' => 'Estadisticas',
		'Songs played, scores and records.' => 'Canciones jugadas, puntuaciones y records.',
		'Echo Lab' => 'Echo Lab',
		'Experimental options. They can cause bugs or crashes.' => 'Opciones experimentales. Pueden causar errores o cierres.',
		'About Echo Engine' => 'Acerca de Echo Engine',
		'Version, credits, license and change log.' => 'Version, creditos, licencia y registro de cambios.',
		'GPU Texture Caching' => 'Cache de texturas en GPU',
		'EXPERIMENTAL: keeps the textures in the video memory to save RAM.\nCan make images look wrong or crash on some devices.' => 'EXPERIMENTAL: guarda las texturas en la memoria de video para ahorrar RAM.\nPuede hacer que las imagenes se vean mal o fallar en algunos dispositivos.',
		'Framerate Cap' => 'Limite de FPS',
		'EXPERIMENTAL: the maximum frames per second. Browsers follow the screen\'s refresh rate,\nso on the web a higher value only helps screens above 60 Hz.' => 'EXPERIMENTAL: los fotogramas por segundo maximos. Los navegadores siguen la frecuencia de la pantalla,\nasi que en la web un valor mayor solo ayuda en pantallas de mas de 60 Hz.',
		'Always Clean Cache' => 'Limpiar cache siempre',
		'EXPERIMENTAL: frees the images and sounds every time you change screen.\nSaves memory, but screens and songs take longer to open.' => 'EXPERIMENTAL: libera las imagenes y sonidos cada vez que cambias de pantalla.\nAhorra memoria, pero las pantallas y canciones tardan mas en abrirse.',
		'xd' => 'xd',
		'Optimization Preset' => 'Preajuste de optimizacion',
		'Low: no shaders, no background details, no anti-aliasing, no flashes (fastest).\nBalanced: the normal look.\nHigh: normal look and a higher framerate cap.\nCustom: you changed something below.' => 'Low: sin shaders, sin detalles de fondo, sin anti-aliasing, sin destellos (lo mas rapido).\nBalanced: el aspecto normal.\nHigh: aspecto normal y un limite de FPS mayor.\nCustom: cambiaste algo de abajo.',
		'Shaders & Visual Effects' => 'Shaders y efectos visuales',
		'If unchecked, disables shaders and the visual effects that use them.' => 'Si esta desactivado, se apagan los shaders y los efectos visuales que los usan.',
		'Background Details & Animations' => 'Detalles y animaciones de fondo',
		'If unchecked, removes background particles, animated props and other\ndetails of the stages (same as Low Quality).' => 'Si esta desactivado, quita particulas, objetos animados y otros\ndetalles de los escenarios (igual que Low Quality).',
		'Anti-Aliasing' => 'Suavizado (anti-aliasing)',
		'If unchecked, sprites are drawn without smoothing. Faster, but less sharp.' => 'Si esta desactivado, los sprites se dibujan sin suavizado. Mas rapido, pero menos nitido.',
		'Flashing & Lighting Effects' => 'Destellos y luces',
		'If unchecked, reduces the flashes and light effects of the game and the mods.' => 'Si esta desactivado, reduce los destellos y efectos de luz del juego y de los mods.',
		'Camera Zoom Effects' => 'Zoom de camara',
		'If unchecked, the camera does not zoom on the beat.' => 'Si esta desactivado, la camara no hace zoom con el ritmo.',
		'FPS Counter' => 'Contador de FPS',
		'If checked, shows the frames per second in the corner.' => 'Si esta activado, muestra los fotogramas por segundo en la esquina.',
		'Memory Counter' => 'Contador de memoria',
		'If checked, the counter also shows the memory in use.' => 'Si esta activado, el contador tambien muestra la memoria en uso.',
		'Auto Clean Cache' => 'Limpieza automatica de cache',
		'If checked, the cache is cleaned automatically between screens\nwhen the memory use is high (about 700 MB).' => 'Si esta activado, la cache se limpia sola entre pantallas\ncuando el uso de memoria es alto (unos 700 MB).',
		'Clear Cache & Reload Assets' => 'Limpiar cache y recargar',
		'Frees the images and sounds that are not in use.\nThey are loaded again from the game files when they are needed.' => 'Libera las imagenes y sonidos que no se usan.\nSe vuelven a cargar de los archivos del juego cuando hacen falta.',
		'Shows the on-screen buttons (arrows, OK, BACK and the note buttons).' => 'Muestra los botones en pantalla (flechas, OK, BACK y los botones de notas).',
		'Button Size' => 'Tamano de botones',
		'How big the buttons are.' => 'Que tan grandes son los botones.',
		'Button Spacing' => 'Espacio entre botones',
		'The space between the buttons.' => 'El espacio entre los botones.',
		'Button Opacity' => 'Opacidad de botones',
		'How see-through the buttons are.' => 'Que tan transparentes son los botones.',
		'Layout' => 'Disposicion',
		'Classic: arrows on the left, OK/BACK on the right, big note buttons.\nCompact: smaller and closer to the center.\nCustom: the positions you set with "Edit Button Positions".' => 'Classic: flechas a la izquierda, OK/BACK a la derecha, botones de notas grandes.\nCompact: mas pequeno y mas cerca del centro.\nCustom: las posiciones que pusiste con Edit Button Positions.',
		'Edit Button Positions' => 'Editar posicion de botones',
		'Close this menu and drag every button to where you want it.\nPress DONE on the screen to save (the layout becomes Custom).' => 'Cierra este menu y arrastra cada boton adonde quieras.\nPulsa DONE en la pantalla para guardar (la disposicion pasa a Custom).',
		'Vibration' => 'Vibracion',
		'A short vibration when you touch a button (only if your device supports it;\niPhones do not).' => 'Una vibracion corta al tocar un boton (solo si tu dispositivo lo permite;\nlos iPhone no).',
		'Landscape Mode' => 'Modo horizontal',
		'Asks for full screen and locks the screen to landscape (where the browser allows it).' => 'Pide pantalla completa y bloquea la pantalla en horizontal (donde el navegador lo permita).',
		'Prevent Accidental Gestures' => 'Evitar gestos accidentales',
		'Blocks pull-to-refresh, pinch zoom and double-tap zoom, and asks before leaving the page\nwhile a song is playing.' => 'Bloquea el gesto de recargar, el zoom con dos dedos y el doble toque, y pregunta antes de salir de la pagina\nmientras suena una cancion.',
		'Reset Touch Settings' => 'Restablecer controles tactiles',
		'Puts every touch setting back to its default value.' => 'Devuelve todos los ajustes tactiles a su valor por defecto.',
		'Downscroll' => 'Flechas abajo',
		'Middlescroll' => 'Flechas al centro',
		'If checked, your notes get centered.' => 'Si esta activado, tus notas se centran.',
		'Opponent Notes' => 'Notas del rival',
		'If unchecked, opponent notes get hidden.' => 'Si esta desactivado, las notas del rival se ocultan.',
		'Ghost Tapping' => 'Toque libre',
		'If checked, you won\'t get misses from pressing keys\nwhile there are no notes able to be hit.' => 'Si esta activado, no fallas por pulsar teclas\nmientras no hay notas que se puedan golpear.',
		'Auto Pause' => 'Pausa automatica',
		'If checked, the game automatically pauses if the screen isn\'t on focus.' => 'Si esta activado, el juego se pausa solo si la ventana pierde el foco.',
		'Disable Reset Button' => 'Desactivar boton de reinicio',
		'If checked, pressing Reset won\'t do anything.' => 'Si esta activado, pulsar Reset no hace nada.',
		'Hitsound Volume' => 'Volumen del sonido de golpe',
		'Funny notes does "Tick!" when you hit them.' => 'Las notas divertidas hacen "Tick!" al golpearlas.',
		'Rating Offset' => 'Ajuste de puntuacion',
		'Changes how late/early you have to hit for a "Sick!"\nHigher values mean you have to hit later.' => 'Cambia cuan tarde o temprano hay que golpear para un "Sick!"\nValores altos significan golpear mas tarde.',
		'Sick! Hit Window' => 'Ventana de Sick!',
		'Changes the amount of time you have\nfor hitting a "Sick!" in milliseconds.' => 'Cambia el tiempo que tienes\npara un "Sick!" en milisegundos.',
		'Good Hit Window' => 'Ventana de Good',
		'Changes the amount of time you have\nfor hitting a "Good" in milliseconds.' => 'Cambia el tiempo que tienes\npara un "Good" en milisegundos.',
		'Bad Hit Window' => 'Ventana de Bad',
		'Changes the amount of time you have\nfor hitting a "Bad" in milliseconds.' => 'Cambia el tiempo que tienes\npara un "Bad" en milisegundos.',
		'Safe Frames' => 'Cuadros de margen',
		'Changes how many frames you have for\nhitting a note earlier or late.' => 'Cambia cuantos cuadros tienes para\ngolpear una nota antes o despues.',
		'Sustains as One Note' => 'Sostenidas como una nota',
		'If checked, Hold Notes can\'t be pressed if you miss,\nand count as a single Hit/Miss.\nUncheck this if you prefer the old Input System.' => 'Si esta activado, las notas largas no se pueden pulsar si fallas\ny cuentan como un solo acierto o fallo.\nDesactivalo si prefieres el sistema de entrada antiguo.',
		'Low Quality' => 'Baja calidad',
		'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.' => 'Si esta desactivado, se apaga el anti-aliasing y sube el rendimiento\nal costo de imagenes menos nitidas.',
		'Shaders' => 'Shaders',
		'GPU Caching' => 'Cache en GPU',
		'Framerate' => 'Fotogramas por segundo',
		'Pretty self explanatory, isn\'t it?' => 'Se explica solo, no?',
		'Note Skins:' => 'Skins de notas:',
		'Select your prefered Note skin.' => 'Elige tu skin de notas preferida.',
		'Note Splashes:' => 'Salpicaduras de notas:',
		'Select your prefered Note Splash variation or turn it off.' => 'Elige tu variante de salpicaduras de notas o apagalas.',
		'Note Splash Opacity' => 'Opacidad de salpicaduras',
		'How much transparent should the Note Splashes be.' => 'Que tan transparentes son las salpicaduras de las notas.',
		'If checked, hides most HUD elements.' => 'Si esta activado, oculta la mayor parte de los elementos del HUD.',
		'Time Bar:' => 'Barra de tiempo:',
		'What should the Time Bar display?' => 'Que debe mostrar la barra de tiempo?',
		'Flashing Lights' => 'Luces parpadeantes',
		'Uncheck this if you\'re sensitive to flashing lights!' => 'Desactivalo si eres sensible a las luces parpadeantes!',
		'Camera Zooms' => 'Zoom de camara',
		'If unchecked, the camera won\'t zoom in on a beat hit.' => 'Si esta desactivado, la camara no hace zoom en cada golpe de ritmo.',
		'Score Text Zoom on Hit' => 'Zoom del texto de puntos',
		'If unchecked, disables the Score text zooming\neverytime you hit a note.' => 'Si esta desactivado, el texto de puntuacion no hace zoom\ncada vez que golpeas una nota.',
		'How much transparent should the health bar and icons be.' => 'Que tan transparentes son la barra de vida y los iconos.',
		'If unchecked, hides FPS Counter.' => 'Si esta desactivado, oculta el contador de FPS.',
		'Pause Screen Song:' => 'Cancion de la pausa:',
		'What song do you prefer for the Pause Screen?' => 'Que cancion prefieres para la pantalla de pausa?',
		'Check for Updates' => 'Buscar actualizaciones',
		'On Release builds, turn this on to check for updates when you start the game.' => 'En versiones Release, activalo para buscar actualizaciones al iniciar el juego.',
		'Discord Rich Presence' => 'Discord Rich Presence',
		'Uncheck this to prevent accidental leaks, it will hide the Application from your "Playing" box on Discord' => 'Desactivalo para evitar filtraciones accidentales: oculta la aplicacion de tu cuadro "Jugando" en Discord.',
		'Combo Stacking' => 'Apilar combos',
		'If unchecked, Ratings and Combo won\'t stack, saving on System Memory and making them easier to read' => 'Si esta desactivado, las puntuaciones y el combo no se apilan, ahorrando memoria y siendo mas faciles de leer.',
		'Echo Extra' => 'Echo Extra',
		'Graphics' => 'Graficos',
		'Visuals and UI' => 'Visuales e interfaz',
		'Gameplay Settings' => 'Ajustes de juego',
		'Gameplay' => 'Jugabilidad',
		'Controls' => 'Controles',
		'Note Colors' => 'Colores de notas',
		'Adjust Delay and Combo' => 'Ajustar retraso y combo',
		'Resume' => 'Continuar',
		'Restart Song' => 'Reiniciar cancion',
		'Change Difficulty' => 'Cambiar dificultad',
		'Options' => 'Opciones',
		'Exit to menu' => 'Salir al menu',
		'Toggle Practice Mode' => 'Modo practica',
		'Toggle Botplay' => 'Botplay',
		'Leave Charting Mode' => 'Salir del modo chart',
		'Skip Time' => 'Saltar tiempo',
		'End Song' => 'Terminar cancion',
		'Back' => 'Volver',
		'Language' => 'Idioma',
		'Shaders ' => 'Shaders',
		'Changes the language of the menus. Auto follows your browser.\nReopen the menu to see it changed (songs, mods and the main menu pictures stay in English).' => 'Cambia el idioma de los menus. Auto sigue el de tu navegador.\nVuelve a abrir el menu para verlo cambiado (las canciones, los mods y las imagenes del menu principal siguen en ingles).',
		'Visual effects of the game (title screen colors and the like). Off = faster.\nMod shaders (.frag files) cannot run on the web, whatever this says.' => 'Efectos visuales del juego (colores de la pantalla de titulo y similares). Apagado = mas rapido.\nLos shaders de los mods (archivos .frag) no funcionan en la web, digas lo que digas aqui.',
		'Note Color Shader' => 'Shader de color de notas',
		'Auto: each song decides. On: always color the notes with the shader.\nOff: never; use it if a mod\'s arrows already have their own colors and look wrong (strange tints).' => 'Auto: cada cancion decide. On: siempre colorea las notas con el shader.\nOff: nunca; usalo si las flechas de un mod ya tienen sus colores y se ven mal (tintes raros).',
		'Mod Warnings' => 'Avisos de mods',
		'If checked, a notice appears when a song of a mod uses Lua / HScript scripts or shaders,\nwhich the web version cannot run (black backgrounds, missing characters, odd colors).' => 'Si esta activado, aparece un aviso cuando la cancion de un mod usa scripts Lua / HScript o shaders,\nque la version web no puede ejecutar (fondos negros, personajes que faltan, colores raros).',
		'Welcome to Echo Engine 1.1.0!\n\nThis project is for all users.\nIt is not official, and it uses Psych Engine to make it work.\nIt is a fan project: it is not affiliated with Friday Night Funkin\',\nNewgrounds or the creators of Psych Engine.\n\nSome songs and mods contain flashing lights.\nPress ENTER to disable them now (or go to the Options Menu).\nPress ESCAPE to continue.\n\nThanks for playing!' => 'Bienvenido a Echo Engine 1.1.0!\n\nEste proyecto es para todos los usuarios.\nNo es oficial y usa Psych Engine para funcionar.\nEs un proyecto de fans: no esta afiliado con Friday Night Funkin\',\nNewgrounds ni con los creadores de Psych Engine.\n\nAlgunas canciones y mods tienen luces parpadeantes.\nPulsa ENTER para desactivarlas ahora (o ve al menu de opciones).\nPulsa ESCAPE para continuar.\n\nGracias por jugar!',
		'UP / DOWN: scroll   -   BACK: close' => 'ARRIBA / ABAJO: desplazar   -   ATRAS: cerrar',
		'Songs played:       ' => 'Canciones jugadas:   ',
		'Songs completed:    ' => 'Canciones completas: ',
		'Total score:        ' => 'Puntuacion total:    ',
		'Notes hit:          ' => 'Notas golpeadas:    ',
		'Misses: ' => 'Fallos: ',
		'Time playing:       ' => 'Tiempo jugado:      ',
		'Best accuracy:      ' => 'Mejor precision:    ',
		'If checked, notes go Down instead of Up, simple enough.' => 'Si esta activado, las notas bajan en vez de subir, asi de simple.',
		'If checked, disables some background details,\ndecreases loading times and improves performance.' => 'Si esta activado, quita algunos detalles de fondo,\nreduce los tiempos de carga y mejora el rendimiento.',
		'If unchecked, disables shaders.\nIt\'s used for some visual effects, and also CPU intensive for weaker PCs.' => 'Si esta desactivado, se apagan los shaders.\nSe usan para algunos efectos visuales y consumen CPU en equipos flojos.',
		'If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nDon\'t turn this on if you have a shitty Graphics Card.' => 'Si esta activado, la GPU guarda las texturas en cache y baja el uso de RAM.\nNo lo actives si tu tarjeta grafica es mala.',
		'Shader Packs' => 'Paquetes de shaders',
		'A visual look for the whole game, like the shader packs of Minecraft (Newb, Cinematic, Retro CRT...).' => 'Un aspecto visual para todo el juego, como los paquetes de shaders de Minecraft (Newb, Cinematic, Retro CRT...).',
		'Shader Pack' => 'Paquete de shaders',
		'A look for the whole game, like the shader packs of Minecraft.\nNewb: warm light, glow and soft vignette. Cinematic: dark corners and film grain.\nGlow, Dreamy, Retro CRT, Sunset, Night, Noir and Vibrant change the colors and effects.' => 'Un aspecto para todo el juego, como los paquetes de shaders de Minecraft.\nNewb: luz calida, brillo y vineta suave. Cinematic: esquinas oscuras y grano de pelicula.\nGlow, Dreamy, Retro CRT, Sunset, Night, Noir y Vibrant cambian los colores y efectos.',
		'Shader Intensity' => 'Intensidad del shader',
		'How strong the pack is (0% = no effect, 100% = full).' => 'Que tan fuerte es el paquete (0% = sin efecto, 100% = completo).',
		'Glow and Blur' => 'Brillo y desenfoque',
		'If unchecked, the packs skip the glow and blur. Faster on weak devices.' => 'Si esta desactivado, los paquetes no usan brillo ni desenfoque. Mas rapido en equipos flojos.',
		'Only During Songs' => 'Solo durante canciones',
		'If checked, the pack is only applied while you play a song, not in the menus.' => 'Si esta activado, el paquete solo se aplica mientras juegas una cancion, no en los menus.',
		'Shaders (master switch)' => 'Shaders (interruptor general)',
		'If unchecked, every shader effect is off, including these packs.' => 'Si esta desactivado, todos los efectos de shader se apagan, tambien estos paquetes.',
		'Best score:         ' => 'Mejor puntuacion:  ',
		'Top songs:' => 'Mejores canciones:',
		'Press RESET again to erase the stats (any other key cancels)' => 'Pulsa RESET otra vez para borrar las estadisticas (cualquier otra tecla cancela)',
		'BACK: close   -   RESET: erase the stats' => 'ATRAS: cerrar   -   RESET: borrar las estadisticas',
		'This mod uses scripts or shaders, which the web version cannot run.\nExpect black backgrounds, missing characters or odd colors.' => 'Este mod usa scripts o shaders, que la version web no puede ejecutar.\nPuede haber fondos negros, personajes que faltan o colores raros.'
	];
}
