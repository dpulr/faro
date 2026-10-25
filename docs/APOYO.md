# Apoyo económico a faro

faro es gratis y libre. Esta guía deja listos dos canales para que quien quiera pueda ayudar a mantenerlo. Ko-fi está activo; GitHub Sponsors permanece visible como «Próximamente» hasta que GitHub apruebe el perfil.

## GitHub Sponsors

1. El repositorio debe ser público (el botón *Sponsor* vive ahí) y la cuenta de GitHub, `dpulr`.
2. Entra a [github.com/sponsors](https://github.com/sponsors) y solicita el perfil. Colombia figura entre las [regiones admitidas](https://github.blog/changelog/2022-07-28-github-sponsors-available-in-30-new-regions), con cuenta bancaria colombiana.
3. GitHub pide los datos del titular, una cuenta bancaria (vía Stripe Connect) y el formulario fiscal que corresponda. Cobra una comisión (ver sus [condiciones](https://docs.github.com/en/sponsors/getting-started-with-github-sponsors/about-github-sponsors)).
4. Cuando GitHub apruebe el perfil, descomenta `github: dpulr` en [`.github/FUNDING.yml`](../.github/FUNDING.yml).

## Ko-fi

El perfil público está activo en [ko-fi.com/conectalab](https://ko-fi.com/conectalab), con aportes únicos y mensuales. El repositorio usa `ko_fi: conectalab` en `FUNDING.yml` y la web lo enlaza por defecto.

## Activar los enlaces del sitio

La sección «Apoya faro» y el enlace del pie se publican siempre. Ko-fi queda activo en todos los despliegues normales. Estas variables permiten probar otra URL o activar GitHub Sponsors cuando esté aprobado:

```bash
# solo GitHub Sponsors
SITE_SPONSORS=1 ./scripts/deploy-site.sh
# probar otra URL de Ko-fi
SITE_KOFI_URL=https://ko-fi.com/tu_usuario ./scripts/deploy-site.sh
# los dos
SITE_SPONSORS=1 SITE_KOFI_URL=https://ko-fi.com/tu_usuario ./scripts/deploy-site.sh
```

Si publicas sin variables, Ko-fi enlaza a Conecta Lab y GitHub Sponsors conserva la etiqueta «Próximamente». Los textos están en `site/src/content.mjs` (`support`).

## Pendientes tuyos

- Confirmar con tu contador cómo declarar estos ingresos como persona natural.
- Decidir si faro anuncia el apoyo dentro de la app (hoy no lo hace).
