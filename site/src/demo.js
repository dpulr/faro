// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín
// Notch de pruebas: todo ocurre en el navegador, no se envía nada a ningún servidor.
(function () {
  var root = document.querySelector('[data-notch-demo]')
  if (!root) return
  var T = JSON.parse(root.querySelector('[data-demo-i18n]').textContent)
  var $ = function (s, r) { return (r || root).querySelector(s) }
  var $$ = function (s, r) { return Array.prototype.slice.call((r || root).querySelectorAll(s)) }
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches
  var screen = $('.demo-screen')
  var notch = $('[data-notch]')

  function ic(name, size) {
    size = size || 16
    return '<svg class="ic" viewBox="0 0 24 24" width="' + size + '" height="' + size + '" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (T.icons[name] || '') + '</svg>'
  }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c] }) }
  function fmt(n) { n = Math.max(0, Math.round(n)); return Math.floor(n / 60) + ':' + ('0' + (n % 60)).slice(-2) }

  // ---------- Estado ----------
  var S = { open: false, tab: 'home', playing: true, track: 0, pos: 0, volume: 60, micMuted: false, awake: false, popover: null, hovering: false }
  var timer = { phase: 'idle', total: 0, remaining: 0, running: false, end: 0 }
  var files = []
  var sys = { cpu: 24, mem: 58, disk: 68, bat: 80 }
  var closeTimer = null

  // ---------- Abrir y cerrar ----------
  function setOpen(on) {
    S.open = on
    screen.classList.toggle('demo-open', on)
    $('[data-pill]').setAttribute('aria-expanded', on ? 'true' : 'false')
    if (on) { $('[data-hint]').classList.add('is-gone'); refreshSystem() }
    else closePopover()
    renderPill()
  }
  notch.addEventListener('mouseenter', function () { S.hovering = true; clearTimeout(closeTimer); if (matchMedia('(hover: hover)').matches) setOpen(true) })
  notch.addEventListener('mouseleave', function () {
    S.hovering = false
    clearTimeout(closeTimer)
    closeTimer = setTimeout(function () { if (!S.hovering && !S.popover) setOpen(false) }, 450)
  })
  $('[data-pill]').addEventListener('click', function () { setOpen(!S.open) })
  $('[data-collapse]').addEventListener('click', function () { setOpen(false) })
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { if (!$('[data-lock]').hidden) unlock(); else if (S.popover) closePopover(); else setOpen(false) }
  })
  document.addEventListener('click', function (e) {
    if (S.popover && !e.target.closest('[data-popover]') && !e.target.closest('[data-tool]') && !e.target.closest('[data-notch]')) closePopover()
  })

  // ---------- Pestañas ----------
  $$('[data-tab]').forEach(function (b) {
    b.addEventListener('click', function () {
      S.tab = b.getAttribute('data-tab')
      $$('[data-tab]').forEach(function (x) { x.setAttribute('aria-selected', x === b ? 'true' : 'false') })
      $$('[data-view]').forEach(function (v) { v.hidden = v.getAttribute('data-view') !== S.tab })
      if (S.tab === 'system') refreshSystem()
    })
  })

  // ---------- Música y letras ----------
  var LINES = T.lyrics
  function renderTrack() {
    var t = T.tracks[S.track]
    $('[data-title]').textContent = t.title
    $('[data-artist]').textContent = t.artist
    $('[data-art]').style.setProperty('--hue', t.hue)
    renderLyrics(true)
    renderPill()
  }
  function lineIndex() { return Math.floor(S.pos / 5) % LINES.length }
  var lastLine = -1
  function renderLyrics(force) {
    var i = (lineIndex() + S.track) % LINES.length
    if (i === lastLine && !force) return
    lastLine = i
    var now = $('[data-lyric-now]'), next = $('[data-lyric-next]')
    now.textContent = LINES[i][0]; next.textContent = LINES[i][1]
    ;[now, next].forEach(function (el) { el.classList.remove('is-swap'); void el.offsetWidth; el.classList.add('is-swap') })
    renderPill()
  }
  function setPlaying(on) {
    S.playing = on
    root.classList.toggle('demo-paused', !on)
    $('[data-play]').innerHTML = ic(on ? 'pause' : 'play', 18)
    renderPill()
  }
  $('[data-play]').addEventListener('click', function () { setPlaying(!S.playing) })
  function changeTrack(d) { S.track = (S.track + d + T.tracks.length) % T.tracks.length; S.pos = 0; renderTrack() }
  $('[data-next]').addEventListener('click', function () { changeTrack(1) })
  $('[data-prev]').addEventListener('click', function () { changeTrack(-1) })
  setInterval(function () {
    if (S.playing) {
      S.pos += 0.5
      if (S.pos >= 120) changeTrack(1)
      $('[data-progress]').style.width = Math.min(100, (S.pos / 120) * 100) + '%'
      renderLyrics(false)
    }
  }, 500)

  // ---------- Volumen ----------
  var vol = $('[data-volume]')
  function renderVolume() {
    vol.style.setProperty('--v', vol.value + '%')
    $('[data-vol-value]').textContent = vol.value
    $('[data-vol-icon]').innerHTML = ic(+vol.value === 0 ? 'x' : 'volume-2', 15)
  }
  vol.addEventListener('input', function () { S.volume = +vol.value; renderVolume() })
  renderVolume()

  // ---------- Pastilla (notch recogido) ----------
  function renderPill() {
    var left = '', right = ''
    var t = T.tracks[S.track]
    if (timer.phase !== 'idle') {
      left = ic('timer', 15)
      right = '<span>' + fmt(timer.remaining) + '</span>'
    } else if (S.playing) {
      left = '<span class="dn-mini-art" style="background:linear-gradient(135deg,hsl(' + t.hue + ' 80% 58%),hsl(' + (t.hue + 50) + ' 70% 32%))"></span>'
      right = '<span class="dn-wave"><i></i><i></i><i></i><i></i></span>'
    }
    if (S.micMuted) left = '<span style="color:#ff6b62">' + ic('mic-off', 15) + '</span>' + left
    if (S.awake) right += '<span style="color:var(--amber-2)">' + ic('coffee', 15) + '</span>'
    $('[data-pill-left]').innerHTML = left
    $('[data-pill-right]').innerHTML = right
    var ly = $('[data-pill-lyric]')
    var line = S.playing && !S.open ? LINES[(lineIndex() + S.track) % LINES.length][0] : ''
    ly.textContent = line
    ly.classList.toggle('is-on', !!line)
  }

  // ---------- Avisos ----------
  var toastTimer = null
  function toast(o) {
    var el = $('[data-toast]')
    var lead = o.swatch ? '<span class="dn-swatch" style="background:' + o.swatch + '"></span>' : ic(o.icon || 'zap', 17)
    el.innerHTML = lead + '<span>' + esc(o.text) + '</span>' + (o.action ? '<button type="button">' + esc(o.action.label) + '</button>' : '')
    if (o.action) el.querySelector('button').addEventListener('click', function () { hideToast(); o.action.run() })
    el.hidden = false
    void el.offsetWidth
    el.classList.add('is-on')
    clearTimeout(toastTimer)
    toastTimer = setTimeout(hideToast, o.ms || 3200)
  }
  function hideToast() { var el = $('[data-toast]'); el.classList.remove('is-on'); setTimeout(function () { if (!el.classList.contains('is-on')) el.hidden = true }, 450) }

  $$('[data-sim]').forEach(function (b) {
    b.addEventListener('click', function () {
      setOpen(false)
      var k = b.getAttribute('data-sim'), x = T.toasts
      if (k === 'airpods') toast({ icon: 'headphones', text: x.airpods + ' · 82%' })
      if (k === 'usb') toast({ icon: 'usb', text: x.usb, ms: 7000, action: { label: x.eject, run: function () { toast({ icon: 'zap', text: x.ejected }) } } })
      if (k === 'download') toast({ icon: 'download', text: x.download, ms: 7000, action: { label: x.show, run: function () { toast({ icon: 'folder-down', text: x.shown }) } } })
      if (k === 'battery') toast({ icon: 'battery-charging', text: x.battery, ms: 4500 })
    })
  })

  // ---------- Sistema ----------
  function ring(k, v, label) {
    var el = $('[data-ring="' + k + '"]')
    el.querySelector('.dn-ring__bar').style.strokeDashoffset = String(100 - v)
    el.querySelector('[data-ring-value]').textContent = label
  }
  function refreshSystem() {
    ring('cpu', sys.cpu, Math.round(sys.cpu) + '%')
    ring('mem', sys.mem, Math.round(sys.mem) + '%')
    ring('disk', sys.disk, '161 GB')
    ring('bat', sys.bat, Math.round(sys.bat) + '%')
    $('[data-sys-cpu]').textContent = 'CPU ' + Math.round(sys.cpu) + '%'
    $('[data-sys-mem]').textContent = 'MEM ' + Math.round(sys.mem) + '%'
  }
  setInterval(function () {
    sys.cpu = Math.min(70, Math.max(8, sys.cpu + (Math.random() - 0.5) * 14))
    sys.mem = Math.min(66, Math.max(52, sys.mem + (Math.random() - 0.5) * 2))
    refreshSystem()
  }, 1600)
  function clock() { var d = new Date(); $('[data-clock]').textContent = d.getHours() + ':' + ('0' + d.getMinutes()).slice(-2) }
  clock(); setInterval(clock, 20000)

  // ---------- Herramientas ----------
  function markTool(name, cls, on) { var b = $('[data-tool="' + name + '"]'); if (b) b.classList.toggle(cls, on) }
  function openPopover(kind) {
    S.popover = kind
    var p = $('[data-popover]')
    p.hidden = false
    if (kind === 'clipboard') {
      p.innerHTML = '<h4>' + ic('clipboard', 17) + T.clipboard.title + '<button type="button" data-pop-close>' + ic('x', 14) + '</button></h4><div class="dn-clip">' + T.clipboard.items.map(function (t) { return '<button type="button" data-clip="' + esc(t) + '">' + esc(t) + '</button>' }).join('') + '</div>'
      $$('[data-clip]', p).forEach(function (b) { b.addEventListener('click', function () { copy(b.getAttribute('data-clip')); toast({ icon: 'clipboard', text: T.clipboard.copied }); closePopover() }) })
    } else if (kind === 'shelf') {
      p.innerHTML = '<h4>' + ic('inbox', 17) + T.shelf.title + '<button type="button" data-pop-close>' + ic('x', 14) + '</button></h4><label class="dn-drop" data-drop>' + ic('inbox', 26) + '<span>' + T.shelf.drop + '</span><small>' + T.shelf.pick + '</small><input type="file" multiple hidden></label><div class="dn-files" data-files></div><small style="display:block;margin-top:10px;color:rgba(255,255,255,.45);font-size:11px">' + T.shelf.note + '</small>'
      var drop = $('[data-drop]', p), input = $('input', p)
      input.addEventListener('change', function () { addFiles(input.files) })
      ;['dragenter', 'dragover'].forEach(function (ev) { drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.add('is-over') }) })
      ;['dragleave', 'drop'].forEach(function (ev) { drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.remove('is-over') }) })
      drop.addEventListener('drop', function (e) { addFiles(e.dataTransfer.files) })
      renderFiles()
    } else if (kind === 'timer') {
      renderTimerPopover()
    }
    var close = $('[data-pop-close]', p)
    if (close) close.addEventListener('click', closePopover)
  }
  function closePopover() { S.popover = null; var p = $('[data-popover]'); p.hidden = true; p.innerHTML = '' }
  function copy(text) { try { navigator.clipboard.writeText(text) } catch (e) {} }

  function addFiles(list) {
    Array.prototype.forEach.call(list || [], function (f) { files.push({ name: f.name, size: f.size }) })
    renderFiles()
    if (list && list.length) toast({ icon: 'inbox', text: T.toasts.shelfAdded })
  }
  function renderFiles() {
    var box = $('[data-files]')
    if (!box) return
    box.innerHTML = files.slice(-4).map(function (f) { return '<div>' + ic('folder-down', 14) + '<span>' + esc(f.name) + '</span><em>' + (f.size > 1048576 ? (f.size / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(f.size / 1024)) + ' KB') + '</em></div>' }).join('')
  }
  // Arrastrar un archivo sobre el escenario abre la bandeja, como en la app
  screen.addEventListener('dragover', function (e) {
    if (e.dataTransfer && Array.prototype.indexOf.call(e.dataTransfer.types || [], 'Files') >= 0) { e.preventDefault(); if (S.popover !== 'shelf') { setOpen(true); openPopover('shelf') } }
  })
  screen.addEventListener('drop', function (e) { if (e.dataTransfer && e.dataTransfer.files.length) { e.preventDefault(); addFiles(e.dataTransfer.files) } })

  // Temporizador
  function startTimer(seconds) {
    timer.phase = 'focus'; timer.total = seconds; timer.remaining = seconds; timer.running = true; timer.end = Date.now() + seconds * 1000
    markTool('timer', 'is-on', true); renderPill()
  }
  function timerTick() {
    if (timer.phase === 'idle' || !timer.running) return
    timer.remaining = Math.max(0, Math.ceil((timer.end - Date.now()) / 1000))
    if (timer.remaining === 0) { timerReset(); toast({ icon: 'timer', text: T.timer.done, ms: 5000 }) }
    renderPill(); if (S.popover === 'timer') renderTimerPopover()
  }
  setInterval(timerTick, 500)
  function timerReset() { timer.phase = 'idle'; timer.running = false; timer.remaining = 0; markTool('timer', 'is-on', false); renderPill() }
  function renderTimerPopover() {
    var p = $('[data-popover]'), idle = timer.phase === 'idle'
    p.innerHTML = '<h4>' + ic('timer', 17) + T.timer.focus + '<button type="button" data-pop-close>' + ic('x', 14) + '</button></h4><div class="dn-timer"><strong>' + fmt(idle ? 25 * 60 : timer.remaining) + '</strong><div class="dn-timer__row">' +
      (idle ? [25 * 60, 5 * 60, 10].map(function (s, i) { return '<button type="button" class="' + (i === 0 ? 'is-main' : '') + '" data-preset="' + s + '">' + T.timer.presets[i] + '</button>' }).join('')
        : '<button type="button" class="is-main" data-tpause>' + (timer.running ? T.timer.pause : T.timer.resume) + '</button><button type="button" data-treset>' + T.timer.reset + '</button>') + '</div></div>'
    $$('[data-preset]', p).forEach(function (b) { b.addEventListener('click', function () { startTimer(+b.getAttribute('data-preset')); renderTimerPopover() }) })
    var pb = $('[data-tpause]', p), rb = $('[data-treset]', p), cb = $('[data-pop-close]', p)
    if (pb) pb.addEventListener('click', function () {
      if (timer.running) { timer.remaining = Math.max(0, Math.ceil((timer.end - Date.now()) / 1000)); timer.running = false } else { timer.end = Date.now() + timer.remaining * 1000; timer.running = true }
      renderTimerPopover(); renderPill()
    })
    if (rb) rb.addEventListener('click', function () { timerReset(); renderTimerPopover() })
    if (cb) cb.addEventListener('click', closePopover)
  }

  // Teclado bloqueado
  var lockTimer = null
  function lock() {
    var box = $('[data-lock]'), n = 10
    box.hidden = false; $('[data-lock-count]').textContent = n; setOpen(false)
    clearInterval(lockTimer)
    lockTimer = setInterval(function () { n--; $('[data-lock-count]').textContent = n; if (n <= 0) unlock() }, 1000)
  }
  function unlock() { clearInterval(lockTimer); $('[data-lock]').hidden = true }
  $('[data-lock-exit]').addEventListener('click', unlock)

  var palette = ['#F2B24F', '#6BA5CE', '#4ED7C8', '#FF5E5B', '#8A7CFF']
  $$('[data-tool]').forEach(function (b) {
    b.addEventListener('click', function () {
      var k = b.getAttribute('data-tool'), x = T.toasts
      if (k === 'clipboard' || k === 'shelf' || k === 'timer') { S.popover === k ? closePopover() : openPopover(k) }
      if (k === 'mic') {
        S.micMuted = !S.micMuted; b.classList.toggle('is-alert', S.micMuted)
        b.querySelector('.ic').outerHTML = ic(S.micMuted ? 'mic-off' : 'mic', 22)
        toast({ icon: S.micMuted ? 'mic-off' : 'mic', text: S.micMuted ? x.micOff : x.micOn, ms: 2200 }); renderPill()
      }
      if (k === 'awake') {
        S.awake = !S.awake; b.classList.toggle('is-on', S.awake)
        toast({ icon: 'coffee', text: S.awake ? x.awakeOn : x.awakeOff, ms: 2200 }); renderPill()
      }
      if (k === 'color') {
        var done = function (hex) { copy(hex); toast({ swatch: hex, text: hex + ' ' + x.color, ms: 4000 }) }
        setOpen(false)
        if (window.EyeDropper) { new window.EyeDropper().open().then(function (r) { done(r.sRGBHex.toUpperCase()) }).catch(function () {}) }
        else done(palette[Math.floor(Math.random() * palette.length)])
      }
      if (k === 'keyboard') lock()
      if (k === 'settings') { var a = document.getElementById('como-funciona'); if (a) a.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth' }) }
    })
  })

  // Bloq Mayús real (si tienes el cursor en la página)
  window.addEventListener('keyup', function (e) {
    if (e.key === 'CapsLock' && e.getModifierState) {
      var on = e.getModifierState('CapsLock')
      toast({ icon: 'keyboard', text: T.toasts.caps + ' ' + (on ? 'ON' : 'OFF'), ms: 1600 })
    }
  })

  // Parallax suave del escenario con el cursor
  if (!reduce) {
    screen.addEventListener('mousemove', function (e) {
      var r = screen.getBoundingClientRect(), x = (e.clientX - r.left) / r.width - 0.5, y = (e.clientY - r.top) / r.height - 0.5
      screen.style.setProperty('--px', (x * 14).toFixed(1) + 'px'); screen.style.setProperty('--py', (y * 10).toFixed(1) + 'px')
      $('.demo-wall').style.transform = 'translate(' + (x * -10).toFixed(1) + 'px,' + (y * -8).toFixed(1) + 'px) scale(1.04)'
    })
  }

  renderTrack(); setPlaying(true); refreshSystem(); renderPill()
})()
