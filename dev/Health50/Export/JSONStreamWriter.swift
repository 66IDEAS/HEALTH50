import Foundation

/// Writes JSON straight to a file, so an export never has to fit into memory.
///
/// The caller drives the structure (`beginObject`, `key`, `string`, ...). Commas are handled here.
/// `newline()` only adds a line break for readability; it has no meaning in JSON.
final class JSONStreamWriter {
    private let handle: FileHandle
    private var buffer: [UInt8] = []
    private var needsComma: [Bool] = [false]
    private var afterKey = false
    private var pendingNewline = false
    private(set) var bytesWritten: Int64 = 0
    /// First write error, for example a full disk. Reported by `close()`.
    private var failure: Error?

    private static let flushSize = 1 << 18

    init(url: URL) throws {
        let created = FileManager.default.createFile(
            atPath: url.path,
            contents: nil,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        guard created else { throw CocoaError(.fileWriteUnknown) }
        handle = try FileHandle(forWritingTo: url)
        buffer.reserveCapacity(Self.flushSize + 4096)
    }

    // MARK: Structure

    func beginObject() { prefix(); put(0x7B); needsComma.append(false) }
    func endObject() { breakLine(); needsComma.removeLast(); put(0x7D) }
    func beginArray() { prefix(); put(0x5B); needsComma.append(false) }
    func endArray() { breakLine(); needsComma.removeLast(); put(0x5D) }

    func key(_ name: String) {
        if needsComma[needsComma.count - 1] { put(0x2C) }
        needsComma[needsComma.count - 1] = true
        breakLine()
        putString(name)
        put(0x3A)
        afterKey = true
    }

    /// Line break before the next element, key or closing bracket. Purely cosmetic.
    func newline() {
        if !afterKey { pendingNewline = true }
    }

    private func breakLine() {
        if pendingNewline { pendingNewline = false; put(0x0A) }
    }

    // MARK: Values

    func string(_ value: String) { prefix(); putString(value) }
    func int(_ value: Int) { prefix(); putASCII(String(value)) }
    func bool(_ value: Bool) { prefix(); putASCII(value ? "true" : "false") }
    func null() { prefix(); putASCII("null") }

    func number(_ value: Double) {
        prefix()
        guard value.isFinite else { putASCII("null"); return }
        if value == value.rounded(), abs(value) < 1e15 {
            putASCII(String(Int64(value)))
        } else {
            putASCII("\(value)")
        }
    }

    /// ISO 8601 in UTC with second precision, for example 2026-11-05T05:58:12Z.
    func date(_ value: Date) { prefix(); put(0x22); putASCII(Self.iso(value)); put(0x22) }

    /// Any value found in HealthKit metadata.
    func any(_ value: Any) {
        switch value {
        case let v as String: string(v)
        case let v as Date: date(v)
        case let v as NSNumber:
            if CFGetTypeID(v) == CFBooleanGetTypeID() { bool(v.boolValue) } else { number(v.doubleValue) }
        case let v as [String: Any]:
            beginObject()
            for k in v.keys.sorted() { key(k); any(v[k]!) }
            endObject()
        case let v as [Any]:
            beginArray()
            for item in v { any(item) }
            endArray()
        default: string(String(describing: value))
        }
    }

    // MARK: Convenience

    func field(_ name: String, _ value: String) { key(name); string(value) }
    func field(_ name: String, _ value: Int) { key(name); int(value) }
    func field(_ name: String, _ value: Double) { key(name); number(value) }
    func field(_ name: String, _ value: Bool) { key(name); bool(value) }
    func field(_ name: String, _ value: Date) { key(name); date(value) }

    func close() throws {
        flushKeepingError()
        try? handle.close()
        if let failure { throw failure }
    }

    // MARK: Internals

    private func prefix() {
        if afterKey { afterKey = false; return }
        if needsComma[needsComma.count - 1] { put(0x2C) }
        needsComma[needsComma.count - 1] = true
        breakLine()
    }

    private func put(_ byte: UInt8) {
        buffer.append(byte)
        if buffer.count >= Self.flushSize { flushKeepingError() }
    }

    private func putASCII(_ text: String) {
        buffer.append(contentsOf: text.utf8)
        if buffer.count >= Self.flushSize { flushKeepingError() }
    }

    private func putString(_ text: String) {
        buffer.append(0x22)
        for byte in text.utf8 {
            switch byte {
            case 0x22: buffer.append(0x5C); buffer.append(0x22)
            case 0x5C: buffer.append(0x5C); buffer.append(0x5C)
            case 0x0A: buffer.append(0x5C); buffer.append(0x6E)
            case 0x0D: buffer.append(0x5C); buffer.append(0x72)
            case 0x09: buffer.append(0x5C); buffer.append(0x74)
            case 0x00..<0x20:
                buffer.append(contentsOf: "\\u00".utf8)
                let hex = Array("0123456789abcdef".utf8)
                buffer.append(hex[Int(byte >> 4)])
                buffer.append(hex[Int(byte & 0x0F)])
            default: buffer.append(byte)
            }
        }
        buffer.append(0x22)
        if buffer.count >= Self.flushSize { flushKeepingError() }
    }

    private func flushKeepingError() {
        do { try flush() } catch {
            if failure == nil { failure = error }
            buffer.removeAll(keepingCapacity: true)
        }
    }

    private func flush() throws {
        guard !buffer.isEmpty else { return }
        try handle.write(contentsOf: Data(buffer))
        bytesWritten += Int64(buffer.count)
        buffer.removeAll(keepingCapacity: true)
    }

    static func iso(_ date: Date) -> String {
        var seconds = time_t(date.timeIntervalSince1970.rounded(.down))
        var parts = tm()
        gmtime_r(&seconds, &parts)
        func two(_ n: Int32) -> String { n < 10 ? "0\(n)" : "\(n)" }
        let year = parts.tm_year + 1900
        return "\(year)-\(two(parts.tm_mon + 1))-\(two(parts.tm_mday))T\(two(parts.tm_hour)):\(two(parts.tm_min)):\(two(parts.tm_sec))Z"
    }
}
