# Apoyo económico a faro

faro es gratis y libre. Esta guía deja listos dos canales para que quien quiera pueda ayudar a mantenerlo. Mientras no estén activos, la web mantiene ambos espacios visibles como «Próximamente».

## GitHub Sponsors

1. El repositorio debe ser público (el botón *Sponsor* vive ahí) y la cuenta de GitHub, `dpulr`.
2. Entra a [github.com/sponsors](https://github.com/sponsors) y solicita el perfil. Colombia figura entre las [regiones admitidas](https://github.blog/changelog/2022-07-28-github-sponsors-available-in-30-new-regions), con cuenta bancaria colombiana.
3. GitHub pide los datos del titular, una cuenta bancaria (vía Stripe Connect) y el formulario fiscal que corresponda. Cobra una comisión (ver sus [condiciones](https://docs.github.com/en/sponsors/getting-started-with-github-sponsors/about-github-sponsors)).
4. Cuando GitHub apruebe el perfil, descomenta `github: dpulr` en [`.github/FUNDING.yml`](../.github/FUNDING.yml).

## Ko-fi

1. Crea la cuenta en [ko-fi.com](https://ko-fi.com) y elige el usuario (por ejemplo `faro`).
2. Conecta el método de cobro que Ko-fi ofrezca para tu país (PayPal o Stripe). Confirma en su ayuda que cubre Colombia antes de anunciarlo.
3. Descomenta `ko_fi: tu_usuario` en `FUNDING.yml`.

## Activar los enlaces del sitio

La sección «Apoya faro» y el enlace del pie se publican siempre. Estas variables convierten las tarjetas de espera en enlaces activos:

```bash
# solo GitHub Sponsors
SITE_SPONSORS=1 ./scripts/deploy-site.sh
# solo Ko-fi
SITE_KOFI_URL=https://ko-fi.com/tu_usuario ./scripts/deploy-site.sh
# los dos
SITE_SPONSORS=1 SITE_KOFI_URL=https://ko-fi.com/tu_usuario ./scripts/deploy-site.sh
```

Si publicas sin esas variables, aparecen las tarjetas de GitHub Sponsors y Ko-fi con la etiqueta «Próximamente». Los textos están en `site/src/content.mjs` (`support`).

## Pendientes tuyos

- Confirmar con tu contador cómo declarar estos ingresos como persona natural.
- Decidir si faro anuncia el apoyo dentro de la app (hoy no lo hace).
