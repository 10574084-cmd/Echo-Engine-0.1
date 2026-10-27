# Psych Engine 0.7.3 – Web Port

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
* **Probado:** importar y persistir un mod, su `pack.json`, una semana y una canción propia (chart + audio `.ogg`), un icono propio y la plantilla oficial `example_mods/modTemplate.zip`. El resto de tipos de archivo usan el mismo mecanismo pero no se probaron uno a uno.
* **No soportado:** fuentes (`.ttf`) dentro de mods.

### Limitaciones de la versión web

* **Lua y HScript no están disponibles** (dependen de librerías nativas de C++). Los mods que usan scripts, eventos o notetypes personalizados cargarán, pero sin esa parte.
* **Sin videos** de cutscenes y **sin Discord Rich Presence**.
* **Sin controles táctiles**: se juega con teclado (el mando no se probó).
* Al abrir la página se descargan unos **75 MB** (todos los assets compartidos, igual que hace el motor original). Las canciones y los assets de cada semana se descargan **solo cuando se juegan** (unos pocos MB por canción).
* No se puede abrir una "carpeta de mods": se usa el importador de `.zip`.

## Qué se cambió respecto a Psych Engine 0.7.3

* `Project.xml`: target HTML5, `MODS_ALLOWED` activo en web, un *asset library* por semana, canciones bajo demanda, Discord solo en escritorio.
* `webshim/`: sistema de archivos virtual (memoria + IndexedDB) que sustituye a `sys.FileSystem` / `sys.io.File` en web, importador de `.zip`, decodificador de PNG y audio para los mods, y un parche de `flxanimate` para compilar en HTML5.
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
