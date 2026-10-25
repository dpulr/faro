# Historial de cambios

Todos los cambios importantes de faro se anotan aquí. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones siguen [SemVer](https://semver.org/lang/es/).

## [2.0.0] — 2026-10-25

### Novedades
- **Puertos USB-C.** Diagnóstico lista los puertos USB-C y MagSafe, su capacidad, los transportes activos (USB, Thunderbolt y DisplayPort), si el cable es activo u óptico cuando macOS lo informa, y detecta humedad.
- **Diagnóstico.** Página nueva que dice qué frena a tu Mac (memoria, procesador, disco, temperatura, energía), analiza el cargador (cuántos vatios llegan al Mac y a la batería), lista los discos externos con botón para expulsarlos y muestra la velocidad de los ventiladores en solo lectura.
- **Alertas de conexión.** El notch avisa cuando se cae internet y cuando vuelve, si la VPN se desconecta, si la respuesta se vuelve lenta o si el Wi‑Fi se debilita. Un widget nuevo ("Conexión") aparece solo cuando hay algo que decir, y la página Internet muestra el estado y la latencia en vivo. Se puede apagar en Internet.
- **Escenas Faro.** Los perfiles ahora guardan la experiencia completa del notch y pueden activarse automáticamente por la aplicación al frente, un monitor externo, la fuente de energía o un horario.
- **Configuración en un minuto.** Un asistente prepara escenas recomendadas para Trabajo, Reunión, Multimedia, Escritorio y Minimal a partir de los ajustes actuales.
- **Historial, duplicado e intercambio.** Antes de aplicar una escena manual o programada, Faro conserva una restauración rápida. Las escenas también se pueden duplicar, exportar e importar como JSON.
- **Widgets contextuales.** El notch puede llevar temporalmente al frente lo que está ocurriendo —música, temporizador, calendario, dispositivos o alertas— sin alterar el orden guardado.
- **Acciones de escena.** Al entrar, una escena puede ajustar volumen, brillo de pantalla y teclado, silenciar o activar el micrófono, iniciar un enfoque, abrir aplicaciones y abrir un enlace. Al terminar un contexto automático, Faro restaura los controles anteriores.
- **Más contexto.** Las escenas también pueden reaccionar a una reunión próxima, una aplicación en pantalla completa, un dispositivo Bluetooth conectado o un nivel bajo de batería.
- **Automatización explicable.** Faro muestra por qué activó la última escena, permite pausar los cambios por una hora o hasta mañana y vuelve exactamente a la configuración anterior al salir del contexto.
- **Atajos.** Cada escena expone un enlace `faro://` que se puede usar desde la app Atajos de macOS.
- **Centro de comandos.** `⌃⌥⌘F` abre un buscador local para ejecutar escenas, abrir cualquier sección y controlar las herramientas de Faro sin recorrer menús. Admite teclado, favoritos y comandos recientes, y también se abre desde la barra de menú o el notch.
- **Baterías de periféricos al instante.** faro lee por IOKit la carga de teclados, ratones y trackpads (y si se están cargando) y se actualiza en cuanto macOS avisa de un cambio, sin sondear; se une con la lectura de AirPods y estuche. La página *Energía* muestra una tarjeta *Baterías de tus dispositivos* (los de menos carga primero) y el notch avisa, una vez por nivel, cuando un periférico baja del 20 % y del 10 %.
- **Almacenamiento más inteligente.** Un asistente ordena las recomendaciones por espacio recuperable y seguridad, con un botón *Limpiar lo seguro* (a la Papelera, con confirmación). Los archivos grandes muestran cuánto llevan sin abrirse ni modificarse y se filtran como *Olvidados*. faro anota el espacio libre cada día, predice cuándo se llenaría el disco y avisa si falta menos de dos semanas. El widget de almacenamiento del notch permite *Analizar* y *Limpiar* lo seguro desde el propio panel.

### Cambios
- La antigua sección *Perfiles* pasa a llamarse *Escenas* y permite elegir aplicaciones instaladas con un selector nativo.
- El acceso *Comandos* se incorpora automáticamente a configuraciones antiguas del dock del notch.

## [1.9.0] — 2026-10-25

### Novedades
- **Notch listo en segundos.** Cuatro plantillas predeterminadas —Minimal, Productividad, Multimedia y Centro de control— aplican un diseño completo con un solo clic.
- **Edición directa en la vista previa.** Los widgets se seleccionan, ordenan, ocultan y redimensionan dentro de una reproducción fiel del notch. El editor limita los tamaños a opciones útiles y deja los ajustes menos frecuentes en secciones avanzadas.
- **Pestaña Audio.** El notch detecta qué aplicaciones reproducen sonido y muestra controles para el volumen general, Música y Spotify. Chrome y las demás apps aparecen vinculadas al volumen general que expone macOS.
- **Mascota protagonista.** La página web y la documentación presentan sus expresiones, reacciones y opciones de personalización, con capturas reales de la app.

### Cambios
- La página Audio de escritorio explica con claridad qué controles son independientes y cuáles dependen del volumen general.
- La configuración del notch pasa de una lista larga de controles a un flujo breve de tres pasos: plantilla, vista previa y detalles opcionales.

## [1.8.0] — 2026-10-25

### Novedades
- **Mascota en el notch.** Un personaje pequeño, dibujado en vectores, que vive en la pastilla y en la cabecera del panel. Sigue el cursor con la mirada y reacciona: **baila** mientras suena música, **se pone azul** cuando se conecta un dispositivo Bluetooth, saca **corazones** si la tocas, hace **fiesta** cuando termina el temporizador y se pone **triste** con la batería baja.
- **Solo está activa cuando la usas:** despierta al acercar el cursor o abrir el notch y, tras 30 s sin tocarlo (configurable de 15 s a 2 min), se duerme. Dormida es una imagen fija: no se anima ni sigue el cursor.
- **Personalizable** en su propia página, *Mascota*, en la barra lateral: forma (gota, frijol, nube, cubo o sol), color (ocho colores o uno libre), ojos (ovalados, redondos, anchos, puntos o estrellas), accesorio (antena, moño o audífonos), cachetes, tiempo para dormir y y botones para probar cada reacción en la mascota real del notch.

## [1.7.0] — 2026-10-24

### Novedades
- **Notch reorganizable:** widgets (saludo, temporizador, música, controles del sistema, clima, calendario, dispositivos, descanso visual y almacenamiento) que se activan, se ordenan por prioridad y se redimensionan a 1/3, 2/3 o todo el ancho; pestañas Inicio, Sistema y Herramientas; dock de herramientas configurable (historial, bandeja, temporizador, micrófono, color, emoji, despierto, teclado y ajustes); estilos negro, teñido, cristal y liquid crystal; vista compacta con datos fijos y botones en las orillas; faro puede usarse solo desde el notch, sin ícono en la barra de menús.
- **Gráficos** (uso de la GPU) como dato para la barra de menú y el notch.
- **Cuidar la batería** (en *Energía*): preajuste «Proteger al 80%», aviso al nivel elegido, recordatorio si la Mac pasa horas enchufada con la batería casi llena e historial de salud día a día. faro avisa para desenchufar; no puede limitar la carga por sí mismo (si tu macOS lo incluye, el límite real está en Ajustes del Sistema → Batería).
- **Música:** un toque en la carátula o el título del widget abre la app desde la que suena.
- **Mac sin notch:** una isla flotante siempre visible arriba al centro, que se abre igual que el notch.
- **Instalador:** el `.dmg` lleva el ícono de faro.

### Arreglos
- Con la música en pausa, la carátula ya no se amontona junto a los botones de la pastilla.

## [1.6.0] — 2026-10-24

### Novedades
- **Letras sincronizadas** de lo que suena en Música o Spotify, con [LRCLIB](https://lrclib.net) (gratis, sin clave). La línea que suena cuelga bajo la pastilla del notch y, con el panel desplegado, se ven la actual y la siguiente. Se apagan en *Notch → Letras sincronizadas*. Consulta lrclib.net con el título y el artista de la canción; el resultado se recuerda mientras faro está abierto.

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
