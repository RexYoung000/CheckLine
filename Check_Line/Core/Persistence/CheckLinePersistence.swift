import Foundation
import SwiftData

enum PersistenceError: Error, Equatable, Sendable {
    case containerUnavailable
    case invalidStoredValue
}

enum CheckLinePersistence {
    static var schema: Schema {
        Schema(CheckLineSchemaV1.models)
    }

    static func liveConfiguration(schema: Schema = schema) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
    }

    static func inMemoryConfiguration(schema: Schema = schema) -> ModelConfiguration {
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = schema
        let configuration = inMemory ? inMemoryConfiguration(schema: schema) : liveConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func makeAppContainer() -> ModelContainer {
        do {
            return try makeContainer(inMemory: false)
        } catch {
            do {
                return try makeContainer(inMemory: true)
            } catch {
                preconditionFailure("CheckLine local ledger container is unavailable.")
            }
        }
    }
}

enum PersistenceCoding {
    static func encodeConversion(_ snapshot: ConversionSnapshot) throws -> Data {
        try makeEncoder().encode(snapshot)
    }

    static func decodeConversion(_ data: Data) throws -> ConversionSnapshot {
        try makeDecoder().decode(ConversionSnapshot.self, from: data)
    }

    static func encodeCoverage(_ snapshot: CoverageSnapshot) throws -> Data {
        try makeEncoder().encode(snapshot)
    }

    static func decodeCoverage(_ data: Data?) throws -> CoverageSnapshot {
        guard let data else {
            return CoverageSnapshot(sources: [])
        }
        return try makeDecoder().decode(CoverageSnapshot.self, from: data)
    }

    static func encodeMatchingPredicate(merchantEquals: String?) throws -> Data {
        try makeEncoder().encode(MatchingPredicate(merchantEquals: merchantEquals))
    }

    static func decodeMatchingPredicate(_ data: Data) throws -> String? {
        try makeDecoder().decode(MatchingPredicate.self, from: data).merchantEquals
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct MatchingPredicate: Codable, Equatable {
    var merchantEquals: String?
}
