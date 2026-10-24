# Historial de cambios

Todos los cambios importantes de faro se anotan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones siguen [SemVer](https://semver.org/lang/es/).

## [1.5.0] — 2026-10-24

### Novedades en el notch
- **Temporizador:** un Pomodoro (enfoque y descanso, con duraciones a tu gusto) o un temporizador simple. La cuenta se ve en la pastilla con el notch recogido, con pausa, saltar y reiniciar en el panel.
- **Silenciar el micrófono** para todas las apps con un botón del panel o con `⌃⌥⌘M`.
- **Batería de dispositivos:** la carga de tus AirPods (con el estuche), teclado, ratón y trackpad Bluetooth, junto al clima.
- **Batería llena y baja:** avisa al llegar al nivel que elijas (80 a 100) para desenchufar, y al 20 y al 10 por ciento cuando no cargas.
- **Descargas terminadas:** un aviso con botón *Mostrar* cuando termina una descarga en Descargas (apagado por defecto).
- **Capturas de pantalla a la bandeja:** cada captura nueva entra sola a la bandeja (apagado por defecto).
- **Discos USB:** un aviso con botón *Expulsar* al conectar una memoria o un disco.
- **Cámara y micrófono en uso:** un punto verde o naranja junto al notch cuando una app los usa.
- **Bloq Mayús:** un aviso breve al activarlo o desactivarlo.
- **Gotero de color:** toma el color de cualquier punto de la pantalla y copia su código.
- Los avisos del notch ahora pueden llevar un botón de acción.

### Novedades en la bandeja
- **Convertir imágenes** (PNG, JPEG, HEIC, TIFF) y **comprimir o descomprimir zip**, sin conexión, desde el menú de cada archivo.

## [1.4.0] — 2026-10-24

### Novedades
- **Aviso de versiones nuevas.** faro consulta una vez al día el archivo público `latest.json` del sitio y, si hay una versión más reciente, lo avisa con una notificación y en *General* (con un botón para descargarla). No envía datos tuyos y nunca instala nada solo. Se puede apagar y también buscar a mano.
- **Política de privacidad** en el sitio de faro, en español y en inglés.

## [1.3.0] — 2026-10-23

### Novedades
- **Notch: accesos rápidos.** Dos botones redondos junto al clima abren el historial del portapapeles y la bandeja de archivos.
- **Notch: cómo se abre.** Nuevo ajuste en *Notch → Cómo se abre*: *Al pasar* el cursor (como antes) o *Con un clic*, para quien no quiere que el panel se despliegue solo.
- El descanso visual en el panel se simplifica a un ojo y los minutos que faltan.

### Arreglos
- **Soltar archivos sobre el notch** funciona también al arrastrar desde la carpeta del Dock: una ventana casi invisible sobre el notch recibe el arrastre y ya no depende del portapapeles de arrastre.
- Los textos del descanso y del evento del calendario en el panel ya se traducen al inglés.

## [1.2.0] — 2026-10-23

### Novedades
- **Interfaz en inglés.** faro sigue el idioma del sistema, o puedes elegir *Español* o *English* en *General → Idioma* (se reinicia al cambiarlo). Las traducciones salen de `scripts/en.txt`, que `scripts/gen-strings.py` convierte en `Resources/en.lproj/Localizable.strings`.
- **Tres fuentes de fotos nuevas, sin clave:** Art Institute of Chicago (dominio público), imágenes de la NASA y Picsum (fotos al azar), con tres canales de fábrica: *Arte*, *Espacio* y *Al azar*. Las fotos más pequeñas que tu pantalla se descartan y se reintenta.
- **Página Audio:** volumen, silencio y salida de tu Mac, y volumen propio de Música y Spotify.
- **Notch:** fila de volumen, aviso al conectarse un dispositivo Bluetooth (audífonos, teclado, ratón, mando), zona para **soltar archivos** que van a la bandeja y señal de poco espacio en disco.
- **Aviso de poco espacio en disco** en *Almacenamiento*: notificación y señal en el notch con un umbral a tu elección.

### Cambios
- Nuevos permisos opcionales: Bluetooth y Notificaciones.
- Los textos que se arman en el código pasan por `tr()` para poder traducirse.

## [1.1.0] — 2026-10-23

### Cambios
- **Logo nuevo:** un faro con haces de luz ámbar y olas. En la barra de menú va dentro de un círculo y de una sola tinta (con los haces encendidos en modo despierto); en la ventana de escritorio aparece solo el emblema junto a "faro" en minúscula. El logo se publica también como [SVG](docs/images/logo.svg) y nuevo ícono de la app.
- **Barra superior del menú:** el logo abre la ventana de escritorio; las flechas de expandir y el apagado pasan a ser íconos discretos, sin botón; la batería se ve más grande y clara.
- **Cerrar con `⌘Q`** muestra un aviso: cerrar faro, minimizar solo la vista de escritorio (faro sigue en la barra de menú) o cancelar. El botón de apagar del menú, el reinicio y el cierre de sesión no preguntan.
- Nuevo generador del logo (`scripts/make-logo.py`) que produce el SVG y el código Swift desde una sola fuente.

## [1.0.0] — 2026-10-23

Primera versión pública, con el nombre **faro**.

### Cambios
- La app pasa a llamarse **faro** (antes *Mirador* y, al principio, *Tapiz*) y estrena su símbolo: un faro dibujado a mano, que también vive en la barra de menú y se enciende con el modo despierto.
- Migra sola los datos, la caché y los ajustes de las versiones anteriores.
- Se publica bajo la licencia **AGPL-3.0-or-later**, con README completo, documentación de arquitectura, guía para contribuir, política de seguridad y código de conducta.
- Aviso legal visible en la página *General*, como pide la licencia.
- La versión de la app sale del archivo `VERSION`.

## [0.9] — Perfiles y diseño propio

- **Perfiles:** modos guardados que cambian fondos, despierto, barra de menú y descanso visual con un clic, con horario opcional.
- La página **Fondos** se simplifica: foto actual y canales como tarjetas; la edición pasa a una ventana aparte con niveles *Poco, Normal, Mucho*.
- Controles propios (desplegables, segmentos, interruptores, equis y más dibujados a mano) en toda la app.

## [0.8] — Panel del notch

- Panel que cuelga del notch con **música** (Música y Spotify), **clima**, **calendario** y **descanso visual**, con alas cuando hay algo en vivo.

## [0.7]

- Quita la ventana vacía "Settings" que macOS abría al lanzar la app; el arranque pasa a AppKit puro y se agrega un menú principal para que funcionen `⌘C`, `⌘V` y `⌘A` en los campos de texto.
- **Limpiar teclado** con un bloqueo básico que no necesita permisos.
- La ventana principal usa un color fijo.
- La app se firma con una identidad estable para que macOS conserve los permisos.

## [0.6] — Limpiar teclado

- Bloqueo del teclado (y opcionalmente del trackpad) con cuenta regresiva y salida de emergencia con `Esc` 3 segundos.
- La bandeja lee archivos soltados de cualquier tipo.

## [0.5] — Bandeja de archivos

- Panel flotante con arrastrar y soltar, soltar sobre el ícono de la barra y AirDrop.

## [0.4] — Cristal líquido y apariencia

- Menú propio con cristal líquido y esquinas redondas, y barra superior con ventana, portapapeles y salir.
- Color de resalte, tinte del cristal y color de la ventana configurables.

## [0.3] — Almacenamiento y portapapeles

- Análisis y limpieza de disco (categorías seguras, archivos grandes, explorador de carpetas).
- **Portapapeles** con historial de texto e imágenes, búsqueda, fijado y panel con `⌃⌥⌘V`.

## [0.2] — Ventana principal

- Ventana con barra lateral: Fondos, Sistema, Internet, Energía, Barra de menú y General.
- Medición de internet automática, mantener despierto y datos en vivo configurables en la barra de menú.

## [0.1] — Primer prototipo

- Cambio de fondo desde Wallhaven, Wikimedia y Bing con **canales mezclados**, caché mínima y atajos globales.
