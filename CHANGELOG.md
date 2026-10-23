# Historial de cambios

Todos los cambios importantes de faro se anotan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones siguen [SemVer](https://semver.org/lang/es/).

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
