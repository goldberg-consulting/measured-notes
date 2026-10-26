import Foundation

struct SpeakerTurn: Codable {
    var start: Double
    var end: Double
    var speaker: String
}

enum SpeakerAlignment {
    static func label(_ segments: [TranscriptSegment], turns: [SpeakerTurn]) -> [TranscriptSegment] {
        let turns = turns.filter { $0.start.isFinite && $0.end.isFinite && $0.end > $0.start && !$0.speaker.isEmpty }.sorted { $0.start < $1.start }
        var names: [String: String] = [:]
        for turn in turns where names[turn.speaker] == nil { names[turn.speaker] = "Speaker \(names.count + 1)" }
        return segments.enumerated().map { index, segment in
            // Preserve the user's corrections and previously assigned labels.
            guard segment.speaker.isEmpty, segment.seconds.isFinite else { return segment }
            let end = segment.endSeconds ?? (index + 1 < segments.count ? segments[index + 1].seconds : turns.last?.end ?? segment.seconds)
            guard end.isFinite, end > segment.seconds else { return segment }
            var overlaps: [String: Double] = [:]
            for turn in turns {
                let overlap = max(0, min(end, turn.end) - max(segment.seconds, turn.start))
                if overlap > 0 { overlaps[turn.speaker, default: 0] += overlap }
            }
            let ranked = overlaps.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            guard let best = ranked.first else { return segment }
            var result = segment
            let total = overlaps.values.reduce(0, +)
            result.speaker = best.value / total >= 0.8 ? names[best.key]! : "Multiple speakers"
            return result
        }
    }
}
