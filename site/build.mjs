// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín
// Genera el sitio estático de faro en site/dist (español en la raíz, inglés en /en). Sin dependencias: `node build.mjs`.
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { features, more, network, privacy, releaseNotes, support, timeline, ui } from './src/content.mjs'

const root = dirname(fileURLToPath(import.meta.url))
const dist = join(root, 'dist')
// SITE_URL permite publicar con otra dirección mientras el dominio propio no esté conectado.
const SITE = process.env.SITE_URL || 'https://faro.conectalab.co'
const REPO = 'https://github.com/dpulr/faro'
const REPO_PUBLIC = process.env.SITE_REPO_PUBLIC === '1'
// Apoyo económico: se activa al publicar con SITE_SPONSORS=1 (GitHub Sponsors) y/o SITE_KOFI_URL=https://ko-fi.com/tu_usuario.
const SPONSORS_URL = process.env.SITE_SPONSORS === '1' ? 'https://github.com/sponsors/dpulr' : ''
const KOFI_URL = process.env.SITE_KOFI_URL || ''
const SUPPORT = Boolean(SPONSORS_URL || KOFI_URL)
const version = readFileSync(join(root, '../VERSION'), 'utf8').trim()

// Descarga: se publica el .dmg que dejó scripts/release.sh, si existe.
const dmgSource = join(root, `../build/faro-${version}.dmg`)
const download = { available: existsSync(dmgSource) && process.env.SITE_NO_DMG !== '1', file: `faro-${version}.dmg` }
if (download.available) {
  const stat = statSync(dmgSource)
  download.size = `${(stat.size / 1048576).toFixed(1)} MB`
  download.date = stat.mtime.toISOString().slice(0, 10)
  const shaFile = `${dmgSource}.sha256`
  download.sha = existsSync(shaFile) ? readFileSync(shaFile, 'utf8').split(/\s+/)[0] : ''
}

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
const img = (name, alt, extra = '') => `<img src="/img/${name}" alt="${esc(alt)}" loading="lazy" decoding="async"${extra}>`

const icons = {
  arrow: '<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true"><path d="M3 8h9M8.5 4l4 4-4 4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  down: '<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true"><path d="M8 2.5v8M4.5 7.5 8 11l3.5-3.5M3 13.5h10" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  sun: '<svg viewBox="0 0 20 20" width="18" height="18" aria-hidden="true"><circle cx="10" cy="10" r="3.6" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M10 2.5v2M10 15.5v2M2.5 10h2M15.5 10h2M4.7 4.7l1.4 1.4M13.9 13.9l1.4 1.4M4.7 15.3l1.4-1.4M13.9 6.1l1.4-1.4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>',
  code: '<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true"><path d="m5.5 4.5-3.5 3.5 3.5 3.5M10.5 4.5l3.5 3.5-3.5 3.5" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
}

const pageUrl = (lang, key) => SITE + (key === 'home' ? ui[lang].path.home.replace(/\/$/, '') || '/' : ui[lang].path[key])

function head(lang, key, meta) {
  const t = ui[lang]
  const url = pageUrl(lang, key)
  const alt = lang === 'es' ? 'en' : 'es'
  const ld = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: 'faro',
    applicationCategory: 'UtilitiesApplication',
    operatingSystem: 'macOS 14+',
    softwareVersion: version,
    license: 'https://www.gnu.org/licenses/agpl-3.0.html',
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
    description: ui[lang].home.description,
    publisher: { '@type': 'Organization', name: 'Conecta Lab', url: 'https://conectalab.co' },
  }
  return `<!doctype html>
<html lang="${t.htmlLang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(meta.title)}</title>
<meta name="description" content="${esc(meta.description)}">
<link rel="canonical" href="${url}">
<link rel="alternate" hreflang="${lang}" href="${url}">
<link rel="alternate" hreflang="${alt}" href="${pageUrl(alt, key)}">
<link rel="alternate" hreflang="x-default" href="${pageUrl('es', key)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="faro">
<meta property="og:title" content="${esc(meta.title)}">
<meta property="og:description" content="${esc(meta.description)}">
<meta property="og:url" content="${url}">
<meta property="og:image" content="${SITE}/img/fondos.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#0d1217">
<link rel="icon" type="image/svg+xml" href="/img/logo.svg">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="preload" href="/fonts/manrope-latin-wght-normal.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/fonts/space-grotesk-latin-wght-normal.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/style.css">
<script>document.documentElement.classList.add('js');try{var t=localStorage.getItem('faro-theme');if(t)document.documentElement.dataset.theme=t}catch(e){}</script>
<script type="application/ld+json">${JSON.stringify(ld)}</script>
</head>`
}

