<div align="center">

<img src="docs/images/logo.svg" width="140" alt="Logo de faro: un faro con haces de luz ámbar y olas, dentro de un círculo azul">

# faro

**Tu Mac tiene mucho que decir. faro lo pone a tu alcance.**
Un centro de control nativo, local y personalizable que vive en la barra de menú y el notch. Widgets, audio por aplicación, una mascota que reacciona contigo y las herramientas que usas todos los días, sin cuentas ni telemetría.

[Sitio oficial](https://faro.conectalab.co) · [Descargar](https://faro.conectalab.co/descargar) · [Actualizaciones](https://faro.conectalab.co/actualizaciones) · [Press kit](https://faro.conectalab.co/prensa) · [Reportar un problema](https://github.com/dpulr/faro/issues)

[![Compilación](https://github.com/dpulr/faro/actions/workflows/ci.yml/badge.svg)](https://github.com/dpulr/faro/actions/workflows/ci.yml)
[![Versión](https://img.shields.io/github/v/release/dpulr/faro)](https://github.com/dpulr/faro/releases/latest)
[![Descargas](https://img.shields.io/github/downloads/dpulr/faro/total)](https://github.com/dpulr/faro/releases)
[![Licencia: AGPL v3](https://img.shields.io/badge/licencia-AGPL--3.0--or--later-2e7d6b.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-lightgrey)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![Sin telemetría](https://img.shields.io/badge/telemetr%C3%ADa-ninguna-brightgreen)

<img src="docs/images/menu.png" width="420" alt="El menú de faro: foto actual, botones redondos, canal y perfil, y un resumen del Mac">

<br>
<a href="https://conectalab.co"><img src="site/public/img/conectalab-logo-black.svg" width="180" alt="Un producto de Conecta Lab"></a>

</div>

> **English:** Read the complete [English README](README.en.md).

---

## Contenido

- [¿Qué es faro?](#qué-es-faro)
- [La mascota](#la-mascota)
- [Funciones](#funciones)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Atajos de teclado](#atajos-de-teclado)
- [Permisos y privacidad](#permisos-y-privacidad)
- [Fuentes de fotos y atribuciones](#fuentes-de-fotos-y-atribuciones)
- [Dónde guarda cada cosa](#dónde-guarda-cada-cosa)
- [Desarrollo](#desarrollo)
- [Preguntas frecuentes](#preguntas-frecuentes)
- [Hoja de ruta](#hoja-de-ruta)
- [Contribuir, seguridad y conducta](#contribuir-seguridad-y-conducta)
- [Licencia](#licencia)

---

## ¿Qué es faro?

faro es un producto de [Conecta Lab](https://conectalab.co) que reúne en una experiencia nativa las herramientas cotidianas que hacen al Mac más claro, rápido y personal. Vive en la barra de menú, no ocupa el Dock y cada control explica lo que hace al pasar el cursor.

Principios con los que está hecho:

- **Local primero.** Tus datos viven en tu Mac. No hay cuentas, ni telemetría, ni servidor propio.
- **Minimalista y en lenguaje llano.** Pocas cosas en pantalla y textos que cualquiera entiende, en español o en inglés.
- **Sin pagos ni claves de API.** Las fuentes de fotos, el clima y la medición de internet funcionan sin registrarse en nada.
- **Respeta tu disco.** Solo guarda la foto actual de cada monitor; todo lo demás se descarga y se borra.
- **Diseño propio.** Cristal líquido en macOS 26, un logo de faro dibujado a mano (disponible en [SVG](docs/images/logo.svg)) y controles propios en lugar de los genéricos del sistema.

## La mascota

<p align="center">
  <img src="docs/images/mascota-personalizada.png" width="680" alt="Tres versiones personalizadas de la mascota de faro, con diferentes colores, ojos y accesorios">
</p>

Una pequeña luz vive en el notch. **Sigue el cursor con la mirada, baila con la música, celebra cuando termina un temporizador, reacciona al Bluetooth y se duerme cuando no la usas.** Puedes cambiar su forma, color, ojos, accesorio y tiempo de descanso, o apagarla por completo.

<img src="docs/images/mascota.png" width="900" alt="Página Mascota de faro con expresiones, colores, accesorios y una vista previa en vivo">

## Funciones

### Fondos de pantalla con canales mezclados

<img src="docs/images/fondos.png" width="760" alt="Página Fondos: la foto actual con cuatro botones y, debajo, los canales como tarjetas">

Un **canal** es un tema; una **mezcla** reparte las fotos entre varios canales. Un clic activa un canal; el lápiz (al pasar el cursor) lo edita.

- **Siete fuentes sin clave:** [Wallhaven](https://wallhaven.cc) (solo contenido seguro), [Wikimedia Commons](https://commons.wikimedia.org) (solo fotos destacadas), el archivo de [Bing](https://www.bing.com) en UHD, el [Art Institute of Chicago](https://www.artic.edu) (obras de dominio público), las [imágenes de la NASA](https://images.nasa.gov), [Picsum](https://picsum.photos) (fotos al azar) y **carpetas locales**.
- **Mezcla por niveles:** cada fuente o canal pesa *Poco*, *Normal* o *Mucho*. El sorteo respeta esos pesos de verdad.
- **Canales de fábrica:** Naturaleza, Bing del día, Tecnología, Ciencia, Autos, una mezcla de los tres últimos, Arte, Espacio y Al azar.
- **Filtros:** resolución mínima respecto a tu pantalla (flexible, alta o exacta), solo fotos horizontales, sin repetir las últimas 50 y una lista de fotos **ocultas para siempre**.
- **Control total:** volver a la foto anterior, guardar la actual en `Imágenes/faro`, marcar *No me gusta* y un fondo distinto por monitor.
- **Intervalo:** cada 15 o 30 minutos, 1, 2 o 6 horas, 1 día, o solo a mano.

<img src="docs/images/editar-canal.png" width="520" alt="Ventana para editar una mezcla de canales con niveles Poco, Normal y Mucho">

### Escenas Faro

<img src="docs/images/perfiles.png" width="760" alt="Página Escenas Faro con modos de uso y activación automática">

Una escena guarda la **experiencia completa**: diseño, widgets y herramientas del notch; fondos; modo despierto; datos de la barra de menú y descanso visual. Faro puede preparar escenas para *Trabajo*, *Reunión*, *Multimedia*, *Escritorio* y *Minimal*, y activarlas por la aplicación al frente, una reunión próxima, pantalla completa, Bluetooth, monitor externo, batería o un horario. Al entrar puede ajustar volumen, brillo y micrófono, iniciar un enfoque o abrir apps y enlaces; al salir restaura los controles anteriores. Incluye explicación de cada cambio, pausa temporal, prioridad entre reglas, historial, enlaces para Atajos, duplicado e importación/exportación.

### Centro de comandos

Pulsa `⌃⌥⌘F` desde cualquier aplicación para buscar y ejecutar todo lo que Faro sabe hacer: activar escenas, abrir secciones, cambiar el fondo, controlar audio y micrófono, iniciar el temporizador, mantener despierto el Mac, abrir emojis, usar el gotero o limpiar el teclado. Funciona completamente en el Mac, se maneja con teclado y permite fijar favoritos; también está disponible en la barra de menú y como herramienta del notch.

### Sistema, internet y energía

<img src="docs/images/sistema.png" width="760" alt="Página Sistema con procesador, memoria, almacenamiento y red en vivo">

- **Sistema:** procesador, memoria, almacenamiento, red en vivo y batería (ciclos y salud), con gráficas y un resumen en lenguaje llano ("Tu Mac va tranquilo").
- **Internet:** mide tu conexión con la herramienta `networkQuality` de macOS, a mano o **automáticamente** cada 30 minutos a 1 día, y guarda un historial con gráfica.
- **Energía:** mantiene el Mac despierto durante 30 minutos a 8 horas, o sin límite. Y **cuida la batería**: avisa al 80 % para desenchufar, recuerda si sigue enchufada y guarda el historial de su salud.
- **Audio:** el volumen y la salida de tu Mac (bocinas, audífonos, AirPlay) a mano, con una pestaña del notch que detecta las aplicaciones que están reproduciendo. Música y Spotify tienen volumen independiente; Chrome y las demás aparecen vinculadas al volumen general que permite macOS.

<img src="docs/images/audio.png" width="760" alt="Página Audio con la salida, el volumen y el volumen por app">
<img src="docs/images/notch-audio.png" width="760" alt="Pestaña Audio del notch con volumen general y controles para las aplicaciones que están reproduciendo">

### Diagnóstico y equipo conectado

<img src="docs/images/diagnostico.png" width="760" alt="Página Diagnóstico con el estado del Mac, cargador, puertos, discos, ventiladores y periféricos">

Faro reúne en una sola página lo que suele estar repartido por macOS:

- **Qué frena al Mac:** memoria, procesador, disco, temperatura y energía, con la aplicación que más consume y un botón para actuar.
- **Cargador explicado:** potencia del adaptador, energía que entra al Mac, consumo del sistema y vatios que llegan a la batería.
- **Puertos USB-C y MagSafe:** capacidad, transportes activos —USB, Thunderbolt o DisplayPort—, cable activo u óptico cuando macOS lo informa y detección de humedad.
- **Discos externos:** nombre, conexión, espacio disponible y botón para expulsar uno o todos.
- **Ventiladores:** revoluciones y carga de cada ventilador, siempre en solo lectura.
- **Periféricos:** batería y carga de AirPods, teclados, ratones y trackpads compatibles.
- **Equipo en el notch:** una pestaña independiente resume estado, conexión, cargador, ventiladores y discos; un punto naranja aparece cuando algo requiere atención.

<img src="docs/images/notch-equipo.png" width="760" alt="Pestaña Equipo del notch con estado, conexión, cargador, ventiladores y discos externos">

### Almacenamiento y limpieza

Encuentra qué ocupa espacio y lo libera **sin tocar tus documentos**.

- **Asistente:** ordena las recomendaciones por espacio recuperable y seguridad, con un botón *Limpiar lo seguro* (a la Papelera, con confirmación).
- **Limpieza guiada** por categorías seguras: compilaciones de Xcode, símbolos de dispositivos iOS, cachés de apps, registros, Gradle, npm, cachés de herramientas y, marcadas como "Revisa antes", los archivos de Xcode y los emuladores de Android.
- **Simuladores de iOS:** quita los que ya no funcionan con tu Xcode.
- **Archivos grandes** (más de 300 MB), con el tiempo que llevan **sin tocarse** para encontrar los olvidados, y un **explorador de carpetas** con barras de tamaño.
- **Predicción de llenado:** con unos días de datos estima cuándo se llenaría el disco y avisa si falta menos de dos semanas.
- **Widget del notch accionable:** analiza y limpia lo seguro desde el propio panel.
- **Aviso de poco espacio:** una notificación y una señal en el notch cuando el disco baja de un umbral que eliges (5 a 100 GB); no repite hasta que empeora o se recupera.
- **Seguro por diseño:** solo borra dentro de una lista blanca de carpetas conocidas, manda a la Papelera por defecto y pide confirmación siempre.

### Portapapeles con historial

<img src="docs/images/portapapeles.png" width="760" alt="Página Portapapeles con ajustes de privacidad e historial">

Nada se pierde: cada texto o imagen que copias queda guardado, con búsqueda y la opción de fijar lo importante.

- **Panel junto al cursor** con `⌃⌥⌘V`: escribe para buscar, `↑↓` para elegir y `↵` para pegar.
- **Privacidad primero:** ignora lo que los gestores de contraseñas marcan como secreto y lo que copies desde apps que excluyas (1Password, Bitwarden, Llaveros y otras vienen excluidas).
- **Se limpia solo:** conserva 24 horas, 7 o 30 días (o sin límite) y un máximo de elementos; lo fijado nunca se borra.
- **Pegado automático** opcional (necesita el permiso de Accesibilidad); sin él, el elemento se copia y pegas tú con `⌘V`.

### Bandeja de archivos

<img src="docs/images/bandeja.png" width="520" alt="La bandeja de archivos con varios archivos y carpetas">

Un panel flotante para llevar archivos de una app a otra. Se abre con `⌃⌥⌘B`.

- **Arrastra dentro y fuera:** también puedes soltar archivos directamente sobre el ícono de faro en la barra de menú.
- **No gasta disco:** guarda referencias a los archivos, no copias.
- **Convertir imágenes** (PNG, JPEG, HEIC, TIFF) y **comprimir o descomprimir zip** desde el menú de cada archivo, sin conexión.
- **AirDrop** de un archivo o de toda la bandeja, doble clic para abrir y clic derecho para mostrar en Finder.

### Limpiar teclado

<img src="docs/images/limpiar-teclado.png" width="760" alt="Página Limpiar teclado con duración y modos de bloqueo">

Bloquea las teclas un momento para limpiarlas sin escribir nada por accidente. La pantalla se oscurece con una cuenta regresiva.

- **Bloqueo básico, sin permisos:** faro ocupa la pantalla, se queda con el teclado, descarta todo lo que pulses e impide cambiar de app con `⌘Tab`.
- **Bloqueo completo (opcional):** con el permiso de Accesibilidad bloquea además volumen, brillo y los atajos del sistema.
- **Siempre se puede salir:** al llegar a cero, **manteniendo `Esc` 3 segundos**, o con el botón *Terminar ahora* si no bloqueaste el trackpad.

<img src="docs/images/pantalla-de-limpieza.png" width="520" alt="La pantalla oscura con la cuenta regresiva durante la limpieza del teclado">

### Panel del notch

<p align="center">
  <img src="docs/images/notch.png" width="480" alt="El panel del notch desplegado con música y clima">
  <img src="docs/images/notch-alas.png" width="480" alt="El notch con las alas que aparecen mientras suena música">
</p>

<img src="docs/images/notch-configurar.png" width="900" alt="Editor visual del notch con vista previa, widgets arrastrables y controles de ancho">

Un panel negro que cuelga del notch: lleva el cursor arriba al centro de la pantalla y se despliega. Mientras suena música o corre un descanso, aparecen detalles a los lados **sin desplegarlo**.

- **Música:** lo que suena en Música o Spotify, con carátula y controles, y **letras sincronizadas** ([LRCLIB](https://lrclib.net)) bajo la pastilla.
- **Clima:** temperatura y estado del cielo de tu ciudad, con [Open-Meteo](https://open-meteo.com).
- **Calendario:** tu próximo evento de las siguientes 24 horas (apagado por defecto).
- **Descanso visual:** un aviso para mirar a lo lejos 20 segundos, la regla 20-20-20 (apagado por defecto).
- **Volumen:** un control del volumen de tu Mac dentro del panel.
- **Bluetooth:** un aviso al conectarse tus audífonos, teclado, ratón o mando.
- **Soltar archivos:** arrastra un archivo hacia el notch y suéltalo en la zona que aparece; se guarda en la bandeja.
- **Notch a tu medida:** widgets que activas, ordenas y redimensionas, pestañas, dock de herramientas y varios estilos. En un Mac sin notch, una isla flotante hace lo mismo.
- **Configuración en segundos:** plantillas Minimal, Productividad, Multimedia y Centro de control, más un editor directo sobre una vista previa fiel del notch.
- **Mezclador en el notch:** una pestaña Audio reúne el volumen general, la salida activa y las aplicaciones que están reproduciendo. Música y Spotify tienen controles independientes; Chrome y las demás apps aparecen vinculadas al volumen general que permite macOS.
- **Editor visual:** arrastra widgets sobre una vista previa real, cambia su prioridad y elige anchos de 1/3, 2/3 o completos.
- **Cada detalle cuenta:** títulos, iconos, descripciones, fondos, forma de las herramientas y letras de cero, una o dos líneas son configurables.
- **Mascota:** un personaje que sigue el cursor, baila con la música, se pone azul con el Bluetooth y se duerme sola cuando no usas el notch. Se personaliza (forma, color, ojos y accesorio).
- **Temporizador:** Pomodoro o temporizador simple, con la cuenta visible en la pastilla.
- **Silenciar el micrófono** con un botón o `⌃⌥⌘M`, **batería de AirPods y otros dispositivos**, **gotero de color**.
- **Avisos:** batería llena o baja, descarga terminada, captura de pantalla (va a la bandeja), disco USB conectado (con botón para expulsar), cámara o micrófono en uso y Bloq Mayús.
- **Cómo se abre:** al pasar el cursor o solo con un clic (*Notch → Cómo se abre*).
- **Accesos rápidos:** dos botones abren el portapapeles y la bandeja.
- **Poco espacio en disco:** el notch muestra una señal ámbar cuando se acaba el espacio.

<img src="docs/images/notch-soltar.png" width="480" alt="La zona para soltar archivos sobre el notch">

Sin notch, el panel aparece como una cápsula arriba al centro.

### Barra de menú y apariencia

- **Datos en vivo en la barra:** procesador, memoria, espacio libre, red, batería y velocidad de internet, a tu elección y con vista previa.
- **El faro se enciende:** el ícono de la barra, un faro dentro de un círculo, muestra los haces de luz cuando el Mac está en modo despierto.
- **Cristal líquido** en macOS 26 (con un material translúcido equivalente en versiones anteriores).
- **Idioma:** español, inglés o el del sistema (*General → Idioma*; faro se reinicia al cambiarlo).
- **Tus colores:** color de resalte (siete listos y uno libre), tinte del cristal del menú y color de fondo de la ventana.

## Requisitos

| | |
|---|---|
| **Sistema** | macOS 14 (Sonoma) o posterior. En un MacBook con notch se integra al recorte; en cualquier otra pantalla aparece como una isla flotante compacta. |
| **Para compilar** | Xcode 26 o posterior (SDK de macOS 26) y Swift 5.9 o posterior. |
| **Probado en** | MacBook con Apple Silicon y macOS 26. |

## Instalación

Descarga el `.dmg` firmado y notarizado por Apple desde la [última Release](https://github.com/dpulr/faro/releases/latest) o desde la [página oficial](https://faro.conectalab.co/descargar), y arrastra faro a *Aplicaciones*. Si prefieres compilarlo tú, usa el código fuente. Para publicar una versión, mira [`docs/DISTRIBUCION.md`](docs/DISTRIBUCION.md).

```bash
git clone https://github.com/dpulr/faro.git
cd faro
./scripts/build-app.sh
```

El script compila en modo *release*, firma la app con la identidad de **Apple Development** que encuentre en tu llavero (así macOS conserva los permisos entre compilaciones; sin identidad, firma sin ella y los permisos se vuelven a pedir) e instala `faro.app` en `/Applications`.

Para que arranque con tu sesión, activa **Abrir al iniciar sesión** en la página *General*.

> **Primer arranque:** faro se abre con su ventana principal. Después vive en la barra de menú: el ícono del faro abre el menú (pulsar el logo dentro del menú expande la ventana), y soltar archivos sobre él los manda a la bandeja.
>
> **Cerrar con `⌘Q`:** faro pregunta antes de cerrarse, y ofrece minimizar solo la vista de escritorio para que siga en la barra de menú.

## Atajos de teclado

| Atajo | Acción |
|---|---|
| `⌃⌥⌘ →` | Siguiente foto |
| `⌃⌥⌘ ←` | Foto anterior |
| `⌃⌥⌘ H` | Ocultar esta foto para siempre |
| `⌃⌥⌘ S` | Guardar esta foto en `Imágenes/faro` |
| `⌃⌥⌘ V` | Historial del portapapeles |
| `⌃⌥⌘ B` | Bandeja de archivos |

Los atajos usan una API de macOS que **no requiere permisos especiales**.

## Permisos y privacidad

faro pide solo lo que cada función necesita, y cada permiso es **opcional**:

| Permiso | Para qué | Si no lo das |
|---|---|---|
| **Accesibilidad** | Bloqueo *completo* del teclado y pegado automático del portapapeles | El bloqueo básico sigue funcionando; el portapapeles solo copia |
| **Automatización: Finder** | Vaciar la Papelera desde la limpieza | Lo haces tú desde Finder |
| **Automatización: Música y Spotify** | Mostrar lo que suena en el notch | El notch no muestra música |
| **Calendarios** | Mostrar tu próximo evento en el notch | Ese módulo queda apagado |
| **Bluetooth** | Avisar en el notch cuando se conecta un dispositivo | Sin aviso de conexión |
| **Notificaciones** | El aviso de poco espacio en disco y el de versiones nuevas | Solo queda la señal en el notch |
| **Carpetas Descargas y Escritorio** | Los avisos de descarga terminada y de capturas de pantalla (ambos apagados por defecto) | Esos avisos no funcionan |

### Qué sale de tu Mac

faro **no tiene telemetría ni cuentas**. Las únicas conexiones que hace son estas, y solo si usas la función:

| Servicio | Para qué | Qué se envía |
|---|---|---|
| `wallhaven.cc` | Buscar fotos | El tema que escribiste y la resolución mínima |
| `commons.wikimedia.org` y `upload.wikimedia.org` | Buscar y bajar fotos | El tema que escribiste |
| `www.bing.com` | Fotos del día | Nada personal |
| `open-meteo.com` | Clima | La ciudad que escribiste |
| Servidores de Apple (`networkQuality`) | Medir la conexión | Lo normal de una prueba de velocidad |
| Cloudflare (`1.1.1.1`) | Comprobar latencia y detectar caídas | Una conexión TCP sin datos personales |
| `api.artic.edu` y `www.artic.edu` | Obras del Art Institute of Chicago | El tema que escribiste |
| `images-api.nasa.gov` y `images-assets.nasa.gov` | Imágenes de la NASA | El tema que escribiste |
| `picsum.photos` | Fotos al azar | Nada personal |
| `faro.conectalab.co` | Avisar de versiones nuevas (un archivo público, una vez al día; se apaga en *General*) | Nada personal |
| `lrclib.net` | Letras sincronizadas (se apaga en *Notch*) | El título y el artista de la canción que suena |
| `i.scdn.co` | Carátula de Spotify | Solo mientras suena algo de Spotify |

Todo lo demás —historial del portapapeles, bandeja, ajustes, fotos— **se queda en tu disco**. El portapapeles no guarda lo que los gestores de contraseñas marcan como secreto. Para borrarlo todo, quita la carpeta de datos (abajo).

## Fuentes de fotos y atribuciones

faro **no redistribuye imágenes**: las descarga de cada fuente para mostrarlas en tu escritorio, con el título y el autor a la vista. Cada foto tiene su propia licencia, y las de Wikimedia Commons suelen exigir atribución: por eso faro muestra el nombre del autor junto a la imagen. Las fotos que guardas con el botón de guardar son para tu uso personal; respeta la licencia de cada una si las compartes.

## Dónde guarda cada cosa

| Qué | Dónde |
|---|---|
| Ajustes, canales, perfiles e historial de fotos | `~/Library/Application Support/faro/state.json` |
| Portapapeles (texto e imágenes) | `~/Library/Application Support/faro/clipboard.json` y `clips/` |
| Bandeja y mediciones de internet | `shelf.json` y `speed.json` (misma carpeta) |
| Foto actual de cada monitor | `~/Library/Caches/faro/current/` |
| Fotos que guardas con el botón de guardar | `~/Pictures/faro/` |
| Apariencia, notch y limpieza de teclado | Preferencias de la app (`defaults read co.soyholistico.faro`) |

## Desarrollo

```
Sources/faro/
├── main.swift, AppDelegate.swift   Arranque (AppKit puro) y menú principal
├── Core/                           Motor de fondos, modelos, persistencia, AppController
├── Sources/                        Fuentes de fotos (Wallhaven, Wikimedia, Bing, Art Institute, NASA, Picsum, carpeta)
├── Modules/                        Monitor del sistema, internet, despierto, audio, aviso de disco
├── Storage/                        Limpieza y análisis de disco
├── Clipboard/  Shelf/  Cleaning/   Portapapeles, bandeja y limpiar teclado
├── Notch/                          Modelo, vista y controlador del panel del notch
└── UI/                             Páginas, menú, tema, controles propios y `tr()` (idioma)
Resources/                          Traducciones (`es.lproj`, `en.lproj`), generadas desde `scripts/en.txt`
```

La arquitectura, con los porqués de cada decisión, está en [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md).

### Herramientas de prueba

faro trae modos de prueba, activados con variables de entorno, que no cambian nada en uso normal:

| Variable | Qué hace |
|---|---|
| `python3 scripts/gen-strings.py` | Genera `Resources/en.lproj/Localizable.strings` desde `scripts/en.txt` (líneas `español => english`) |
| `python3 scripts/make-logo.py` | Regenera el logo (`docs/images/logo.svg`, `logo-mark.svg`) y el código Swift que lo dibuja |
| `FARO_SELFTEST=1 .build/release/faro` | Cambia el fondo 8 veces e imprime la fuente de cada foto y el tamaño de la caché |
| `FARO_SNAPSHOT=<carpeta>` | Dibuja cada pantalla a PNG sin abrir la app |
| `open --env FARO_DEBUG_SHOT=<carpeta> --stdout <archivo> -n /Applications/faro.app` | Abre menú, bandeja y notch de verdad, ejecuta pruebas y captura las ventanas |
| `open --env FARO_DEBUG_PERMS=<archivo> -n /Applications/faro.app` | Escribe qué permisos ve la app y prueba el bloqueo de teclado |

### Convenciones de diseño

- Sin tipografía con serifa y sin controles genéricos del sistema: usa los de [`UI/Controls.swift`](Sources/faro/UI/Controls.swift).
- Botones redondos **sin texto**, con ayuda instantánea (`.instantTip`).
- Todo el texto en español y en lenguaje llano.
- Cada archivo de código lleva el encabezado de licencia SPDX.

## Preguntas frecuentes

**¿Por qué pide el permiso de Accesibilidad?**
Solo para el bloqueo *completo* del teclado y para pegar automáticamente desde el historial. Nada más lo usa, y se puede negar sin perder ninguna otra función.

**¿Borra algo de mi disco sin avisar?**
No. La limpieza solo actúa sobre lo que marcas, dentro de una lista blanca de carpetas conocidas, manda a la Papelera por defecto y siempre pide confirmación.

**¿Por qué no está en la App Store?**
Funciones como el bloqueo de teclado, el panel del notch y la lectura de Música o Spotify no son compatibles con el entorno restringido de la App Store.

**¿Funciona sin notch?**
Sí. El panel aparece como una cápsula arriba al centro de la pantalla.

**¿Por qué se llama faro?**
Por la idea de una luz que te muestra lo importante desde lejos.

## Hoja de ruta

Ideas que no están hechas todavía, sin fechas:

- Volumen por aplicación para cualquier app (macOS no lo permite sin un controlador de audio propio).
- Más idiomas.
- Integración opcional con modos de concentración y redes Wi‑Fi cuando macOS permita hacerlo sin sacrificar privacidad.

Las propuestas y los fallos se reportan en [Issues](https://github.com/dpulr/faro/issues).

## Contribuir, seguridad y conducta

- **Contribuir:** lee [`CONTRIBUTING.md`](CONTRIBUTING.md).
- **Reportar una vulnerabilidad:** sigue [`SECURITY.md`](SECURITY.md); no abras un issue público.
- **Convivencia:** este proyecto sigue un [código de conducta](CODE_OF_CONDUCT.md).

## Licencia

faro es **software libre** bajo la licencia **GNU Affero General Public License, versión 3 o posterior** (AGPL-3.0-or-later). El texto completo está en [`LICENSE`](LICENSE).

En palabras llanas, y sin ser asesoría legal: puedes usarlo, estudiarlo, modificarlo y compartirlo. Si distribuyes una versión modificada —o la ofreces a otras personas a través de una red— debes publicar su código fuente bajo esta misma licencia. El programa se ofrece **sin ninguna garantía**.

Copyright © 2026 Conecta Lab Corp.

Los servicios de datos, sus condiciones y las licencias necesarias están documentados en [`CREDITS.md`](CREDITS.md).
