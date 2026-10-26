import Foundation
@main struct Checks {
    static func main() throws {
        let turns = [SpeakerTurn(start: 0, end: 2, speaker: "a"), SpeakerTurn(start: 2, end: 4, speaker: "b")]
        let input = [TranscriptSegment(seconds: 0, endSeconds: 2, text: "One"), TranscriptSegment(seconds: 2, endSeconds: 4, text: "Two"), TranscriptSegment(seconds: 0, endSeconds: 4, text: "Mixed"), TranscriptSegment(seconds: 8, endSeconds: 9, text: "Unknown")]
        let result = SpeakerAlignment.label(input, turns: turns)
        precondition(result.map(\.speaker) == ["Speaker 1", "Speaker 2", "Multiple speakers", ""])
        var edited = input[0]; edited.speaker = "Eli"
        precondition(SpeakerAlignment.label([edited], turns: turns)[0] == edited)
        let legacy = Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"seconds\":0,\"speaker\":\"\",\"text\":\"Old\"}".utf8)
        let old = try JSONDecoder().decode(TranscriptSegment.self, from: legacy)
        precondition(old.endSeconds == nil)
        print("Speaker alignment checks passed")
    }
}
