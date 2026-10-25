// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

enum SourceKind: String, Codable, CaseIterable, Identifiable {
    case wallhaven, wikimedia, bing, folder, artic, nasa, picsum

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wallhaven: return tr("Wallhaven")
        case .wikimedia: return tr("Wikimedia Commons")
        case .bing: return tr("Bing del día")
        case .folder: return tr("Carpeta local")
        case .artic: return tr("Art Institute of Chicago")
        case .nasa: return tr("NASA (imágenes)")
        case .picsum: return tr("Fotos al azar (Picsum)")
        }
    }

    var needsQuery: Bool { self != .bing && self != .picsum }

    var queryPlaceholder: String {
        switch self {
        case .wallhaven: return tr("tema, ej. mountains")
        case .wikimedia: return tr("tema, ej. landscape")
        case .bing, .picsum: return ""
        case .folder: return "/ruta/a/la/carpeta"
        case .artic: return tr("tema, ej. impressionism")
        case .nasa: return tr("tema, ej. nebula")
        }
    }
}

struct SourceSpec: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: SourceKind
    var query: String
    var weight: Int
}

/// Un canal de una mezcla: apunta a otro canal y dice cuánto pesa dentro de ella.
struct ChannelMember: Codable, Identifiable, Hashable {
    var id = UUID()
    var channelID: UUID
    var weight: Int
}

struct Channel: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sources: [SourceSpec] = []
    var members: [ChannelMember] = []
    /// Una mezcla no tiene fuentes propias: reparte las fotos entre otros canales.
    var isCombo = false

    init(id: UUID = UUID(), name: String, sources: [SourceSpec] = [], members: [ChannelMember] = [], isCombo: Bool = false) {
        self.id = id; self.name = name; self.sources = sources; self.members = members; self.isCombo = isCombo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        sources = try c.decodeIfPresent([SourceSpec].self, forKey: .sources) ?? []
        members = try c.decodeIfPresent([ChannelMember].self, forKey: .members) ?? []
        isCombo = try c.decodeIfPresent(Bool.self, forKey: .isCombo) ?? false
    }
}

struct ImageCandidate: Codable, Hashable, Identifiable {
    var id: String
    var url: URL
    var source: SourceKind
    var title: String
    var author: String
    var pageURL: URL?
    var width: Int
    var height: Int
}

struct SpeedResult: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var downMbps: Double
    var upMbps: Double
    var latencyMs: Double
}

enum MenuBarMetric: String, Codable, CaseIterable, Identifiable {
    case cpu, gpu, memory, disk, network, battery, speed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return tr("Procesador")
        case .gpu: return tr("Gráficos")
        case .memory: return tr("Memoria")
        case .disk: return tr("Espacio libre en disco")
        case .network: return tr("Red en vivo")
        case .battery: return tr("Batería")
        case .speed: return tr("Velocidad de internet")
        }
    }

    var detail: String {
        switch self {
        case .cpu: return tr("Cuánto trabaja tu Mac ahora mismo")
        case .gpu: return tr("Uso de la tarjeta gráfica")
        case .memory: return tr("Porcentaje de memoria en uso")
        case .disk: return tr("Gigabytes que te quedan")
        case .network: return tr("Lo que sube y baja por segundo")
        case .battery: return tr("Carga actual")
        case .speed: return tr("Resultado de la última medición")
        }
    }

    var symbol: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "square.stack.3d.up"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "arrow.up.arrow.down"
        case .battery: return "battery.75"
        case .speed: return "speedometer"
        }
    }
}

struct SceneApplication: Codable, Identifiable, Hashable {
    var bundleIdentifier: String
    var name: String
    var id: String { bundleIdentifier }
}

enum ScenePowerTrigger: String, Codable, CaseIterable, Identifiable {
    case any, pluggedIn, battery
    var id: String { rawValue }
    var title: String {
        switch self {
        case .any: tr("No importa")
        case .pluggedIn: tr("Con corriente")
        case .battery: tr("Usando batería")
        }
    }
}

