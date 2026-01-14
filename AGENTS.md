# Repository Guidelines

## Project Structure & Module Organization
- Rust workspace root: `Cargo.toml` with many crates (e.g., `core`, `db`, `query-*`, `transaction`, `tolstoy`). Shared Rust source lives under each crate’s `src/`.
- Top-level Rust sources for the main crate are in `src/`.
- Tests: Rust integration tests in `tests/`; Swift SDK tests in `sdks/swift/Mentat/MentatTests/`.
- SDKs: `sdks/` (notably `sdks/swift/Mentat` for the Swift framework).
- Docs: `docs/` and `README.md`.
- Scripts and utilities: `scripts/` (e.g., iOS and docs helpers).

## Build, Test, and Development Commands
- `cargo build`: build the Rust workspace.
- `cargo test --all`: run Rust tests across crates.
- `cargo test --features edn/serde_support --all`: run tests with EDN serde feature.
- `./scripts/test-ios.sh`: build iOS Swift SDK + run Swift tests.
- `./scripts/cargo-doc.sh`: generate Rust docs.

## Coding Style & Naming Conventions
- Rust: use standard formatting (4-space indent), `snake_case` for functions/modules, `CamelCase` for types. Prefer `cargo fmt` and clippy defaults when applicable.
- Swift SDK: 4-space indent, `CamelCase` types, `lowerCamelCase` methods. Keep API comments aligned with existing style.
- Avoid non-ASCII unless already present in file.

## Testing Guidelines
- Rust tests live in `tests/` and crate-local `src/` modules.
- Swift tests use XCTest in `sdks/swift/Mentat/MentatTests/` (e.g., `MentatTests.swift`).
- Prefer adding or updating tests alongside behavior changes. Use `./scripts/test-ios.sh` for Swift SDK coverage.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative, and capitalized (e.g., “Fix …”, “Use …”).
- Keep commits focused; include tests or note why not run.
- PRs should include a concise summary, test results, and linked issues if relevant. Screenshots are only needed for UI-facing changes.

## Security & Configuration Tips
- iOS simulator builds require Xcode and a valid simulator runtime.
- The Swift SDK uses FFI; avoid API changes that break binary compatibility without coordination.
