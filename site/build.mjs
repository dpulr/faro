// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín
// Genera el sitio estático de faro en site/dist (español en la raíz, inglés en /en). Sin dependencias: `node build.mjs`.
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { demo, features, more, network, privacy, releaseNotes, support, timeline, ui } from './src/content.mjs'
import { icon, lucide } from './src/icons.mjs'

const root = dirname(fileURLToPath(import.meta.url))
const dist = join(root, 'dist')
// SITE_URL permite publicar con otra dirección mientras el dominio propio no esté conectado.
const SITE = process.env.SITE_URL || 'https://faro.conectalab.co'
const REPO = 'https://github.com/dpulr/faro'
const REPO_PUBLIC = process.env.SITE_REPO_PUBLIC !== '0'
// Los espacios de apoyo se muestran como "próximamente" hasta que se configure cada enlace.
const SPONSORS_URL = process.env.SITE_SPONSORS === '1' ? 'https://github.com/sponsors/dpulr' : ''
const KOFI_URL = process.env.SITE_KOFI_URL || ''
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
const img = (name, alt, extra = '') => `<img src="/img/${name}" alt="${esc(alt)}"${extra.includes('loading=') ? '' : ' loading="lazy"'} decoding="async"${extra}>`

const brand = {
  github: '<svg viewBox="0 0 24 24" width="26" height="26" aria-hidden="true"><path fill="currentColor" d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>',
  kofi: '<svg viewBox="0 0 24 24" width="28" height="28" aria-hidden="true"><path fill="currentColor" d="M11.351 2.715c-2.7 0-4.986.025-6.83.26C2.078 3.285 0 5.154 0 8.61c0 3.506.182 6.13 1.585 8.493 1.584 2.701 4.233 4.182 7.662 4.182h.83c4.209 0 6.494-2.234 7.637-4a9.5 9.5 0 0 0 1.091-2.338C21.792 14.688 24 12.22 24 9.208v-.415c0-3.247-2.13-5.507-5.792-5.87-1.558-.156-2.65-.208-6.857-.208m0 1.947c4.208 0 5.09.052 6.571.182 2.624.311 4.13 1.584 4.13 4v.39c0 2.156-1.792 3.844-3.87 3.844h-.935l-.156.649c-.208 1.013-.597 1.818-1.039 2.546-.909 1.428-2.545 3.064-5.922 3.064h-.805c-2.571 0-4.831-.883-6.078-3.195-1.09-2-1.298-4.155-1.298-7.506 0-2.181.857-3.402 3.012-3.714 1.533-.233 3.559-.26 6.39-.26m6.547 2.287c-.416 0-.65.234-.65.546v2.935c0 .311.234.545.65.545 1.324 0 2.051-.754 2.051-2s-.727-2.026-2.052-2.026m-10.39.182c-1.818 0-3.013 1.48-3.013 3.142 0 1.533.858 2.857 1.949 3.897.727.701 1.87 1.429 2.649 1.896a1.47 1.47 0 0 0 1.507 0c.78-.467 1.922-1.195 2.623-1.896 1.117-1.039 1.974-2.364 1.974-3.897 0-1.662-1.247-3.142-3.039-3.142-1.065 0-1.792.545-2.338 1.298-.493-.753-1.246-1.298-2.312-1.298"/></svg>',
}

