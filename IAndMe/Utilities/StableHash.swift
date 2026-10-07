import Foundation

/// A deterministic hash (FNV-1a) that is stable across launches, unlike `hashValue`.
/// Used wherever a seed must be reproducible: placeholder waveforms, sample imagery, reply variation.
enum StableHash {
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }
}
