// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín
(function () {
  var root = document.documentElement
  // Tema: el botón alterna y recuerda la elección (si el navegador lo permite).
  var toggle = document.querySelector('[data-theme-toggle]')
  if (toggle) {
    toggle.addEventListener('click', function () {
      var current = root.dataset.theme || (matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark')
      var next = current === 'light' ? 'dark' : 'light'
      root.dataset.theme = next
      try { localStorage.setItem('faro-theme', next) } catch (e) {}
    })
  }
  // Aparición suave al hacer scroll.
  var items = document.querySelectorAll('.reveal')
  if (!('IntersectionObserver' in window) || matchMedia('(prefers-reduced-motion: reduce)').matches) {
    items.forEach(function (el) { el.classList.add('in') })
    return
  }
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target) } })
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.05 })
  items.forEach(function (el) { io.observe(el) })
})()
