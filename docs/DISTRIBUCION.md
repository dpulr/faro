# Distribuir faro

Cómo generar un `.dmg` que cualquiera pueda abrir sin avisos de seguridad. Necesitas una cuenta de pago del **Apple Developer Program**.

## Una sola vez

1. **Certificado Developer ID Application.** En Xcode: *Settings → Accounts →* tu equipo *→ Manage Certificates → + → Developer ID Application* (lo puede crear el titular de la cuenta). Comprueba que aparece:

   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

   Los certificados *Apple Development* y *Apple Distribution* no sirven: el primero es solo para tu Mac y el segundo es para la App Store.

2. **Credenciales de notarización.** Crea una contraseña de aplicación en [account.apple.com](https://account.apple.com) (*Inicio de sesión y seguridad → Contraseñas de apps*) y guárdala en el llavero:

   ```bash
   xcrun notarytool store-credentials faro --apple-id TU_CORREO --team-id TU_TEAM_ID
   ```

   Te pedirá la contraseña de aplicación. El nombre `faro` es el que usa el script (cámbialo con `NOTARY_PROFILE`).

## Cada versión

```bash
./scripts/release.sh
```

El script compila un binario **universal** (Apple Silicon e Intel), firma con Developer ID con *hardened runtime* y los permisos de [`scripts/faro.entitlements`](../scripts/faro.entitlements) (Automatización, Calendarios y Bluetooth), crea `build/faro-<versión>.dmg`, lo envía a notarizar, espera el resultado, le grapa el ticket y deja un `.sha256` al lado. Con `SKIP_NOTARIZE=1` se salta la notarización (útil para probar el empaquetado).

Después, sube el `.dmg` como *Release* de GitHub con la etiqueta `v<versión>` y el texto del `CHANGELOG.md`.

## Notas

- La app **no usa el sandbox**: lee otras carpetas (limpieza), controla Finder, Música y Spotify con AppleScript y bloquea el teclado con un *event tap*. Por eso no es apta para la Mac App Store.
- Los permisos de macOS (Accesibilidad, Bluetooth, Calendarios, Notificaciones) se piden la primera vez que se usa cada función. Con la firma Developer ID se conservan entre versiones.
- Para repartir una versión sin cuenta de pago, quien la reciba debe abrirla con clic derecho → *Abrir*, o ejecutar `xattr -dr com.apple.quarantine /Applications/faro.app`. No es recomendable para publicar.
