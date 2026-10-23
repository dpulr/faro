# Arquitectura de faro

Este documento explica cómo está organizado el código y **por qué** se tomaron las decisiones principales. Para qué hace cada función, mira el [README](../README.md).

## Visión general

faro es una app de AppKit con interfaz en SwiftUI. No usa el ciclo de vida `App` de SwiftUI: arranca desde `main.swift`, y un único objeto, **`AppController`**, es dueño de todo lo que vive fuera de una ventana.

```
main.swift ─► AppDelegate ─► AppController
                              ├── NSStatusItem (ícono dibujado con ImageRenderer)
                              ├── Panel del menú (NSPanel + SwiftUI, cristal líquido)
                              ├── Ventana principal (NSWindow + SwiftUI)
                              ├── WallpaperEngine   fondos, historial, atajos, estado persistente
                              ├── SystemMonitor     procesador, memoria, disco, red, batería
                              ├── SpeedTest         networkQuality + historial
                              ├── KeepAwake         aserción de energía
                              ├── StorageModel      análisis y limpieza de disco
                              ├── ClipboardStore    historial del portapapeles
                              ├── ShelfStore        bandeja de archivos
                              ├── CleaningMode      bloqueo del teclado
                              └── NotchModel        música, calendario, clima, descanso visual
```

Cada modelo es un `ObservableObject` aislado en `@MainActor`. Las páginas reciben lo que necesitan por `environmentObject`.

### Por qué no `MenuBarExtra` ni escenas de SwiftUI

- `MenuBarExtra` no deja controlar la forma de la ventana ni el cristal, y descarta el diseño de la etiqueta cuando contiene formas.
- Una escena de ajustes vacía hacía que macOS abriera una ventana "Settings" en cada lanzamiento.

Por eso el ícono (`NSStatusItem`), el menú (`NSPanel`) y la ventana principal (`NSWindow`) se crean a mano, y SwiftUI se usa solo dentro de ellos.

## Estado y datos

| Pieza | Formato | Detalle |
|---|---|---|
| `AppState` | `state.json` | Canales, perfiles, historial, ajustes. La decodificación es **tolerante** (`decodeIfPresent`) para que un archivo viejo siga cargando al agregar campos. |
| `ClipboardStore` | `clipboard.json` + `clips/` | Texto en JSON, imágenes como PNG; guardado con retraso de 0,8 s. |
| `ShelfStore` | `shelf.json` | Rutas más *bookmarks*, para seguir un archivo que se mueva. |
| `SpeedTest` | `speed.json` | Historial de mediciones. |
| Apariencia, notch, limpieza | `UserDefaults` | Claves simples. |

> **Lección aprendida:** las fechas deben usar la misma estrategia (`.iso8601`) al escribir **y** al leer. Una vez no coincidieron y la app arrancaba de cero en cada apertura sin dar ningún error.

`LegacyMigration` y `Paths.migrate` mueven datos y ajustes desde los nombres anteriores del proyecto (Tapiz, Mirador) una sola vez.

## Fondos

1. `WallpaperEngine.pick()` sortea una fuente según los pesos. Una **mezcla de canales** se aplana primero (`effectiveSources`) a una lista de fuentes con pesos combinados.
2. Cada fuente implementa `ImageSource` y devuelve un lote de candidatos; el motor guarda un *pool* por fuente para que el reparto sea exacto.
3. Se filtra por resolución, orientación, fotos ocultas y recientes.
4. `Net.download` baja la imagen, `Imaging.prepare` la **reduce a la resolución de la pantalla** y se aplica con `NSWorkspace.setDesktopImageURL`.
5. El archivo anterior se borra después de poner el nuevo: la caché guarda **un archivo por monitor**.

Para agregar una fuente: implementa `ImageSource`, agrega un caso a `SourceKind` y regístralo en `Sources.make`.

## Interfaz

- **Tema y controles:** `UI/Theme.swift` (colores, tarjetas, estilos de botón) y `UI/Controls.swift` (desplegable, segmentos, interruptor, marcas dibujadas a mano).
- **Logo:** la geometría vive en `scripts/make-logo.py`, que escribe el SVG (`docs/images/logo.svg`) y `UI/FaroLogoData.swift`; `UI/FaroLogo.swift` lee esos trazos y los dibuja con `Canvas`, a color o de una sola tinta (la barra de menú, donde un trazo extra engrosa los detalles finos).
- **Color de resalte dinámico:** `Theme.accent` lee de `Appearance`. `.tint` **no** cambia `Color.accentColor` en macOS, así que las ventanas raíz se reconstruyen con `.id(appearance.revision)` cuando el color cambia.
- **Cristal líquido:** `UI/Glass.swift` usa `glassEffect` en macOS 26 y un material translúcido antes.
- **`Menu` vs. `Dropdown`:** el `Menu` del sistema descarta las formas de su etiqueta, por eso las páginas usan `Dropdown` (un *popover* propio). Dentro del panel del menú de la barra se mantiene `Menu`, porque un *popover* le quitaría el foco y lo cerraría.
- **Ayuda instantánea:** `.instantTip` muestra la etiqueta al pasar el cursor, sin la espera de la ayuda nativa.

## Paneles flotantes

Menú, portapapeles, bandeja, notch y pantalla de limpieza son `NSPanel` sin bordes (`FloatingPanel`), con `nonactivatingPanel` para que la app que tenías al frente siga activa.

- El **menú** y el **portapapeles** se cierran al perder el foco; la **bandeja** no, para poder arrastrar hacia otras apps.
- El **notch** vive siempre en pantalla pero ignora el ratón mientras está recogido; un temporizador de 0,1 s mira si el cursor entra en su zona.
- Las esquinas redondeadas se logran recortando la vista (`cornerRadius` + `masksToBounds`) y llamando a `invalidateShadow()`; sin eso, macOS dibuja una sombra rectangular.

## Limpiar teclado

Dos modos:

- **Básico** (sin permisos): faro se activa, muestra una pantalla encima de todo, descarta teclas con un `NSEvent.addLocalMonitorForEvents` y activa el modo quiosco (`presentationOptions`).
- **Completo**: un `CGEventTap` de sesión que retiene las teclas del sistema también. Requiere Accesibilidad.

En ambos, mantener `Esc` 3 segundos y la cuenta regresiva liberan el teclado.

## Seguridad de la limpieza

`Safety.allows` solo permite borrar **dentro de las carpetas del catálogo** (`CleanupCatalog`) o un archivo suelto que el usuario eligió. Se valida la ruta estandarizada, así que `..` no sirve para salirse. Por defecto todo va a la Papelera.

## Salir de la app

`applicationShouldTerminate` pregunta antes de cerrar (cerrar, minimizar la vista de escritorio o cancelar). Salir por el botón de apagar, un reinicio o el cierre de sesión (`willPowerOffNotification`) activa `forceQuit` y no pregunta, para no bloquear el apagado del Mac.

## Firma y permisos

macOS liga los permisos (Accesibilidad, Automatización, Calendarios) a la **firma** de la app. Con firma *ad hoc* cada compilación cambia la firma y los permisos se pierden; por eso `scripts/build-app.sh` firma con la identidad de Apple Development si existe.

## Herramientas de prueba

`Snapshot` dibuja las pantallas fuera de pantalla; `AppController.debugCapture` abre las ventanas de verdad y las captura con `CGWindowListCreateImage` (resuelta con `dlsym`, porque está marcada como obsoleta). Las pruebas también ejercitan el motor: perfiles, horarios, bandeja, bloqueo básico y despliegue del notch.