function header(lang, key) {
  const t = ui[lang]
  const home = t.path.home
  const alt = lang === 'es' ? 'en' : 'es'
  const altPath = ui[alt].path[key]
  const a = (id) => (key === 'home' ? `#${id}` : `${home}#${id}`)
  return `<body>
<a class="skip" href="#main">${lang === 'es' ? 'Saltar al contenido' : 'Skip to content'}</a>
<header class="top">
  <a class="brand" href="${home}" aria-label="faro"><img src="/img/logo.svg" alt="" width="34" height="34"><span>faro</span></a>
  <nav class="nav" aria-label="${lang === 'es' ? 'Principal' : 'Main'}">
    <a href="${a('funciones')}">${t.nav.features}</a>
    <a href="${a('como-funciona')}">${t.nav.how}</a>
    <a href="${a('privacidad')}">${t.nav.privacy}</a>
    <a href="${a('desarrollo')}">${t.nav.build}</a>
  </nav>
  <div class="top__tools">
    <a class="chip" href="${altPath}" hreflang="${alt}" lang="${alt}">${t.other}</a>
    <button class="chip chip--icon" type="button" data-theme-toggle aria-label="${t.theme}">${icons.sun}</button>
    <a class="btn btn--small" href="${t.path.download}">${t.nav.download}</a>
  </div>
</header>
<main id="main">`
}

function footer(lang) {
  const t = ui[lang]
  return `</main>
<footer class="foot">
  <div class="foot__inner">
    <div class="foot__brand">
      <img src="/img/logo.svg" alt="" width="40" height="40">
      <div><strong>faro</strong><p>${t.home.sub.split('.')[0]}.</p></div>
    </div>
    <div class="foot__links">
      <a href="${t.path.home}">${lang === 'es' ? 'Inicio' : 'Home'}</a>
      <a href="${t.path.download}">${t.nav.download}</a>
      ${REPO_PUBLIC ? `<a href="${REPO}">GitHub</a>` : ''}
      ${SUPPORT ? `<a href="${t.path.home}#apoyo">${support[lang].footer}</a>` : ''}
      <a href="${t.path.privacy}">${t.footer.privacy}</a>
      <a href="https://conectalab.co/${lang === 'es' ? 'contacto' : 'en/contact'}">${t.footer.contact}</a>
    </div>
    <div class="foot__by">
      <span>${t.footer.by}</span>
      <a href="https://conectalab.co${lang === 'en' ? '/en' : ''}" aria-label="Conecta Lab"><img src="/img/conectalab-mark.svg" alt="" width="22" height="22"> Conecta Lab</a>
    </div>
  </div>
  <p class="foot__legal">${t.footer.rights} · ${t.footer.license}</p>
</footer>
<script src="/app.js" defer></script>
</body>
</html>`
}

function downloadButton(lang, cls = '') {
  const t = ui[lang]
  return `<a class="btn ${cls}" href="${t.path.download}">${icons.down}<span>${t.home.cta}</span></a>`
}

