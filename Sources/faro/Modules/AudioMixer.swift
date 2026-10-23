// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import CoreAudio
import Foundation

struct AudioOutput: Identifiable, Hashable {
    let id: AudioObjectID
    let name: String
}

/// Volumen y salida de audio del Mac. macOS no deja cambiar el volumen de otras apps, pero sí el del dispositivo,
/// el silencio y la salida; Música y Spotify tienen además un volumen propio.
@MainActor
final class AudioMixer: ObservableObject {
    @Published private(set) var outputs: [AudioOutput] = []
    @Published private(set) var defaultOutput: AudioObjectID = 0
    @Published private(set) var volume = 0.0
    @Published private(set) var muted = false
    /// Algunas salidas (HDMI, por ejemplo) no dejan cambiar el volumen desde el Mac.
    @Published private(set) var canSetVolume = true
    @Published private(set) var musicVolume: Double?
    @Published private(set) var spotifyVolume: Double?

    private var timer: Timer?
    private static let system = AudioObjectID(kAudioObjectSystemObject)
    /// 'vmvc': el volumen general del dispositivo, el mismo que mueven las teclas de volumen.
    private static let mainVolume = AudioObjectPropertySelector(0x766D_7663)

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = 0.5
    }

    var defaultOutputName: String { outputs.first { $0.id == defaultOutput }?.name ?? tr("Sin salida") }

    // MARK: Lectura

    func refresh() {
        defaultOutput = Self.currentDefaultOutput()
        outputs = Self.listOutputs()
        var vol = Self.address(Self.mainVolume, scope: kAudioObjectPropertyScopeOutput)
        if let v: Float32 = Self.get(defaultOutput, &vol, Float32(0)) { volume = Double(v); canSetVolume = true } else { canSetVolume = false }
        var mute = Self.address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput)
        muted = (Self.get(defaultOutput, &mute, UInt32(0)) ?? 0) != 0
    }

    func refreshApps() {
        musicVolume = Self.appVolume("Music")
        spotifyVolume = Self.appVolume("Spotify")
    }

    // MARK: Cambios

    func setVolume(_ value: Double) {
        let v = Float32(min(max(value, 0), 1))
        var addr = Self.address(Self.mainVolume, scope: kAudioObjectPropertyScopeOutput)
        if Self.set(defaultOutput, &addr, v) { volume = Double(v) }
        if v > 0, muted { setMuted(false) }
    }

    func setMuted(_ on: Bool) {
        var addr = Self.address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput)
        if Self.set(defaultOutput, &addr, UInt32(on ? 1 : 0)) { muted = on }
    }

    func selectOutput(_ id: AudioObjectID) {
        var addr = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        _ = Self.set(Self.system, &addr, id)
        refresh()
    }

    func setAppVolume(_ app: String, _ value: Double) {
        let n = Int((min(max(value, 0), 1) * 100).rounded())
        _ = Self.script("tell application \"\(app)\" to set sound volume to \(n)")
        if app == "Music" { musicVolume = value } else { spotifyVolume = value }
    }

    // MARK: CoreAudio

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func get<T>(_ object: AudioObjectID, _ address: inout AudioObjectPropertyAddress, _ initial: T) -> T? {
        guard AudioObjectHasProperty(object, &address) else { return nil }
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func set<T>(_ object: AudioObjectID, _ address: inout AudioObjectPropertyAddress, _ value: T) -> Bool {
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(object, &address), AudioObjectIsPropertySettable(object, &address, &settable) == noErr, settable.boolValue
        else { return false }
        var copy = value
        return AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<T>.size), &copy) == noErr
    }

    private static func currentDefaultOutput() -> AudioObjectID {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        return get(system, &addr, AudioObjectID(0)) ?? 0
    }

    private static func listOutputs() -> [AudioOutput] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var streams = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr, streamSize > 0 else { return nil }
            var nameAddr = address(kAudioObjectPropertyName)
            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &name) == noErr, let text = name?.takeRetainedValue() else { return nil }
            return AudioOutput(id: id, name: text as String)
        }
    }

    // MARK: Música y Spotify

    private static func appVolume(_ app: String) -> Double? {
        let bundle = app == "Music" ? "com.apple.Music" : "com.spotify.client"
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundle).isEmpty,
              let result = script("tell application \"\(app)\" to get sound volume") else { return nil }
        return Double(result.int32Value) / 100
    }

    private static func script(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}