const labLogo = (width, height) => `<span class="lab-logo"><img class="lab-logo__dark" src="/img/conectalab-logo-white.svg" alt="Conecta Lab" width="${width}" height="${height}"><img class="lab-logo__light" src="/img/conectalab-logo-color.svg" alt="" aria-hidden="true" width="${width}" height="${height}"></span>`

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
<meta property="og:image" content="${SITE}/img/notch-configurar.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#0d1217">
<link rel="icon" type="image/svg+xml" href="/img/logo.svg">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="preload" href="/fonts/manrope-latin-wght-normal.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/fonts/space-grotesk-latin-wght-normal.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/style.css">
<link rel="stylesheet" href="/demo.css">
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
<div class="scroll-progress" aria-hidden="true"><span></span></div>
<header class="top">
  <a class="brand" href="${home}" aria-label="faro"><img src="/img/logo.svg" alt="" width="36" height="36"><span>faro</span></a>
  <a class="made-by" href="https://conectalab.co${lang === 'en' ? '/en' : ''}" aria-label="${lang === 'es' ? 'Un producto de Conecta Lab' : 'A Conecta Lab product'}">
    <span>${lang === 'es' ? 'por' : 'by'}</span>${labLogo(112, 18)}
  </a>
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
      <a href="${REPO}">GitHub</a>
      <a href="${t.path.home}#apoyo">${support[lang].footer}</a>
      <a href="${t.path.privacy}">${t.footer.privacy}</a>
      <a href="https://conectalab.co/${lang === 'es' ? 'contacto' : 'en/contact'}">${t.footer.contact}</a>
    </div>
    <div class="foot__by">
      <span>${t.footer.by}</span>
      <a class="lab-lockup" href="https://conectalab.co${lang === 'en' ? '/en' : ''}" aria-label="Conecta Lab">${labLogo(148, 24)}</a>
    </div>
  </div>
  <p class="foot__legal">${t.footer.rights} · ${t.footer.license}</p>
