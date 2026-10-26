import Foundation
import FluidAudio

struct Turn: Encodable {
    let start: Double
    let end: Double
    let speaker: String
}

@main struct Diarizer {
    static func main() async {
        do {
            guard CommandLine.arguments.count == 3 else { throw NSError(domain: "MeasuredDiarizer", code: 1) }
            let manager = OfflineDiarizerManager(config: OfflineDiarizerConfig())
            try await manager.prepareModels()
            let result = try await manager.process(URL(fileURLWithPath: CommandLine.arguments[1]))
            let turns = result.segments.map { Turn(start: Double($0.startTimeSeconds), end: Double($0.endTimeSeconds), speaker: $0.speakerId) }
            try JSONEncoder().encode(turns).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
}
