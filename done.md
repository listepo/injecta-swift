# Done

### T1. Skeleton: macros, runtime, checker plugin, tests, benchmarks, docs

`@Injectable`, `@Inject`, `@Container`, `@Singleton`, `@Transient`, `@Provides`, `@Forward`; the
inline lock-free `Once` cell; `InjectaGraph` checks; `injecta-check` and `InjectaCheckPlugin`
(whole-target checks and generated `Needs` conformances); tests for the graph, the syntax reader,
macro expansions and diagnostics, runtime behaviour and docs freshness; the comparison benchmarks
against hand-written wiring, swift-dependencies, Factory and Swinject; GUIDE.md, AGENTS.md,
llms.txt.

### T6. CI

GitHub Actions (`.github/workflows/ci.yml`) runs `swift build` and `swift test` on macOS with
Xcode 27 (`runs-on: xcode-27`; `macos-latest` is the macOS 26 image and does not ship Xcode 27)
and on Linux in the `swift:6.4.0-noble` container. `swift test` includes the docs-freshness
check (`DocsTests`).
