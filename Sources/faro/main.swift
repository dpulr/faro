// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit

// faro no usa escenas de SwiftUI: el ícono, el menú y las ventanas los maneja AppController.
// (Una escena vacía hacía que macOS abriera una ventana "faro Settings" cada vez.)
LegacyMigration.run()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
