// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Conecta Lab Corp.
(function () {
  var root = document.documentElement
  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches

  var toggle = document.querySelector('[data-theme-toggle]')
  if (toggle) {
    toggle.addEventListener('click', function () {
      var current = root.dataset.theme || (matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark')
      var next = current === 'light' ? 'dark' : 'light'
      root.dataset.theme = next
      try { localStorage.setItem('faro-theme', next) } catch (e) {}
    })
  }

  var items = document.querySelectorAll('.reveal')
  if (!('IntersectionObserver' in window) || reduce) {
    items.forEach(function (el) { el.classList.add('in') })
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('in')
          io.unobserve(entry.target)
        }
      })
    }, { rootMargin: '0px 0px -7% 0px', threshold: 0.06 })
    items.forEach(function (el, index) {
      el.style.transitionDelay = Math.min(index % 3, 2) * 55 + 'ms'
      io.observe(el)
    })
  }

  var progress = document.querySelector('.scroll-progress span')
  function updateProgress() {
    if (!progress) return
    var height = document.documentElement.scrollHeight - innerHeight
    root.style.setProperty('--scroll', (height > 0 ? scrollY / height * 100 : 0).toFixed(2) + '%')
  }
  addEventListener('scroll', updateProgress, { passive: true })
  addEventListener('resize', updateProgress, { passive: true })
  updateProgress()

  if (!reduce && matchMedia('(pointer:fine)').matches) {
    document.querySelectorAll('[data-tilt]').forEach(function (card) {
      card.addEventListener('pointermove', function (event) {
        var box = card.getBoundingClientRect()
        var x = (event.clientX - box.left) / box.width - 0.5
        var y = (event.clientY - box.top) / box.height - 0.5
        card.style.setProperty('--tilt-x', (x * 2.5).toFixed(2) + 'deg')
        card.style.setProperty('--tilt-y', (-y * 2.2).toFixed(2) + 'deg')
      })
      card.addEventListener('pointerleave', function () {
        card.style.setProperty('--tilt-x', '0deg')
        card.style.setProperty('--tilt-y', '0deg')
      })
    })
  }
})()