</footer>
<script src="/app.js" defer></script>
<script src="/demo.js" defer></script>
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

  const featureBlocks = features[lang].map((f, i) => f.id === 'notch' ? notchBento(lang, f, i) : `
  <article class="feature${i % 2 ? ' feature--flip' : ''}" id="${f.id}">
    <div class="feature__text reveal" data-number="${String(i + 1).padStart(2, '0')}">
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
  const featureIcons = { fondos: 'image', perfiles: 'layers', sistema: 'activity', diagnostico: 'stethoscope', almacenamiento: 'hard-drive', portapapeles: 'clipboard', bandeja: 'inbox', notch: 'panel-top', teclado: 'keyboard', audio: 'volume-2' }
  const moreIcons = ['hard-drive', 'coffee', 'gauge', 'sparkles', 'battery-charging', 'timer', 'mic-off', 'languages', 'command']
  const marqueeA = features[lang].map((f) => [featureIcons[f.id] ?? 'zap', f.title.replace(/\.$/, '')])
  const marqueeB = more[lang].map(([title], k) => [moreIcons[k] ?? 'zap', title])
  const featureNav = features[lang].map((f, i) => `<a href="#${f.id}"><span>${String(i + 1).padStart(2, '0')}</span>${f.title.replace(/\.$/, '')}</a>`).join('')
  const customizePoints = h.customizePoints.map((point) => `<li>${icons.arrow}<span>${point}</span></li>`).join('')

  return `${head(lang, 'home', { title: h.title, description: h.description })}
${header(lang, 'home')}
<section class="hero">
  <div class="hero__beam hero__beam--a" aria-hidden="true"></div>
  <div class="hero__beam hero__beam--b" aria-hidden="true"></div>
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
  <div class="hero__art" data-tilt>
    <div class="scene">
      <div class="scene__wall" aria-hidden="true"></div>
      <div class="scene__bar" aria-hidden="true">
        <span class="scene__brand"><img src="/img/logo.svg" alt="" width="16" height="16">faro</span>
        <span class="scene__cam"></span>
        <span class="scene__stats"><i>CPU 24%</i><i>MEM 58%</i><b>9:41</b></span>
      </div>
      <div class="scene__notch">${img('hero-notch.png', lang === 'es' ? 'El panel del notch desplegado con música, letra, controles y clima' : 'The notch panel unfolded with music, lyrics, controls and weather', ' fetchpriority="high" loading="eager"')}</div>
      <div class="scene__alas">${img('hero-aviso.png', lang === 'es' ? 'Aviso en el notch: descarga lista, con botón para mostrarla' : 'Notch notice: download ready, with a button to show it', ' loading="eager"')}</div>
      <div class="scene__menu">${img('hero-menu.png', lang === 'es' ? 'El menú de faro en la barra de menú' : 'The faro menu from the menu bar', ' loading="eager"')}</div>
    </div>
  </div>
</section>

${demoSection(lang)}

${mascotSection(lang)}

<ul class="facts" aria-label="faro">${h.facts.map((f, i) => `<li class="reveal"><span class="facts__icon">${icon(['cpu', 'shield-check', 'sliders-horizontal', 'code-xml'][i], 22)}</span><strong>${f}</strong><small>${h.factsSub[i]}</small></li>`).join('')}</ul>

<div class="marquee" aria-hidden="true">
  ${[[marqueeA, ''], [marqueeB, ' marquee__track--rev']].map(([items, cls]) => `<div class="marquee__row"><div class="marquee__track${cls}">${[0, 1].map(() => `<ul>${items.map(([ic, label]) => `<li><span>${icon(ic, 17)}</span>${label}</li>`).join('')}</ul>`).join('')}</div></div>`).join('')}
</div>

<section class="section" id="funciones">
  <div class="wrap">
    <h2 class="reveal">${h.featuresTitle}</h2>
    <p class="lead reveal">${h.featuresLead}</p>
    <nav class="feature-nav reveal" aria-label="${lang === 'es' ? 'Explorar funciones' : 'Explore features'}">${featureNav}</nav>
    ${featureBlocks}
  </div>
</section>

<section class="section customize" id="como-funciona">
  <div class="wrap customize__grid">
    <div class="customize__copy reveal">
      <p class="kicker">${lang === 'es' ? 'Tu notch, tus reglas' : 'Your notch, your rules'}</p>
      <h2>${h.customizeTitle}</h2>
      <p class="lead">${h.customizeLead}</p>
      <ul>${customizePoints}</ul>
    </div>
    <div class="customize__visual reveal" data-tilt>${img('notch-configurar.png', lang === 'es' ? 'Vista previa interactiva para organizar y redimensionar widgets' : 'Interactive preview for arranging and resizing widgets')}</div>
  </div>
</section>

<section class="section section--tint">
  <div class="wrap">
    <h2 class="reveal">${h.moreTitle}</h2>
    <div class="grid">${moreCards}</div>
  </div>
</section>

<section class="section experience">
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

<section class="section open-source">
  <div class="wrap open-source__grid">
    <div class="open-source__copy reveal">
      <span class="eyebrow">GitHub · AGPL-3.0</span>
      <h2>${h.openTitle}</h2>
      <p class="lead">${h.openLead}</p>
      <p><a class="btn btn--github" href="${REPO}" rel="noopener">${icons.code}<span>${h.openRepo}</span></a></p>
      ${REPO_PUBLIC ? '' : `<p class="muted">${h.openSoon}</p>`}
    </div>
    <div class="terminal reveal" aria-label="${lang === 'es' ? 'Ejemplo para compilar faro' : 'Example commands to build faro'}">
      <div class="terminal__bar"><i></i><i></i><i></i><span>faro — main</span></div>
      <pre><code><span class="terminal__muted">$</span> git clone ${REPO}.git
<span class="terminal__muted">$</span> cd faro
<span class="terminal__muted">$</span> ./scripts/build-app.sh

<span class="terminal__ok">✓ ${lang === 'es' ? 'nativo en Swift' : 'native Swift'}</span>
<span class="terminal__ok">✓ ${lang === 'es' ? 'sin telemetría' : 'no telemetry'}</span>
<span class="terminal__ok">✓ AGPL-3.0-or-later</span></code></pre>
    </div>
  </div>
</section>

<section class="section lab-band">
  <div class="wrap lab-band__inner reveal">
    ${labLogo(244, 40)}
    <div><h2>${h.labTitle}</h2><p class="lead">${h.labLead}</p></div>
    <a class="btn btn--ghost" href="https://conectalab.co${lang === 'en' ? '/en' : ''}">${h.labCta}${icons.arrow}</a>
  </div>
</section>

${supportSection(lang)}
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

function notchBento(lang, f, i) {
  const es = lang === 'es'
  const t = {
    music: es ? 'Música y letra' : 'Music and lyrics', musicLine: es ? 'Una luz en la costa se enciende' : 'A light on the coast turns on',
    timer: es ? 'Pomodoro' : 'Pomodoro', timerSub: es ? 'La cuenta se ve en la pastilla' : 'The countdown shows on the pill',
    alerts: es ? 'Avisos con acción' : 'Notices with actions', usb: es ? 'SANDISK conectado' : 'SANDISK connected', eject: es ? 'Expulsar' : 'Eject', dl: es ? 'Descarga lista' : 'Download ready', show: es ? 'Mostrar' : 'Show',
    battery: es ? 'Cuida tu batería' : 'Battery care', batterySub: es ? 'Aviso para desenchufar al 80 %' : 'Notice to unplug at 80%',
    privacy: es ? 'Cámara y micrófono' : 'Camera and microphone', cam: es ? 'Cámara en uso' : 'Camera in use', mic: es ? 'Micrófono en uso' : 'Microphone in use',
    widgets: es ? 'Tus widgets, a tu manera' : 'Your widgets, your way',
  }
  return `
  <article class="feature feature--bento" id="${f.id}">
    <div class="feature__text reveal" data-number="${String(i + 1).padStart(2, '0')}">
      <h3>${f.title}</h3>
      <p class="feature__lead">${f.lead}</p>
      <ul>${f.points.map((p) => `<li>${p}</li>`).join('')}</ul>
    </div>
    <div class="bento">
      <div class="bento__tile bento__tile--music reveal"><span class="bento__label">${icon('music', 15)}${t.music}</span><div class="bento__eq"><i></i><i></i><i></i><i></i><i></i></div><p class="bento__lyric"><span>${t.musicLine}</span><span>${es ? 'La noche se abre en el mar' : 'The night opens over the sea'}</span></p></div>
      <div class="bento__tile bento__tile--timer reveal"><span class="bento__label">${icon('timer', 15)}${t.timer}</span><div class="bento__ring"><svg viewBox="0 0 64 64"><circle cx="32" cy="32" r="26"/><circle class="bento__ring-bar" cx="32" cy="32" r="26" pathLength="100"/></svg><b>25:00</b></div><small>${t.timerSub}</small></div>
      <div class="bento__tile bento__tile--alerts reveal"><span class="bento__label">${icon('zap', 15)}${t.alerts}</span><div class="bento__toasts"><div class="bento__toast">${icon('usb', 16)}<span>${t.usb}</span><em>${t.eject}</em></div><div class="bento__toast">${icon('download', 16)}<span>${t.dl}</span><em>${t.show}</em></div></div></div>
      <div class="bento__tile bento__tile--battery reveal"><span class="bento__label">${icon('battery-charging', 15)}${t.battery}</span><div class="bento__battery"><i></i><b>80%</b></div><small>${t.batterySub}</small></div>
      <div class="bento__tile bento__tile--privacy reveal"><span class="bento__label">${icon('camera', 15)}${t.privacy}</span><div class="bento__dots"><span class="bento__dot bento__dot--cam"></span><em>${t.cam}</em><span class="bento__dot bento__dot--mic"></span><em>${t.mic}</em></div></div>
      <div class="bento__tile bento__tile--widgets reveal"><span class="bento__label">${icon('layers', 15)}${t.widgets}</span><div class="bento__blocks"><i></i><i></i><i></i></div></div>
    </div>
  </article>`
}

function demoSection(lang) {
  const d = demo[lang]
  const tools = [['clipboard', 'clipboard'], ['shelf', 'inbox'], ['timer', 'timer'], ['mic', 'mic'], ['color', 'pipette'], ['awake', 'coffee'], ['keyboard', 'keyboard'], ['settings', 'sliders-horizontal']]
  const sims = [['airpods', 'headphones'], ['usb', 'usb'], ['download', 'download'], ['battery', 'battery-charging']]
  return `<section class="section demo" id="prueba" aria-label="${d.title}">
  <div class="wrap">
    <div class="demo__head reveal">
      <span class="eyebrow">${d.eyebrow}</span>
      <h2>${d.title}</h2>
      <p class="lead">${d.lead}</p>
    </div>
    <div class="demo-stage reveal" data-notch-demo>
      <script type="application/json" data-demo-i18n>${JSON.stringify({ ...d, icons: Object.fromEntries(['timer', 'mic', 'mic-off', 'coffee', 'headphones', 'usb', 'download', 'battery-charging', 'keyboard', 'pipette', 'clipboard', 'inbox', 'play', 'pause', 'volume-2', 'x', 'music', 'sliders-horizontal', 'folder-down', 'plug-zap', 'cloud-sun', 'zap', 'chrome', 'link-2', 'heart'].filter((n) => lucide[n]).map((n) => [n, lucide[n]])) })}</script>
      <div class="demo-screen">
        <div class="demo-wall" aria-hidden="true"></div>
        <div class="demo-menubar" aria-hidden="true">
          <span class="demo-menubar__brand"><img src="/img/logo.svg" alt="" width="16" height="16">faro</span>
          <span class="demo-menubar__stats"><i data-sys-cpu>CPU 24%</i><i data-sys-mem>MEM 58%</i><b data-clock>9:41</b></span>
        </div>
        <div class="demo-notch" data-notch aria-live="polite">
          <button class="dn-pill" type="button" data-pill aria-label="${d.hint}" aria-expanded="false">
            <span class="dn-pill__left" data-pill-left></span>
            <span class="dn-pill__cam"></span>
            <span class="dn-pill__right" data-pill-right></span>
          </button>
          <div class="dn-lyric" data-pill-lyric></div>
          <div class="dn-panel" data-panel>
            <div class="dn-tabs" role="tablist">
              <button class="dn-pet" type="button" data-demo-pet aria-label="${d.mascot.label}"><i><b></b><b></b></i><em>♥</em></button>
              ${['home', 'system', 'audio', 'tools'].map((t, k) => `<button role="tab" type="button" data-tab="${t}" aria-selected="${k === 0}">${d.tabs[t]}</button>`).join('')}
              <button class="dn-close" type="button" data-collapse aria-label="Cerrar">${icon('x', 16)}</button>
            </div>
            <div class="dn-views">
              <div class="dn-view dn-view--home" data-view="home">
                <div class="dn-music">
                  <div class="dn-art" data-art><span class="dn-eq"><i></i><i></i><i></i><i></i></span></div>
                  <div class="dn-meta"><strong data-title></strong><span data-artist></span></div>
                  <div class="dn-controls">
                    <button type="button" data-prev aria-label="Anterior">${icon('skip-back', 16)}</button>
                    <button type="button" class="dn-play" data-play aria-label="Reproducir o pausar">${icon('pause', 18)}</button>
                    <button type="button" data-next aria-label="Siguiente">${icon('skip-forward', 16)}</button>
                  </div>
                  <div class="dn-lyrics"><p data-lyric-now></p><p data-lyric-next></p></div>
                  <div class="dn-progress"><i data-progress></i></div>
                </div>
                <div class="dn-side">
                  <div class="dn-card dn-volume">
                    <span class="dn-card__label"><span data-vol-icon>${icon('volume-2', 15)}</span>${d.volume}<b data-vol-value>60</b></span>
                    <input type="range" min="0" max="100" value="60" data-volume aria-label="${d.volume}">
                  </div>
                  <div class="dn-card dn-weather">
                    <span class="dn-weather__icon">${icon('cloud-sun', 30)}</span>
                    <span><small>${d.weather.city}</small><strong>${d.weather.temp}</strong><em>${d.weather.text}</em></span>
                  </div>
                </div>
              </div>
              <div class="dn-view dn-view--system" data-view="system" hidden>
                ${[['cpu', 'cpu'], ['mem', 'activity'], ['disk', 'hard-drive'], ['bat', 'battery-charging']].map(([k, ic]) => `<div class="dn-ring" data-ring="${k}"><svg viewBox="0 0 64 64"><circle cx="32" cy="32" r="26"/><circle class="dn-ring__bar" cx="32" cy="32" r="26" pathLength="100"/></svg><span class="dn-ring__icon">${icon(ic, 16)}</span><strong data-ring-value>0</strong><small>${d.system[k]}</small></div>`).join('')}
              </div>
              <div class="dn-view dn-view--audio" data-view="audio" hidden>
                ${[
                  ['master', 'volume-2', 60, ''],
                  ['music', 'music', 74, ''],
                  ['spotify', 'headphones', 48, ''],
                  ['chrome', 'chrome', 60, d.audio.linked],
                ].map(([k, ic, value, note]) => `<label class="dn-audio-row${note ? ' is-linked' : ''}"><span class="dn-audio-icon">${icon(ic, 18)}</span><span class="dn-audio-name"><strong>${d.audio[k]}</strong>${note ? `<small>${note}</small>` : ''}</span><input type="range" min="0" max="100" value="${value}" data-audio="${k}" ${note ? 'disabled' : ''}><b data-audio-value="${k}">${value}</b></label>`).join('')}
              </div>
              <div class="dn-view dn-view--tools" data-view="tools" hidden>
                ${tools.map(([k, ic], n) => `<button type="button" class="dn-tool" data-tool="${k}" style="--i:${n}">${icon(ic, 20)}<span>${d.tools[k]}</span></button>`).join('')}
              </div>
            </div>
          </div>
        </div>
        <div class="dn-toast" data-toast hidden></div>
        <div class="dn-popover" data-popover hidden></div>
        <div class="dn-lock" data-lock hidden>
          <div class="dn-lock__box">${icon('keyboard', 34)}<strong>${d.keyboardLock.title}</strong><p>${d.keyboardLock.text}</p><b data-lock-count>10</b><button type="button" data-lock-exit>${d.keyboardLock.exit}</button></div>
        </div>
        <span class="demo-hint" data-hint>${icon('mouse-pointer-click', 15)}${d.hint}</span>
      </div>
      <div class="demo-sims">
        <span>${d.simulate}</span>
        ${sims.map(([k, ic]) => `<button type="button" class="chip" data-sim="${k}">${icon(ic, 15)}${d.sims[k]}</button>`).join('')}
      </div>
    </div>
  </div>
</section>`
}

function mascotSection(lang) {
  const h = ui[lang].home
  const labels = lang === 'es'
    ? ['Sigue tu mirada', 'Baila con la música', 'Celebra contigo', 'También toma siestas']
    : ['Follows your gaze', 'Dances to music', 'Celebrates with you', 'Also takes naps']
  return `<section class="section mascot" id="mascota">
  <div class="wrap mascot__grid">
    <div class="mascot__copy reveal">
      <span class="eyebrow">${h.mascotEyebrow}</span>
      <h2>${h.mascotTitle}</h2>
      <p class="lead">${h.mascotLead}</p>
      <ul>${h.mascotPoints.map((point) => `<li>${icons.arrow}<span>${point}</span></li>`).join('')}</ul>
      <div class="mascot__cta">${downloadButton(lang)}<a href="#funciones">${h.mascotCta}${icons.arrow}</a></div>
    </div>
    <div class="mascot__showcase reveal" data-tilt>
      <div class="mascot__halo" aria-hidden="true"></div>
      <div class="mascot__strip">${img('mascota-personalizada.png', lang === 'es' ? 'Tres versiones personalizadas de la mascota de faro' : 'Three customized versions of faro’s mascot')}</div>
      <div class="mascot__app">${img('mascota.png', lang === 'es' ? 'La página para personalizar la mascota, con expresiones, colores y accesorios' : 'The mascot customization page with expressions, colors and accessories')}</div>
      <div class="mascot__reactions" aria-hidden="true">${labels.map((label, index) => `<span style="--i:${index}">${['◉', '♫', '♥', 'zZ'][index]} ${label}</span>`).join('')}</div>
    </div>
  </div>
</section>`
}

function supportSection(lang) {
  const s = support[lang]
  const button = (kind, title, url) => url
    ? `<a class="support-btn support-btn--${kind}" href="${url}" rel="noopener">${brand[kind]}<span>${title}</span>${icons.arrow}</a>`
    : `<div class="support-btn support-btn--${kind} support-btn--soon">${brand[kind]}<span>${title}</span><small>${s.soon}</small></div>`
  return `<section class="section support-section" id="apoyo">
  <div class="wrap">
    <div class="support-panel reveal">
      <div class="support-panel__copy">
        <span class="eyebrow">${s.eyebrow}</span>
        <h2>${s.title}</h2>
        <p class="lead">${s.lead}</p>
        <ul class="support-uses">${s.uses.map((u) => `<li>${icons.arrow}<span>${u}</span></li>`).join('')}</ul>
      </div>
      <div class="support-panel__actions">
        ${button('github', s.github, SPONSORS_URL)}
        ${button('kofi', s.kofi, KOFI_URL)}
        <p class="muted">${s.note}</p>
      </div>
    </div>
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
cpSync(join(root, 'src/demo.css'), join(dist, 'demo.css'))
cpSync(join(root, 'src/demo.js'), join(dist, 'demo.js'))

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
