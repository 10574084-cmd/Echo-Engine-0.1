# Web port: cómo publicarlo, usar mods y limitaciones

Port de **[Psych Engine 0.7.3](https://github.com/ShadowMario/FNF-PsychEngine/releases/tag/0.7.3)** (Friday Night Funkin') para el navegador, con un sistema de **mods** adaptado a la web. El código fuente base es el de la release 0.7.3 de ShadowMario.

Se compila a HTML5 con GitHub Actions y se publica en GitHub Pages:
`https://<tu-usuario>.github.io/<nombre-del-repo>/`

> Proyecto de fans, sin relación oficial con Funkin' Crew, Newgrounds ni ShadowMario.

---

## Cómo publicarlo (una sola vez)

1. En el repo: **Settings → Pages → Build and deployment → Source: _GitHub Actions_**.
2. Cada `push` a `main` ejecuta `.github/workflows/pages.yml`, compila y publica. También se puede lanzar a mano desde la pestaña **Actions → Run workflow**.

## Mods

En el menú principal entra en **MODS**.

| Acción | Cómo |
|---|---|
| Instalar | Botón **ADD** y elegir uno o varios `.zip`, o **arrastrar el `.zip` sobre la página** |
| Quitar | Botón **DELETE** (borra el mod de este navegador) |
| Activar / ordenar | Igual que en la versión de escritorio (encendido, subir, bajar) |

* Los mods se guardan en el navegador (**IndexedDB**), así que siguen ahí al recargar. Si borras los datos del sitio, se pierden.
* Se usan los mismos `.zip` de escritorio. Se aceptan estos formatos de zip:
  * `MiMod.zip` → `MiMod/pack.json`, `MiMod/images/…` (una carpeta con el mod)
  * `MiMod.zip` → `pack.json`, `images/…` (los archivos del mod en la raíz; el nombre lo da el zip)
  * un zip con `mods/ModA/…`, `mods/ModB/…` (varios mods a la vez)
* Pensado para mods basados en **archivos**: semanas, canciones (charts + audio `.ogg`/`.mp3`/`.wav`), personajes, escenarios en JSON, imágenes, iconos, sonidos y música.
* **Probado:** importar y persistir un mod, su `pack.json`, una semana y una canción propia (chart + audio `.ogg`), un icono propio, un mod que reemplaza ~30 imágenes de la interfaz en distintos formatos de PNG, una fuente propia, un personaje con una hoja de sprites de 4096×4096, una canción de 5 minutos y la plantilla oficial `example_mods/modTemplate.zip`. El resto de tipos de archivo usan el mismo mecanismo pero no se probaron uno a uno.
* **Imágenes:** se aceptan PNG de cualquier tipo (RGBA, RGB, paleta, escala de grises, 16 bits, entrelazados, con transparencia por `tRNS`). Un mod puede reemplazar las imágenes de la interfaz (`images/menuBG.png`, `healthBar.png`, `num0.png`…), igual que en escritorio.
* **Fuentes:** las fuentes `.ttf`/`.otf`/`.woff`/`.woff2` de `mods/<mod>/fonts/` también se usan (por ejemplo, un `fonts/vcr.ttf` propio reemplaza al original).
* **Errores:** si algo falla, aparece un panel rojo abajo con el error y un botón **Copy**, para poder copiarlo y reportarlo (en vez de quedarse en pantalla negra sin saber por qué).

## Modo online (BETA)

En el menú principal entra en **ONLINE**: duelo **1 contra 1** por código de sala.

1. Uno elige **Create room** y comparte el código de 5 letras que aparece.
2. El otro elige **Join room** y escribe el código.
3. **El anfitrión siempre es Boyfriend.** El que entra elige **su personaje** en una pantalla de selección (con vista previa; salen los personajes del juego y los de los mods importados).
4. Los dos pasan a la lista de canciones: **el anfitrión elige la canción** (el invitado ve la misma selección) y pulsa ENTER.
5. Los dos juegan la misma canción a la vez. Cada uno se ve a sí mismo en el lado del jugador y al rival en el lado del oponente (en lugar del oponente de la canción), con el **marcador del rival en vivo**; al final hay una pantalla de resultado (gana quien tiene más puntos; si empatan, más precisión).

El personaje del rival es solo visual: canta las notas del oponente de la canción, no las teclas reales del otro jugador.

Reglas: sin botplay, sin modificadores y sin morir (solo cuenta la puntuación); no se puede reiniciar la canción. Ambos jugadores deben tener la canción (los mods se importan en cada navegador); si el rival no la tiene, el anfitrión no puede empezarla.

Cómo funciona: el sitio es estático (GitHub Pages), así que no hay servidor de juego. Los navegadores se conectan **directamente** (WebRTC) mediante [PeerJS](https://peerjs.com); su servidor público solo sirve para que los dos se encuentren. La librería se descarga desde unpkg/jsDelivr al abrir ONLINE. Si algún jugador está tras una red muy restrictiva, la conexión puede fallar.

### Limitaciones de la versión web

* **Lua y HScript no están disponibles** (dependen de librerías nativas de C++). Los mods que usan scripts, eventos o notetypes personalizados cargarán, pero sin esa parte.
* **Sin videos** de cutscenes y **sin Discord Rich Presence**.
* **Teléfonos:** al abrir la página pregunta una vez *"Are you using a phone?"*. Si respondes que sí, aparecen botones en pantalla (cruceta + OK/BACK en los menús, 4 botones de notas y pausa durante las canciones; admite varios dedos a la vez) y se pide pantalla completa en horizontal. La respuesta se recuerda; para cambiarla usa `?phone=ask` al final de la dirección (o `?phone=1` / `?phone=0`). En computadora se juega con teclado (el mando no se probó).
* Al abrir la página se descargan unos **75 MB** (todos los assets compartidos, igual que hace el motor original). Las canciones y los assets de cada semana se descargan **solo cuando se juegan** (unos pocos MB por canción).
* No se puede abrir una "carpeta de mods": se usa el importador de `.zip`.

## Echo Extra (Options > Echo Extra)

* **Optimization:** preajustes *Low / Balanced / High* (Low quita shaders, detalles de fondo/partículas, antialiasing y flashes; High sube el límite de FPS), contador de FPS y medidor de memoria, limpieza de caché (manual y automática cuando la memoria pasa de ~700 MB; las imágenes se liberan al abrir la siguiente pantalla porque la actual las está usando).
* **Touch Controls** (solo web): activar/desactivar, tamaño, separación y opacidad de los botones, diseño *Classic / Compact / Custom*, editor para arrastrar los botones, vibración (si el dispositivo la admite), modo horizontal y bloqueo de gestos accidentales. Se guardan en el navegador.
* **Accessibility and HUD:** menos flashes, sin zoom/sacudidas de cámara, ocultar HUD y popups de rating, opacidad de notas y de la barra de vida, teclas, línea de precisión/rendimiento durante la canción. Toda la configuración se guarda sola y se recuerda.
* **Echo Extras:** Echo Theme (colores de los menús), Quick Boot, Random Menu Music, Stats, Echo Lab (opciones experimentales) y About Echo Engine.

## Echo Live: anuncios para todos los jugadores

Una cuenta atrás que le sale a **todo el que tenga el juego abierto** y, al llegar a 0, lo lleva a una canción (o lanza un evento del chart, o solo muestra un aviso).
No hay servidor: el repo tiene una rama `live` con un único archivo `live.json` y cada copia del juego lo lee cada 30 s.

**Cómo lanzarlo:** en GitHub, `Actions > Echo Live (announce something to every player) > Run workflow`, y rellenas:

- `kind`: `song` (todos a una canción), `event` (un evento en los que estén jugando), `message` (solo un aviso) o `clear` (cancela el último anuncio).
- `song` + `difficulty`: nombre de la carpeta de la canción (`bopeebo`, `blammed`...) y dificultad.
- `minutes`: minutos hasta que pase (0-60). Mientras tanto todos ven la cuenta atrás.
- `event`, `value1`, `value2`, `message`: según el tipo.

Quien está dentro de una canción entra a la nueva al terminar la suya; los que están en un duelo online no se tocan; quien no tiene la canción ve un aviso.
Los admins también pueden lanzarlo desde dentro del juego (menú `xd`): hace falta pegar un token de GitHub propio (solo este repo, permiso *Actions: read and write*), que se queda en ese navegador y nunca está en el código; sin token no se puede anunciar nada.
Cualquiera puede saltarse el anuncio con **F9** o tocando la barra, y apagarlos en `Options > Echo Extras > Echo Live Events`.
Un jugador que abre el juego hasta 10 minutos tarde también entra.

## Seguridad (qué cubre y qué no)

Todo el juego corre en el navegador de cada persona, así que **nada del código del cliente puede ser inviolable**: quien controle su navegador (extensión, userscript, herramientas de desarrollo) puede cambiar lo que ocurre *en su propia copia*. Lo que se hizo:

- **Echo Live no se puede falsificar**: el único que puede anunciar algo es quien puede ejecutar el workflow del repo (permisos de GitHub). No hay contraseña ni token dentro del juego. Lo que se lee de `live.json` se valida (tipos, longitudes, lista blanca de eventos, nombre de canción) antes de usarlo.
- **Online**: cada mensaje del rival se valida (tipo, rango, longitud, caracteres), se limita a 60 mensajes por segundo, y solo el host puede iniciar canciones. Los eventos forzados deben estar en una lista blanca de 4.
- **PeerJS alojado en el propio sitio**: el build lo descarga y lo publica junto al juego (`peerjs.min.js`), así la página no carga código de terceros al jugar; en `pages.yml` se puede fijar su hash (`PEERJS_SHA384`). `window.ECHO_ONLINE` (cambiar scripts/servidor) solo funciona en `localhost`.
- **Content-Security-Policy** en `index.html`: solo se permiten scripts del propio sitio, unpkg y jsDelivr, y conexiones a este sitio, GitHub (raw) y PeerJS; no se puede incrustar ni cargar `object`/formularios. Además, si alguien mete el juego en un `iframe` de otra página, se sale de él o se oculta.
- **El menú admin (`xd`)** es solo comodidad local (editores, botplay, god): el código se comprueba en el cliente, así que un usuario avanzado puede saltárselo en *su* copia. Por eso el rival nunca se fía de él: lo que llega por la red se valida igual, y el botplay se marca como `[BOT]`, aunque esa marca la envía el propio cliente y un cliente modificado podría no enviarla.
- **No cubierto**: las extensiones y los gestores de userscripts quedan fuera de la CSP de la página (el navegador las deja pasar), y un cliente modificado puede mandar puntuaciones falsas en un duelo. Para eso haría falta un servidor propio que juzgue las partidas.

## Qué se cambió respecto a Psych Engine 0.7.3

* `Project.xml`: target HTML5, `MODS_ALLOWED` activo en web, un *asset library* por semana, canciones bajo demanda, Discord solo en escritorio.
* `webshim/`: sistema de archivos virtual (memoria + IndexedDB) que sustituye a `sys.FileSystem` / `sys.io.File` en web, importador de `.zip`, decodificador de PNG propio, carga de fuentes y audio para los mods, y un panel de errores, y un parche de `flxanimate` para compilar en HTML5.
* `source/states/LoadingState.hx`: pantalla de carga que descarga la semana y la canción antes de jugarla.
* `source/states/ModsMenuState.hx`: botones **ADD** y **DELETE**.
* `source/echo/`, `source/options/Echo*` y `source/online/`: las funciones propias de Echo Engine (ajustes extra, modo online).
* `PlayState`: el evento *Set Property* ahora convierte los valores a número/booleano (en JavaScript un texto en `defaultCamZoom` dejaba la pantalla negra, p. ej. en Blammed).
* Pequeños ajustes en `Paths`, `Mods`, `CoolUtil`, `WeekData` y `Main` (diferencias entre C++ y JavaScript, lectura de mods, arranque).

## Compilar en local

Necesitas [Haxe 4.3.x](https://haxe.org/download/) y las librerías que aparecen en `.github/workflows/pages.yml`.

```bash
haxelib run lime build Project.xml html5 -release
# resultado: export/release/html5/bin  (hay que servirlo por HTTP, no abrirlo con file://)
cd export/release/html5/bin && python3 -m http.server 8080
```

## Créditos y licencia

* **Psych Engine** por Shadow Mario, Riveren y colaboradores – Apache 2.0 (ver `LICENSE`).
* **Friday Night Funkin'** por ninjamuffin99, PhantomArcade, evilsk8r y kawaisprite.
* `webshim/flxanimate/…` es una copia mínimamente modificada de [flxanimate](https://github.com/ShadowMario/flxanimate) (MIT).
