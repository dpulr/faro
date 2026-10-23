# Política de seguridad

## Versiones con soporte

faro es un proyecto personal: solo se corrigen fallos de seguridad en la **versión más reciente** de la rama `main`.

| Versión | Soporte |
|---|---|
| 1.x (la última) | ✅ |
| Anteriores | ❌ |

## Cómo reportar una vulnerabilidad

**No abras un issue público.** Usa el reporte privado de GitHub:

1. Ve a la pestaña **Security** del repositorio.
2. Pulsa **Report a vulnerability**.
3. Describe el problema con el mayor detalle posible.

Incluye, si puedes:

- Qué versión de faro y de macOS usas.
- Los pasos para reproducirlo.
- Qué impacto crees que tiene (qué se podría leer, borrar o ejecutar).
- Una propuesta de solución, si la tienes.

## Qué esperar

- Una respuesta inicial en unos **7 días**.
- Un aviso cuando el fallo esté corregido, y reconocimiento en las notas de la versión si lo deseas.
- Pedimos que **no divulgues el fallo públicamente** hasta que exista una corrección.

## Qué puede hacer faro (alcance)

Para valorar el impacto de un reporte, esto es lo que la app puede hacer en tu Mac:

- **Archivos:** lee y borra solo dentro de una lista blanca de carpetas de caché y desarrollo (`Storage/Cleanup.swift`), y mueve archivos a la Papelera cuando tú lo pides. La bandeja guarda referencias, no copias.
- **Portapapeles:** guarda en tu disco lo que copias, salvo lo que los gestores de contraseñas marcan como secreto y las apps que excluyas.
- **Permisos opcionales:** Accesibilidad (bloqueo completo del teclado y pegado automático), Automatización (Finder, Música, Spotify) y Calendarios.
- **Red:** solo las conexiones listadas en el [README](README.md#qué-sale-de-tu-mac). No tiene telemetría ni servidor propio.

Son de especial interés los fallos que permitan **borrar archivos fuera de la lista blanca**, **leer el historial del portapapeles desde otra app** o **ejecutar código** a través de una fuente de imágenes.

## Recompensas

No hay un programa de recompensas económicas, pero se agradece y se reconoce el trabajo de quien ayuda a mejorar la seguridad de faro.
