// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import IOKit

/// Lectura (solo lectura) de los ventiladores a través del SMC, el controlador de energía y temperatura del Mac.
/// No escribe nada ni necesita permisos de administrador.
struct Fan: Identifiable, Equatable {
    var index: Int
    var rpm: Double
    var minimum: Double
    var maximum: Double
    var id: Int { index }

    /// 0...1 entre el mínimo y el máximo del ventilador.
    var load: Double {
        guard maximum > minimum else { return 0 }
        return min(max((rpm - minimum) / (maximum - minimum), 0), 1)
    }
}

enum FanReader {
    // Estructura que espera el SMC. Los tamaños y desplazamientos replican la de C (80 bytes).
    private struct Version { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0, release: UInt16 = 0 }
    private struct PLimit { var version: UInt16 = 0, length: UInt16 = 0, cpu: UInt32 = 0, gpu: UInt32 = 0, mem: UInt32 = 0 }
    private struct KeyInfo { var dataSize: UInt32 = 0, dataType: UInt32 = 0, attributes: UInt8 = 0, pad0: UInt8 = 0, pad1: UInt8 = 0, pad2: UInt8 = 0 }
    private struct Param {
        var key: UInt32 = 0
        var version = Version()
        var pLimit = PLimit()
        var keyInfo = KeyInfo()
        var result: UInt8 = 0, status: UInt8 = 0, command: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
    }

    private static func code(_ text: String) -> UInt32 { text.utf8.reduce(0) { $0 << 8 | UInt32($1) } }

    private static func call(_ connection: io_connect_t, _ input: Param) -> Param? {
        var input = input, output = Param()
        var size = MemoryLayout<Param>.size
        let result = IOConnectCallStructMethod(connection, 2, &input, MemoryLayout<Param>.size, &output, &size)
        return result == KERN_SUCCESS && output.result == 0 ? output : nil
    }

    /// Valor numérico de una clave del SMC (tipos `flt `, `ui8 `, `fpe2`...).
    private static func read(_ key: String, on connection: io_connect_t) -> Double? {
        var info = Param(); info.key = code(key); info.command = 9
        guard let described = call(connection, info) else { return nil }
        var request = Param(); request.key = code(key); request.keyInfo.dataSize = described.keyInfo.dataSize; request.command = 5
        guard let answer = call(connection, request) else { return nil }
        let bytes = withUnsafeBytes(of: answer.bytes) { Array($0.prefix(Int(described.keyInfo.dataSize))) }
        return decode(bytes, type: described.keyInfo.dataType)
    }

    /// Decodifica los bytes según el tipo (`flt ` en Apple Silicon, `fpe2` en los Mac con Intel).
    static func decode(_ bytes: [UInt8], type: UInt32) -> Double? {
        switch type {
        case code("flt ") where bytes.count >= 4:
            return Double(Float(bitPattern: UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24))
        case code("ui8 ") where bytes.count >= 1: return Double(bytes[0])
        case code("ui16") where bytes.count >= 2: return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case code("fpe2") where bytes.count >= 2: return Double((Int(bytes[0]) << 6) + (Int(bytes[1]) >> 2))
        default: return nil
        }
    }

    /// Los ventiladores del Mac. Vacío si no tiene (MacBook Air) o si el SMC no responde.
    static func read() -> [Fan] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return [] }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return [] }
        defer { IOServiceClose(connection) }
        guard let count = read("FNum", on: connection), count >= 1 else { return [] }
        return (0..<min(Int(count), 4)).compactMap { i in
            guard let rpm = read("F\(i)Ac", on: connection) else { return nil }
            return Fan(index: i, rpm: rpm, minimum: read("F\(i)Mn", on: connection) ?? 0, maximum: read("F\(i)Mx", on: connection) ?? 0)
        }
    }
}