enum SceneMicrophoneAction: String, Codable, CaseIterable, Identifiable {
    case unchanged, mute, unmute
    var id: String { rawValue }
    var title: String {
        switch self {
        case .unchanged: tr("No cambiar")
        case .mute: tr("Silenciar")
        case .unmute: tr("Activar")
        }
    }
}

/// Acciones seguras que una escena puede ejecutar al entrar. Los porcentajes usan 0...100.
struct SceneActions: Codable, Equatable {
    var volume: Int?
    var screenBrightness: Int?
    var keyboardBrightness: Int?
    var microphone: SceneMicrophoneAction
    var focusMinutes: Int?
    var launchApplications: [SceneApplication]
    var openURL: String

    init(volume: Int? = nil, screenBrightness: Int? = nil, keyboardBrightness: Int? = nil,
         microphone: SceneMicrophoneAction = .unchanged, focusMinutes: Int? = nil,
         launchApplications: [SceneApplication] = [], openURL: String = "") {
        self.volume = volume; self.screenBrightness = screenBrightness; self.keyboardBrightness = keyboardBrightness
        self.microphone = microphone; self.focusMinutes = focusMinutes
        self.launchApplications = launchApplications; self.openURL = openURL
    }

    private enum CodingKeys: String, CodingKey {
        case volume, screenBrightness, keyboardBrightness, microphone, focusMinutes, launchApplications, openURL
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        volume = try c.decodeIfPresent(Int.self, forKey: .volume)
        screenBrightness = try c.decodeIfPresent(Int.self, forKey: .screenBrightness)
        keyboardBrightness = try c.decodeIfPresent(Int.self, forKey: .keyboardBrightness)
        microphone = try c.decodeIfPresent(SceneMicrophoneAction.self, forKey: .microphone) ?? .unchanged
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes)
        launchApplications = try c.decodeIfPresent([SceneApplication].self, forKey: .launchApplications) ?? []
        openURL = try c.decodeIfPresent(String.self, forKey: .openURL) ?? ""
    }

    var isEmpty: Bool {
        volume == nil && screenBrightness == nil && keyboardBrightness == nil && microphone == .unchanged
            && focusMinutes == nil && launchApplications.isEmpty && openURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct SceneActivationRecord: Codable, Equatable {
    var date = Date()
    var profileID: UUID
    var profileName: String
    var reason: String
    var automatic: Bool
}

/// Una escena completa: cambia la experiencia de faro y puede activarse por contexto.
/// Conserva los campos de los perfiles antiguos para que las configuraciones existentes migren sin perderse.
struct Profile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var symbol = "briefcase"
    var channelID: UUID?
    var intervalMinutes: Int
    var keepAwake: Bool
    var menuBarMetrics: Set<MenuBarMetric>
    var menuBarShowIcon = true
    var eyeBreak: Bool
    /// Activarse solo a cierta hora de ciertos días.
    var autoStart = false
    var days: Set<Int> = [2, 3, 4, 5, 6]   // 1 = domingo … 7 = sábado
    var hour = 8
    var minute = 0
    /// Apariencia, widgets y herramientas del notch. `nil` identifica un perfil creado por una versión anterior.
    var notch: NotchSceneSettings?
    /// Aplicaciones que activan esta escena mientras están al frente.
    var applications: [SceneApplication] = []
    /// La escena compite cuando hay al menos una pantalla externa.
    var externalDisplay = false
    /// La escena compite según la fuente de energía.
    var powerTrigger: ScenePowerTrigger = .any
    /// Entre varias coincidencias contextuales gana el número mayor.
    var priority = 50
    /// Disparadores contextuales adicionales.
    var meetingTrigger = false
    var fullScreenTrigger = false
    var bluetoothDevices: [String] = []
    var batteryBelow: Int?
    /// Acciones que se ejecutan después de aplicar la escena.
    var actions = SceneActions()

    var hasContextTrigger: Bool {
        !applications.isEmpty || externalDisplay || powerTrigger != .any || meetingTrigger || fullScreenTrigger
            || !bluetoothDevices.isEmpty || batteryBelow != nil
    }

    init(id: UUID = UUID(), name: String, symbol: String = "briefcase", channelID: UUID? = nil,
         intervalMinutes: Int, keepAwake: Bool, menuBarMetrics: Set<MenuBarMetric>, menuBarShowIcon: Bool = true,
         eyeBreak: Bool, autoStart: Bool = false, days: Set<Int> = [2, 3, 4, 5, 6], hour: Int = 8,
         minute: Int = 0, notch: NotchSceneSettings? = nil, applications: [SceneApplication] = [],
         externalDisplay: Bool = false, powerTrigger: ScenePowerTrigger = .any, priority: Int = 50,
         meetingTrigger: Bool = false, fullScreenTrigger: Bool = false,
         bluetoothDevices: [String] = [], batteryBelow: Int? = nil,
         actions: SceneActions = SceneActions()) {
        self.id = id; self.name = name; self.symbol = symbol; self.channelID = channelID
        self.intervalMinutes = intervalMinutes; self.keepAwake = keepAwake; self.menuBarMetrics = menuBarMetrics
        self.menuBarShowIcon = menuBarShowIcon; self.eyeBreak = eyeBreak; self.autoStart = autoStart
        self.days = days; self.hour = hour; self.minute = minute; self.notch = notch
        self.applications = applications; self.externalDisplay = externalDisplay
        self.powerTrigger = powerTrigger; self.priority = priority
        self.meetingTrigger = meetingTrigger; self.fullScreenTrigger = fullScreenTrigger; self.bluetoothDevices = bluetoothDevices
        self.batteryBelow = batteryBelow; self.actions = actions
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, channelID, intervalMinutes, keepAwake, menuBarMetrics, menuBarShowIcon, eyeBreak
        case autoStart, days, hour, minute, notch, applications, externalDisplay, powerTrigger, priority
        case meetingTrigger, fullScreenTrigger, bluetoothDevices, batteryBelow, actions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "briefcase"
        channelID = try c.decodeIfPresent(UUID.self, forKey: .channelID)
        intervalMinutes = try c.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? 60
        keepAwake = try c.decodeIfPresent(Bool.self, forKey: .keepAwake) ?? false
        menuBarMetrics = try c.decodeIfPresent(Set<MenuBarMetric>.self, forKey: .menuBarMetrics) ?? [.cpu, .memory]
        menuBarShowIcon = try c.decodeIfPresent(Bool.self, forKey: .menuBarShowIcon) ?? true
        eyeBreak = try c.decodeIfPresent(Bool.self, forKey: .eyeBreak) ?? false
        autoStart = try c.decodeIfPresent(Bool.self, forKey: .autoStart) ?? false
        days = try c.decodeIfPresent(Set<Int>.self, forKey: .days) ?? [2, 3, 4, 5, 6]
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 8
        minute = try c.decodeIfPresent(Int.self, forKey: .minute) ?? 0
        notch = try c.decodeIfPresent(NotchSceneSettings.self, forKey: .notch)
        applications = try c.decodeIfPresent([SceneApplication].self, forKey: .applications) ?? []
        externalDisplay = try c.decodeIfPresent(Bool.self, forKey: .externalDisplay) ?? false
        powerTrigger = try c.decodeIfPresent(ScenePowerTrigger.self, forKey: .powerTrigger) ?? .any
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 50
        meetingTrigger = try c.decodeIfPresent(Bool.self, forKey: .meetingTrigger) ?? false
        fullScreenTrigger = try c.decodeIfPresent(Bool.self, forKey: .fullScreenTrigger) ?? false
        bluetoothDevices = try c.decodeIfPresent([String].self, forKey: .bluetoothDevices) ?? []
        batteryBelow = try c.decodeIfPresent(Int.self, forKey: .batteryBelow)
        actions = try c.decodeIfPresent(SceneActions.self, forKey: .actions) ?? SceneActions()
    }
}

