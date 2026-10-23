// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

struct TecladoPage: View {
    @EnvironmentObject var cleaning: CleaningMode
    @State private var trusted = AXIsProcessTrusted()
    private let recheck = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private let durations: [(String, Int)] = [("30 segundos", 30), ("1 minuto", 60), ("2 minutos", 120), ("5 minutos", 300)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Limpiar teclado",
                       subtitle: "Bloquea las teclas un momento para limpiarlas sin escribir nada por accidente.")

            Card {
                HStack(spacing: 14) {
                    Image(systemName: "keyboard").font(.system(size: 22)).foregroundStyle(Theme.accent)
                        .frame(width: 48, height: 48).background(Circle().fill(Theme.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Listo para limpiar").font(.title3.weight(.semibold))
                        Text("La pantalla se oscurece con una cuenta regresiva y el teclado deja de responder.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { cleaning.start() } label: { Text("Empezar a limpiar") }
                        .buttonStyle(PillButtonStyle(prominent: true))
                }
            }

            Card(padding: 4) {
                VStack(spacing: 0) {
                    row("Duración", "Se desbloquea solo cuando llega a cero.") {
                        Choice(selection: $cleaning.duration, options: durations)
                    }
                    Divider().padding(.horizontal, 12)
                    row("Bloquear también el trackpad y el mouse",
                        "Con esto activado el botón «Terminar» no funciona: se sale esperando o con Esc.") {
                        Toggle("", isOn: $cleaning.lockPointer).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    row("Bloqueo completo (opcional)",
                        trusted ? "Activo: además bloquea volumen, brillo y los atajos del sistema."
                                : "Sin permiso se usa el bloqueo básico: ya impide escribir, pero no frena las teclas de volumen ni de brillo.") {
                        if trusted {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                        } else {
                            Button("Dar permiso") {
                                cleaning.requestPermission()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { trusted = AXIsProcessTrusted() }
                            }
                            .buttonStyle(PillButtonStyle())
                        }
                    }
                }
            }

            if !trusted {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("¿Quieres el bloqueo completo y el permiso no se activa?", systemImage: "exclamationmark.circle")
                            .font(.callout.weight(.semibold)).foregroundStyle(Theme.warning)
                        Text("macOS liga el permiso a la firma exacta de la app. Si activaste una versión anterior, el interruptor se ve encendido pero no vale para esta. Se arregla una sola vez:")
                            .font(.callout).foregroundStyle(.secondary)
                        tip("1.circle", "Abre Ajustes del Sistema → Privacidad y seguridad → Accesibilidad.")
                        tip("2.circle", "Selecciona faro en la lista y pulsa el botón «−» para quitarlo.")
                        tip("3.circle", "Vuelve aquí y pulsa «Dar permiso»; cuando macOS lo pida, actívalo.")
                        HStack {
                            Button("Abrir Accesibilidad") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(PillButtonStyle())
                            Button("Reiniciar faro") { AppController.shared.relaunch() }
                                .buttonStyle(PillButtonStyle())
                            Text("Esta pantalla se actualiza sola.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cómo salir").font(.callout.weight(.semibold))
                    tip("clock", "Se desbloquea solo cuando la cuenta regresiva llega a cero.")
                    tip("escape", "Mantén presionada la tecla Esc durante 3 segundos para salir antes.")
                    tip("cursorarrow.click", "Si no bloqueas el mouse, también puedes pulsar «Terminar ahora» en pantalla.")
                    tip("power", "El botón de encendido y Touch ID no se pueden bloquear: evítalos al limpiar.")
                }
            }
        }
        .onAppear { trusted = AXIsProcessTrusted() }
        .onReceive(recheck) { _ in trusted = AXIsProcessTrusted() }
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 20).foregroundStyle(.secondary)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func row<Control: View>(_ title: String, _ detail: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(12)
    }
}