function home(lang) {
  const t = ui[lang]
  const h = t.home
  const codeLink = REPO_PUBLIC
    ? `<a class="btn btn--ghost" href="${REPO}">${icons.code}<span>${h.code}</span></a>`
    : `<span class="btn btn--ghost btn--off" aria-disabled="true">${icons.code}<span>${h.codeSoon}</span></span>`

  const featureBlocks = features[lang].map((f, i) => `
  <article class="feature${i % 2 ? ' feature--flip' : ''}" id="${f.id}">
    <div class="feature__text reveal">
      <h3>${f.title}</h3>
      <p class="feature__lead">${f.lead}</p>
      <ul>${f.points.map((p) => `<li>${p}</li>`).join('')}</ul>
    </div>
    <div class="feature__shot reveal">
      <div class="shot">${img(f.img, f.alt)}</div>
      ${f.extra ? `<div class="shot-row">${f.extra.map((e) => `<div class="shot shot--small">${img(e, '')}</div>`).join('')}</div>` : ''}
    </div>
  </article>`).join('')

  const moreCards = more[lang].map(([title, text]) => `<div class="card reveal"><h4>${title}</h4><p>${text}</p></div>`).join('')
  const steps = h.steps.map(([title, text], i) => `<li class="step reveal"><span class="step__n">${i + 1}</span><div><h4>${title}</h4><p>${text}</p></div></li>`).join('')
  const rows = network.map(([host, why, what]) => `<tr><td data-label="${h.netHead[0]}"><code>${host}</code></td><td data-label="${h.netHead[1]}">${why[lang]}</td><td data-label="${h.netHead[2]}">${what[lang]}</td></tr>`).join('')
  const points = h.buildPoints.map(([title, text]) => `<div class="card reveal"><h4>${title}</h4><p>${text}</p></div>`).join('')
  const tl = timeline[lang].map(([v, text]) => `<li><span class="tl__v">${v}</span><span>${text}</span></li>`).join('')

  return `${head(lang, 'home', { title: h.title, description: h.description })}
${header(lang, 'home')}
<section class="hero">
  <div class="hero__beam" aria-hidden="true"></div>
  <div class="hero__text">
    <p class="kicker">${h.kicker}</p>
    <h1>${h.h1a}<br><span>${h.h1b}</span></h1>
    <p class="hero__sub">${h.sub}</p>
    <div class="hero__cta">
      ${downloadButton(lang)}
      ${codeLink}
    </div>
    <p class="hero__note">${h.ctaNote(version)}</p>
  </div>
  <div class="hero__art">
    <div class="hero__window">${img('fondos.png', lang === 'es' ? 'La ventana de faro con la página Fondos' : 'The faro window showing the Wallpapers page', ' fetchpriority="high" loading="eager"')}</div>
    <div class="hero__menu">${img('menu.png', lang === 'es' ? 'El menú de faro en la barra de menú' : 'The faro menu from the menu bar', ' loading="eager"')}</div>
  </div>
</section>

<ul class="facts" aria-label="faro">${h.facts.map((f) => `<li>${f}</li>`).join('')}</ul>

<section class="section" id="funciones">
  <div class="wrap">
    <h2 class="reveal">${h.featuresTitle}</h2>
    ${featureBlocks}
  </div>
</section>

<section class="section section--tint">
  <div class="wrap">
    <h2 class="reveal">${h.moreTitle}</h2>
    <div class="grid">${moreCards}</div>
  </div>
</section>

<section class="section" id="como-funciona">
  <div class="wrap wrap--narrow">
    <h2 class="reveal">${h.howTitle}</h2>
    <p class="lead reveal">${h.howLead}</p>
    <ol class="steps">${steps}</ol>
  </div>
</section>

<section class="section section--tint" id="privacidad">
  <div class="wrap wrap--narrow">
    <h2 class="reveal">${h.privacyTitle}</h2>
    <p class="lead reveal">${h.privacyLead}</p>
    <div class="table-wrap reveal">
      <table>
        <thead><tr>${h.netHead.map((c) => `<th>${c}</th>`).join('')}</tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
    <p class="muted reveal">${h.privacyFoot}</p>
  </div>
</section>

<section class="section" id="desarrollo">
  <div class="wrap">
    <h2 class="reveal">${h.buildTitle}</h2>
    <p class="lead reveal">${h.buildLead}</p>
    <div class="grid grid--4">${points}</div>
    <h3 class="reveal tl__title">${h.timelineTitle}</h3>
    <ol class="tl reveal">${tl}</ol>
  </div>
</section>

<section class="section section--tint">
  <div class="wrap wrap--narrow open">
    <h2 class="reveal">${h.openTitle}</h2>
    <p class="lead reveal">${h.openLead}</p>
    ${REPO_PUBLIC ? `<p class="reveal"><a class="btn btn--ghost" href="${REPO}">${icons.code}<span>${h.openRepo}</span></a></p>` : `<p class="muted reveal">${h.openSoon}</p>`}
  </div>
</section>

${SUPPORT ? supportSection(lang) : ''}
<section class="final">
  <div class="wrap wrap--narrow">
    <img src="/img/logo.svg" alt="" width="72" height="72">
    <h2>${h.finalTitle}</h2>
    ${downloadButton(lang)}
    <p class="hero__note">${h.ctaNote(version)}</p>
  </div>
</section>
${footer(lang)}`
}

