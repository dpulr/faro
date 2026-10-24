// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import CoreAudio
import Foundation

/// Silencia el micrófono del sistema de un toque, sirve para cualquier app de videollamadas.
/// Usa la propiedad de silencio del dispositivo; si no la tiene, baja el volumen de entrada a cero y lo recuerda.
@MainActor
final class MicMute: ObservableObject {
    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "micMuteEnabled") } }
    @Published private(set) var muted = false
    /// `false` si el micrófono actual no deja controlar ni el silencio ni el volumen.
    @Published private(set) var available = true

    private static let savedKey = "micMuteSavedVolume"
    private let input = AudioObjectPropertyScope(kAudioDevicePropertyScopeInput)

    init() {
        enabled = UserDefaults.standard.object(forKey: "micMuteEnabled") as? Bool ?? true
        refresh()
    }

    private func address(_ selector: AudioObjectPropertySelector, element: UInt32 = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: input, mElement: element)
    }

    private var device: AudioDeviceID? {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    private func settable(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector, element: UInt32) -> Bool {
        var a = address(selector, element: element)
        var can = DarwinBoolean(false)
        return AudioObjectHasProperty(device, &a) && AudioObjectIsPropertySettable(device, &a, &can) == noErr && can.boolValue
    }

    private func read(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector, element: UInt32) -> Float32? {
        var a = address(selector, element: element)
        guard AudioObjectHasProperty(device, &a) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        if selector == kAudioDevicePropertyMute {
            var flag = UInt32(0)
            var flagSize = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(device, &a, 0, nil, &flagSize, &flag) == noErr else { return nil }
            return Float32(flag)
        }
        return AudioObjectGetPropertyData(device, &a, 0, nil, &size, &value) == noErr ? value : nil
    }

    private func write(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector, element: UInt32, _ value: Float32) -> Bool {
        var a = address(selector, element: element)
        if selector == kAudioDevicePropertyMute {
            var flag = UInt32(value > 0 ? 1 : 0)
            return AudioObjectSetPropertyData(device, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &flag) == noErr
        }
        var v = value
        return AudioObjectSetPropertyData(device, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) == noErr
    }

    /// Elementos con volumen: el principal o, si no hay, los canales 1 y 2.
    private func volumeElements(_ device: AudioDeviceID) -> [UInt32] {
        if settable(device, kAudioDevicePropertyVolumeScalar, element: kAudioObjectPropertyElementMain) { return [kAudioObjectPropertyElementMain] }
        return [1, 2].filter { settable(device, kAudioDevicePropertyVolumeScalar, element: $0) }
    }

    func refresh() {
        guard let device else { available = false; muted = false; return }
        if settable(device, kAudioDevicePropertyMute, element: kAudioObjectPropertyElementMain) {
            available = true
            muted = (read(device, kAudioDevicePropertyMute, element: kAudioObjectPropertyElementMain) ?? 0) > 0
            return
        }
        let elements = volumeElements(device)
        available = !elements.isEmpty
        muted = available && elements.allSatisfy { (read(device, kAudioDevicePropertyVolumeScalar, element: $0) ?? 1) == 0 }
    }

    func toggle() { setMuted(!muted) }

    @discardableResult
    func setMuted(_ on: Bool) -> Bool {
        guard let device else { return false }
        if settable(device, kAudioDevicePropertyMute, element: kAudioObjectPropertyElementMain) {
            _ = write(device, kAudioDevicePropertyMute, element: kAudioObjectPropertyElementMain, on ? 1 : 0)
        } else {
            let elements = volumeElements(device)
            guard !elements.isEmpty else { return false }
            if on {
                let current = elements.compactMap { read(device, kAudioDevicePropertyVolumeScalar, element: $0) }.max() ?? 0.7
                if current > 0 { UserDefaults.standard.set(Double(current), forKey: Self.savedKey) }
                for e in elements { _ = write(device, kAudioDevicePropertyVolumeScalar, element: e, 0) }
            } else {
                let saved = UserDefaults.standard.object(forKey: Self.savedKey) as? Double ?? 0.7
                for e in elements { _ = write(device, kAudioDevicePropertyVolumeScalar, element: e, Float32(saved)) }
            }
        }
        refresh()
        return muted == on
    }
}
