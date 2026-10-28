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
3. Los dos pasan a la lista de canciones: **el anfitrión elige la canción** (el invitado ve la misma selección) y pulsa ENTER.
4. Los dos juegan la misma canción a la vez; cada uno ve el **marcador del rival en vivo** y al final una pantalla de resultado (gana quien tiene más puntos; si empatan, más precisión).

Reglas: sin botplay, sin modificadores y sin morir (solo cuenta la puntuación); no se puede reiniciar la canción. Ambos jugadores deben tener la canción (los mods se importan en cada navegador); si el rival no la tiene, el anfitrión no puede empezarla.

Cómo funciona: el sitio es estático (GitHub Pages), así que no hay servidor de juego. Los navegadores se conectan **directamente** (WebRTC) mediante [PeerJS](https://peerjs.com); su servidor público solo sirve para que los dos se encuentren. La librería se descarga desde unpkg/jsDelivr al abrir ONLINE. Si algún jugador está tras una red muy restrictiva, la conexión puede fallar.

### Limitaciones de la versión web

* **Lua y HScript no están disponibles** (dependen de librerías nativas de C++). Los mods que usan scripts, eventos o notetypes personalizados cargarán, pero sin esa parte.
* **Sin videos** de cutscenes y **sin Discord Rich Presence**.
* **Sin controles táctiles**: se juega con teclado (el mando no se probó).
* Al abrir la página se descargan unos **75 MB** (todos los assets compartidos, igual que hace el motor original). Las canciones y los assets de cada semana se descargan **solo cuando se juegan** (unos pocos MB por canción).
* No se puede abrir una "carpeta de mods": se usa el importador de `.zip`.

## Qué se cambió respecto a Psych Engine 0.7.3

* `Project.xml`: target HTML5, `MODS_ALLOWED` activo en web, un *asset library* por semana, canciones bajo demanda, Discord solo en escritorio.
* `webshim/`: sistema de archivos virtual (memoria + IndexedDB) que sustituye a `sys.FileSystem` / `sys.io.File` en web, importador de `.zip`, decodificador de PNG propio, carga de fuentes y audio para los mods, y un panel de errores, y un parche de `flxanimate` para compilar en HTML5.
* `source/states/LoadingState.hx`: pantalla de carga que descarga la semana y la canción antes de jugarla.
* `source/states/ModsMenuState.hx`: botones **ADD** y **DELETE**.
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