function supportSection(lang) {
  const s = support[lang]
  return `<section class="section" id="apoyo">
  <div class="wrap wrap--narrow support">
    <h2 class="reveal">${s.title}</h2>
    <p class="lead reveal">${s.lead}</p>
    <div class="support__buttons reveal">
      ${SPONSORS_URL ? `<a class="btn" href="${SPONSORS_URL}" rel="noopener">${s.github}</a>` : ''}
      ${KOFI_URL ? `<a class="btn btn--ghost" href="${KOFI_URL}" rel="noopener">${s.kofi}</a>` : ''}
    </div>
    <p class="muted reveal">${s.note}</p>
  </div>
</section>`
}

function downloadPage(lang) {
  const t = ui[lang]
  const d = t.download
  const button = download.available
    ? `<a class="btn btn--big" href="/download/faro.dmg" download="${download.file}">${icons.down}<span>${d.button}</span></a>`
    : `<span class="btn btn--big btn--off" aria-disabled="true">${icons.down}<span>${d.button}</span></span><p class="muted">${d.unavailable}</p>`
  const sha = download.available && download.sha
    ? `<h3>${d.verifyTitle}</h3>
       <p>${d.verifyLead}</p>
       <pre class="code"><code>${download.sha}</code></pre>
       <p>${d.verifyCmd}</p>
       <pre class="code"><code>shasum -a 256 ~/Downloads/${download.file}</code></pre>`
    : ''
  const source = REPO_PUBLIC
    ? `<pre class="code"><code>git clone ${REPO}.git
cd faro
./scripts/build-app.sh</code></pre>`
    : `<p class="muted">${d.sourceSoon}</p>`
  return `${head(lang, 'download', { title: d.title, description: d.description })}
${header(lang, 'download')}
<section class="dl">
  <div class="wrap wrap--narrow">
    <img class="dl__icon" src="/img/icon.png" alt="" width="112" height="112">
    <h1>${d.h1}</h1>
    <p class="lead">${d.sub}</p>
    <div class="dl__cta">${button}</div>
    ${download.available ? `<p class="hero__note">${d.meta(version, download.size, download.date)}</p>` : `<p class="hero__note">${t.home.ctaNote(version)}</p>`}
  </div>
</section>
<section class="section section--tint dl__body">
  <div class="wrap wrap--narrow prose">
    <h3>${d.reqTitle}</h3>
    <ul>${d.req.map((r) => `<li>${r}</li>`).join('')}</ul>
    <h3>${d.installTitle}</h3>
    <ol>${d.install.map((r) => `<li>${r}</li>`).join('')}</ol>
    <h3>${d.permsTitle}</h3>
    <p>${d.perms}</p>
    ${sha}
    <h3>${d.sourceTitle}</h3>
    <p>${d.sourceLead}</p>
    ${source}
    <h3>${d.uninstallTitle}</h3>
    <p>${d.uninstall}</p>
    <p><a class="link" href="${t.path.home}">${icons.arrow} ${d.back}</a></p>
  </div>
</section>
${footer(lang)}`
}

