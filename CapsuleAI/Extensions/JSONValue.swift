//
//  JSONValue.swift
//  CapsuleAI
//

import Foundation

/// Peut encoder/décoder n'importe quelle valeur JSON (colonnes JSONB Supabase)
enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case object([String: JSONValue])
    case array([JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let i = try? container.decode(Int.self) { self = .int(i); return }
        if let d = try? container.decode(Double.self) { self = .double(d); return }
        if let b = try? container.decode(Bool.self) { self = .bool(b); return }
        if let o = try? container.decode([String: JSONValue].self) { self = .object(o); return }
        if let a = try? container.decode([JSONValue].self) { self = .array(a); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "JSONValue: type non géré")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        }
    }

    var jsonString: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: toFoundation), let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    private var toFoundation: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .null: return NSNull()
        case .object(let o): return Dictionary(uniqueKeysWithValues: o.map { ($0.key, $0.value.toFoundation) })
        case .array(let a): return a.map(\.toFoundation)
        }
    }

    /// Crée un JSONValue depuis du JSON brut (Data) — pour contenu Tiptap
    static func from(data: Data) -> JSONValue? {
        // Essayer d'abord via JSONSerialization (plus tolérant aux cas limites JS)
        if let any = try? JSONSerialization.jsonObject(with: data),
           let v = from(any: any) {
            return v
        }
        return (try? JSONDecoder().decode(JSONValue.self, from: data))
    }

    /// Crée un JSONValue depuis Any (output de JSONSerialization.jsonObject)
    static func from(any: Any) -> JSONValue? {
        switch any {
        case is NSNull:
            return .null
        case let s as String:
            return .string(s)
        case let i as Int:
            return .int(i)
        case let d as Double:
            return .double(d)
        case let f as Float:
            return .double(Double(f))
        case let b as Bool:
            return .bool(b)
        case let arr as [Any]:
            let mapped = arr.compactMap { from(any: $0) }
            return mapped.count == arr.count ? .array(mapped) : nil
        case let dict as [String: Any]:
            var obj: [String: JSONValue] = [:]
            for (k, v) in dict {
                guard let jv = from(any: v) else { return nil }
                obj[k] = jv
            }
            return .object(obj)
        case let n as NSNumber:
            if n.doubleValue.truncatingRemainder(dividingBy: 1) == 0,
               let i = Int(exactly: n.int64Value) {
                return .int(i)
            }
            return .double(n.doubleValue)
        default:
            return nil
        }
    }

    /// Extrait le texte brut d'un document Tiptap (doc JSON)
    var tiptapPlainText: String {
        var parts: [String] = []
        func collect(_ v: JSONValue) {
            switch v {
            case .string(let s): if !s.isEmpty { parts.append(s) }
            case .array(let a): a.forEach { collect($0) }
            case .object(let o):
                if let text = o["text"], case .string(let s) = text, !s.isEmpty {
                    parts.append(s)
                }
                o.values.forEach { collect($0) }
            default: break
            }
        }
        collect(self)
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
