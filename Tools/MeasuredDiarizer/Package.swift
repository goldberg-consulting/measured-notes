// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "MeasuredDiarizer",
    platforms: [.macOS(.v15)],
    dependencies: [.package(url: "https://github.com/FluidInference/FluidAudio.git", revision: "1b0ed50d686873128a4129b3510ce3914c849bab", traits: ["Diarizer"])],
    targets: [.executableTarget(name: "MeasuredDiarizer", dependencies: [.product(name: "FluidAudio", package: "FluidAudio")])]
)