function privacyPage(lang) {
  const p = privacy[lang]
  const body = p.sections.map(([title, items]) => `<h3>${title}</h3><ul>${items.map((i) => `<li>${i}</li>`).join('')}</ul>`).join('')
  return `${head(lang, 'privacy', { title: p.title, description: p.description })}
${header(lang, 'privacy')}
<section class="dl dl--left">
  <div class="wrap wrap--narrow">
    <h1>${p.h1}</h1>
    <p class="lead">${p.intro}</p>
    <p class="hero__note">${p.updated}</p>
  </div>
</section>
<section class="section section--tint dl__body">
  <div class="wrap wrap--narrow prose">
    ${body}
    <p><a class="link" href="${p.contactUrl}">${icons.arrow} ${p.contact}</a></p>
  </div>
</section>
${footer(lang)}`
}

function notFound() {
  return `${head('es', 'home', { title: 'No encontrado · faro', description: ui.es.home.description }).replace('<head>', '<head>\n<meta name="robots" content="noindex">')}
${header('es', 'home')}
<section class="dl"><div class="wrap wrap--narrow"><h1>404</h1><p class="lead">Esta página no existe. / This page doesn’t exist.</p>
<p><a class="btn" href="/">faro</a> <a class="btn btn--ghost" href="/en/">English</a></p></div></section>
${footer('es')}`
}

function write(path, html) {
  const file = join(dist, path)
  mkdirSync(dirname(file), { recursive: true })
  writeFileSync(file, html)
}

rmSync(dist, { recursive: true, force: true })
cpSync(join(root, 'public'), dist, { recursive: true })
cpSync(join(root, 'src/style.css'), join(dist, 'style.css'))
cpSync(join(root, 'src/app.js'), join(dist, 'app.js'))

write('index.html', home('es'))
write('en/index.html', home('en'))
write('descargar/index.html', downloadPage('es'))
write('en/download/index.html', downloadPage('en'))
write('privacidad/index.html', privacyPage('es'))
write('en/privacy/index.html', privacyPage('en'))
write('404.html', notFound())

mkdirSync(join(dist, 'download'), { recursive: true })
if (download.available) {
  cpSync(dmgSource, join(dist, 'download', download.file))
  cpSync(dmgSource, join(dist, 'download', 'faro.dmg'))
}
// latest.json lo consulta la app para avisar de versiones nuevas (no es ejecutable: Spark lo admite).
writeFileSync(join(dist, 'download', 'latest.json'), JSON.stringify({
  version,
  date: new Date().toISOString().slice(0, 10),
  page: { es: pageUrl('es', 'download'), en: pageUrl('en', 'download') },
  notes: releaseNotes,
  ...(download.available ? { file: download.file, size: download.size, sha256: download.sha } : {}),
}, null, 2) + '\n')

const urls = ['es', 'en'].flatMap((l) => ['home', 'download', 'privacy'].map((k) => pageUrl(l, k)))
write('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map((u) => `  <url><loc>${u}</loc></url>`).join('\n')}\n</urlset>\n`)
write('robots.txt', `User-agent: *\nAllow: /\nSitemap: ${SITE}/sitemap.xml\n`)

console.log(`faro site ${version}: ${urls.length} páginas${download.available ? `, descarga ${download.file} (${download.size})` : ', sin .dmg (ejecuta scripts/release.sh)'}`)
