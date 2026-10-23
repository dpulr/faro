# Cómo contribuir a faro

¡Gracias por querer mejorar faro! Este documento explica cómo preparar el proyecto, qué se espera de una contribución y cómo se revisa.

## Antes de empezar

- Busca primero en los [Issues](https://github.com/dpulr/faro/issues) para no duplicar una propuesta o un fallo.
- Para cambios grandes (una función nueva, un cambio de diseño), **abre un issue antes** de escribir código: así nos ponemos de acuerdo en la idea y no pierdes tiempo.
- Si encuentras una vulnerabilidad, **no abras un issue**: sigue [`SECURITY.md`](SECURITY.md).

## Preparar el entorno

Necesitas **Xcode 26 o posterior** (SDK de macOS 26) y un Mac con macOS 14 o superior.

```bash
git clone https://github.com/dpulr/faro.git
cd faro
swift build              # compila en modo debug
./scripts/build-app.sh   # compila en release, firma e instala faro.app en /Applications
```

Para ver la interfaz sin abrir la app, usa las herramientas de prueba descritas en el [README](README.md#herramientas-de-prueba) (`FARO_SNAPSHOT`, `FARO_DEBUG_SHOT`…).

## Qué se espera de una contribución

**Diseño** (son reglas del proyecto, no gustos):

- Sin tipografía con serifa.
- Sin controles genéricos del sistema (`Picker`, control segmentado, interruptor nativo): usa los de `UI/Controls.swift`.
- Botones redondos **sin texto**, con `.instantTip("…")` para decir qué hacen.
- Texto de la interfaz **en español y en lenguaje llano**, sin jerga técnica.
- Minimalista: si algo no aporta, no va.

**Código:**

- Swift con la forma del código que ya hay: mismos nombres, misma densidad de comentarios. Los comentarios explican el *porqué*, no el *qué*.
- Cada archivo nuevo empieza con el encabezado de licencia:
  ```swift
  // SPDX-License-Identifier: AGPL-3.0-or-later
  // Copyright (C) 2026 <tu nombre>
  ```
- Nada de dependencias externas sin discutirlo antes: faro hoy no depende de ninguna.
- Respeta la privacidad: nada de telemetría, y cualquier conexión de red nueva debe documentarse en el README (sección *Qué sale de tu Mac*).
- Las funciones que borran o mueven archivos del usuario deben pasar por la lista blanca de `Storage/Cleanup.swift` y pedir confirmación.

**Pruebas:** no hay una batería automática todavía. Describe en el pull request **cómo lo probaste**; si cambia la interfaz, adjunta una captura (puedes generarla con `FARO_SNAPSHOT`).

## Flujo de trabajo

1. Haz un *fork* y crea una rama desde `main` (`fix/…`, `feat/…`, `docs/…`).
2. Haz commits pequeños y con mensajes claros en español, en presente: `Agrega aviso de Bluetooth al notch`.
3. Compila con `swift build` y prueba tu cambio en la app real.
4. Abre el pull request y completa la plantilla.

## Licencia de las contribuciones

Al enviar una contribución aceptas que se publique bajo la licencia del proyecto, **AGPL-3.0-or-later**, y declaras que tienes derecho a hacerlo. No pedimos un acuerdo de cesión (CLA); basta con tu aceptación en el pull request.

No copies código de otros proyectos con licencias incompatibles. En particular, faro se inspira en otras apps (ver [`CREDITS.md`](CREDITS.md)) pero **no contiene código de ellas**, y así debe seguir.

## Código de conducta

Al participar aceptas el [código de conducta](CODE_OF_CONDUCT.md).
