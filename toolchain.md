# Toolchain

| Program | How to install | Why here | Source |
| --- | --- | --- | --- |
| Xcode 27 / Swift 6.4 | Mac App Store | Build, test, macros | https://developer.apple.com/xcode/ |

## SwiftPM

| Package | Where | Source | Why here |
| --- | --- | --- | --- |
| swift-syntax 604 | local | https://github.com/swiftlang/swift-syntax | Macros and the `injecta-check` parser. Measured 2026-10-08: SwiftPM 6.4 (`swiftbuild`) compiled it from source, about 194 s of a 202 s clean release build (README, "Comparison") |

## SwiftPM (Benchmarks/ only, never a library dependency)

| Package | Where | Source | Why here |
| --- | --- | --- | --- |
| swift-dependencies 1.17.1 | local | https://github.com/pointfreeco/swift-dependencies | Comparison (the version Cox pins) |
| Factory 3.4.1 | local | https://github.com/hmlongco/Factory | Comparison |
| Swinject 2.10.0 | local | https://github.com/Swinject/Swinject | Comparison |
| Resolver 1.5.1 | local | https://github.com/hmlongco/Resolver | Comparison (deprecated upstream, still shipped by apps) |