struct SceneHistoryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    var reason: String
    var snapshot: Profile
}

struct AppState: Codable {
    var channels: [Channel]
    var currentChannelID: UUID
    var intervalMinutes = 60
    var differentPerScreen = false
    var minResolution = 0.95
    var hidden: Set<String> = []
    var history: [ImageCandidate] = []
    var currentFiles: [String: String] = [:]
    var lastChange = Date.distantPast
    var menuBarMetrics: Set<MenuBarMetric> = [.cpu, .memory]
    var menuBarShowIcon = true
    /// Permite usar faro solo desde el notch, sin reservar espacio en la barra de menús.
    var menuBarEnabled = true
    /// Métricas visibles en la versión compacta del notch. Son independientes de la barra.
    var notchMetrics: Set<MenuBarMetric> = [.cpu, .memory]
    /// Ya se agregaron los canales de tecnología, ciencia y autos (una sola vez).
    var seededCatalog = false
    var profiles: [Profile] = []
    var activeProfileID: UUID?
    var seededProfiles = false
    var seededExtraChannels = false
    var sceneHistory: [SceneHistoryEntry] = []
    var sceneAutomationEnabled = true
    var sceneOnboardingCompleted = false
    var sceneAutomationPauseUntil: Date?
    var lastSceneActivation: SceneActivationRecord?
    var sceneAutomationVersion = 0

