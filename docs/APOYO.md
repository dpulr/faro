# Apoyo económico a faro

faro es gratis y libre. Esta guía deja listos dos canales para que quien quiera pueda ayudar a mantenerlo. Ko-fi y GitHub Sponsors están activos.

## GitHub Sponsors

1. El repositorio debe ser público (el botón *Sponsor* vive ahí) y la cuenta de GitHub, `dpulr`.
2. Entra a [github.com/sponsors](https://github.com/sponsors) y solicita el perfil. Colombia figura entre las [regiones admitidas](https://github.blog/changelog/2022-07-28-github-sponsors-available-in-30-new-regions), con cuenta bancaria colombiana.
3. GitHub pide los datos del titular, una cuenta bancaria (vía Stripe Connect) y el formulario fiscal que corresponda. Cobra una comisión (ver sus [condiciones](https://docs.github.com/en/sponsors/getting-started-with-github-sponsors/about-github-sponsors)).
4. Cuando GitHub apruebe el perfil, descomenta `github: dpulr` en [`.github/FUNDING.yml`](../.github/FUNDING.yml).

## Ko-fi

El perfil público está activo en [ko-fi.com/conectalab](https://ko-fi.com/conectalab), con aportes únicos y mensuales. El repositorio usa `ko_fi: conectalab` en `FUNDING.yml` y la web lo enlaza por defecto.

## Activar los enlaces del sitio

La sección «Apoya faro» y el enlace del pie se publican siempre, con Ko-fi y GitHub Sponsors activos. Estas variables permiten cambiar ese comportamiento:

```bash
# probar otra URL de Ko-fi
SITE_KOFI_URL=https://ko-fi.com/tu_usuario ./scripts/deploy-site.sh
# dejar GitHub Sponsors como «Próximamente»
SITE_SPONSORS=0 ./scripts/deploy-site.sh
# ocultar el bloque de Homebrew de la página de descarga
SITE_BREW=0 ./scripts/deploy-site.sh
```

Los textos están en `site/src/content.mjs` (`support`).

## Pendientes tuyos

- Confirmar con tu contador cómo declarar estos ingresos como persona natural.
- Decidir si faro anuncia el apoyo dentro de la app (hoy no lo hace).
