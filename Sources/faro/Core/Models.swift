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

/// Un modo guardado: con un clic cambia fondos, pantalla despierta, barra de menú y descanso visual.
struct Profile: Codable, Identifiable, Hashable {
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