    init(channels: [Channel], currentChannelID: UUID) {
        self.channels = channels
        self.currentChannelID = currentChannelID
    }

    /// Tolerante: un estado guardado por una versión anterior sigue cargando aunque falten campos.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        channels = try c.decode([Channel].self, forKey: .channels)
        currentChannelID = try c.decode(UUID.self, forKey: .currentChannelID)
        intervalMinutes = try c.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? 60
        differentPerScreen = try c.decodeIfPresent(Bool.self, forKey: .differentPerScreen) ?? false
        minResolution = try c.decodeIfPresent(Double.self, forKey: .minResolution) ?? 0.95
        hidden = try c.decodeIfPresent(Set<String>.self, forKey: .hidden) ?? []
        history = try c.decodeIfPresent([ImageCandidate].self, forKey: .history) ?? []
        currentFiles = try c.decodeIfPresent([String: String].self, forKey: .currentFiles) ?? [:]
        lastChange = try c.decodeIfPresent(Date.self, forKey: .lastChange) ?? .distantPast
        menuBarMetrics = try c.decodeIfPresent(Set<MenuBarMetric>.self, forKey: .menuBarMetrics) ?? [.cpu, .memory]
        menuBarShowIcon = try c.decodeIfPresent(Bool.self, forKey: .menuBarShowIcon) ?? true
        menuBarEnabled = try c.decodeIfPresent(Bool.self, forKey: .menuBarEnabled) ?? true
        notchMetrics = try c.decodeIfPresent(Set<MenuBarMetric>.self, forKey: .notchMetrics) ?? menuBarMetrics
        seededCatalog = try c.decodeIfPresent(Bool.self, forKey: .seededCatalog) ?? false
        profiles = try c.decodeIfPresent([Profile].self, forKey: .profiles) ?? []
        activeProfileID = try c.decodeIfPresent(UUID.self, forKey: .activeProfileID)
        seededProfiles = try c.decodeIfPresent(Bool.self, forKey: .seededProfiles) ?? false
        seededExtraChannels = try c.decodeIfPresent(Bool.self, forKey: .seededExtraChannels) ?? false
        sceneHistory = try c.decodeIfPresent([SceneHistoryEntry].self, forKey: .sceneHistory) ?? []
        sceneAutomationEnabled = try c.decodeIfPresent(Bool.self, forKey: .sceneAutomationEnabled) ?? true
        sceneOnboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .sceneOnboardingCompleted) ?? false
        sceneAutomationPauseUntil = try c.decodeIfPresent(Date.self, forKey: .sceneAutomationPauseUntil)
        lastSceneActivation = try c.decodeIfPresent(SceneActivationRecord.self, forKey: .lastSceneActivation)
        sceneAutomationVersion = try c.decodeIfPresent(Int.self, forKey: .sceneAutomationVersion) ?? 0
    }

    /// Canales temáticos de fábrica y la mezcla que los junta.
    static func catalogChannels() -> [Channel] {
        func src(_ kind: SourceKind, _ query: String, _ weight: Int) -> SourceSpec {
            SourceSpec(kind: kind, query: query, weight: weight)
        }
        let tech = Channel(name: "Tecnología", sources: [
            src(.wallhaven, "futuristic technology", 40), src(.wallhaven, "cyberpunk city", 25),
            src(.wallhaven, "robot", 15), src(.wikimedia, "robot OR satellite OR rocket", 20),
        ])
        let science = Channel(name: "Ciencia", sources: [
            src(.wallhaven, "space nebula", 35), src(.wallhaven, "galaxy", 20), src(.wallhaven, "aurora", 15),
            src(.wikimedia, "nebula OR galaxy OR aurora", 20), src(.wikimedia, "microscope OR fractal", 10),
        ])
        let cars = Channel(name: "Autos", sources: [
            src(.wallhaven, "supercar", 40), src(.wallhaven, "sports car", 20), src(.wallhaven, "classic car", 15),
            src(.wikimedia, "Ferrari OR Porsche OR Lamborghini", 25),
        ])
        let mix = Channel(name: "Tecnología + Ciencia + Autos", members: [
            ChannelMember(channelID: tech.id, weight: 34), ChannelMember(channelID: science.id, weight: 33),
            ChannelMember(channelID: cars.id, weight: 33),
        ], isCombo: true)
        return [tech, science, cars, mix]
    }

    /// Agrega los canales de fábrica a un estado que todavía no los tiene y activa la mezcla.
    mutating func seedCatalogIfNeeded() {
        guard !seededCatalog else { return }
        let fresh = AppState.catalogChannels().filter { new in !channels.contains { $0.name == new.name } }
        channels += fresh
        if let mix = fresh.first(where: { $0.isCombo }) { currentChannelID = mix.id }
        seededCatalog = true
    }

    /// Canales de las fuentes más nuevas (arte, NASA y fotos al azar); se agregan una sola vez sin tocar el canal activo.
    mutating func seedExtraChannelsIfNeeded() {
        guard !seededExtraChannels else { return }
        func src(_ kind: SourceKind, _ query: String, _ weight: Int) -> SourceSpec { SourceSpec(kind: kind, query: query, weight: weight) }
        let extra = [
            Channel(name: "Arte", sources: [src(.artic, "landscape", 40), src(.artic, "impressionism", 30), src(.artic, "sea", 20)]),
            Channel(name: "Espacio", sources: [src(.nasa, "nebula", 40), src(.nasa, "galaxy", 30), src(.nasa, "earth from space", 20)]),
            Channel(name: "Al azar", sources: [src(.picsum, "", 100)]),
        ]
        channels += extra.filter { new in !channels.contains { $0.name == new.name } }
        seededExtraChannels = true
    }

    /// Crea los perfiles "Trabajo" y "Descanso" (una sola vez) con valores razonables que luego se editan.
    mutating func seedProfilesIfNeeded() {
        guard !seededProfiles, !channels.isEmpty else { return }
        let calm = channels.first { $0.name == "Naturaleza" }?.id ?? channels[0].id
        let fun = channels.first { $0.isCombo }?.id ?? channels[0].id
        profiles = [
            Profile(name: "Trabajo", symbol: "briefcase", channelID: calm, intervalMinutes: 120, keepAwake: true,
                    menuBarMetrics: [.cpu, .memory], eyeBreak: true),
            Profile(name: "Descanso", symbol: "moon.stars", channelID: fun, intervalMinutes: 15, keepAwake: false,
                    menuBarMetrics: [], eyeBreak: false),
        ]
        seededProfiles = true
    }

    static func makeDefault() -> AppState {
        let mix = Channel(name: "Naturaleza", sources: [
            SourceSpec(kind: .wallhaven, query: "nature landscape", weight: 60),
            SourceSpec(kind: .wikimedia, query: "mountain", weight: 25),
            SourceSpec(kind: .bing, query: "", weight: 15),
        ])
        let bing = Channel(name: "Bing del día", sources: [
            SourceSpec(kind: .bing, query: "", weight: 100)
        ])
        var state = AppState(channels: [mix, bing], currentChannelID: mix.id)
        state.seedCatalogIfNeeded()
        state.seedExtraChannelsIfNeeded()
        state.seedProfilesIfNeeded()
        return state
    }
}
