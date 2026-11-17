# LucinaJS: a JavaScript engine completely rebuilt in Rust

## What it is and what it is used for

LucinaJS is a JavaScript engine written in Rust: a parser, a bytecode compiler and VM, a copying (semispace) garbage collector, and the built-ins, including `Intl`. It is the engine of LucinaNet, a browser, where it is used in place of SpiderMonkey through an embedding API (`src/js/runtime/embed`, described in `docs/embedding.md`).

Names have not been changed from the upstream project:

- The engine library is the crate `brimstone_core` (`src/js`). The command-line crate is `brimstone` (`src`) and its binary is `bs`.
- The default allocator feature is `jemalloc`. In `src/js/Cargo.toml` the dependency `tikv-jemallocator` is not optional on non-MSVC targets, and it depends on `tikv-jemalloc-sys`, which builds C code. The `jemalloc` feature only decides whether jemalloc is installed as the global allocator (`src/js/common/alloc.rs`), and `no_jemalloc` overrides it. The manifests therefore do not show that a build without default features is free of C code; the default `bs` build compiles C.
- `tests/fuzz/coverage.c` is the fuzzing shim from upstream.

## Origin

LucinaJS is a fork of [Brimstone](https://github.com/Hans-Halverson/brimstone) by Hans Halverson (MIT licence), taken at upstream commit `64d66980ce03f3c9c0a38a16d09e7fa056a1171d`. Changes made since then, each of which can be found in this tree:

- An embedding API for hosts such as a browser: `src/js/runtime/embed`, with `docs/embedding.md`.
- `Intl` built on ICU4X with baked data for the locales `en`, `da` and `it` (the default of `icu/generate_intl_data.sh`): Collator, NumberFormat, DateTimeFormat, PluralRules, ListFormat, RelativeTimeFormat, Segmenter, DisplayNames and Locale in `src/js/runtime/intrinsics/intl`; the data in `src/brimstone_intl_data` and `icu/`.
- Copying garbage collector work and a heap verifier: `src/js/runtime/gc` (`verify.rs`, `sizing.rs`, `accounting.rs`).
- WebAssembly groundwork only: engine cells and external `ArrayBuffer`s in the embed layer (`src/js/runtime/embed`, `src/js/runtime/intrinsics/array_buffer_object.rs`). This is not a WebAssembly implementation.
- A function cache with an on-disk part: `src/js/runtime/bytecode/fncache`.
- Proof inputs for the Verus tool: scripts in `verification/` and `//@` annotated files such as `src/js/runtime/bytecode/fncache/disk_rules.rs`. They are inputs to a verifier; this README makes no claim about their results.
- Browser-style `TypeError` messages that name the callee and property (snapshot tests in `tests/snapshot/error`).
- A per-test timeout in the test harness (`--test-timeout-secs`, `tests/harness/src/timeout.rs`).
- Fixes in Annex B (B.3.2 block-level function hoisting, B.3.4 if-clause functions) and in the scope and evaluation order of compound assignment.

## State

test262 results for this snapshot: not measured at this revision.

## Build, run, test

The toolchain is pinned in `rust-toolchain.toml`.

```
cargo build --release -p brimstone --bin bs
./target/release/bs script.js
```

Engine unit tests and the snapshot and Rust tests of the workspace:

```
cargo test -p brimstone_core --features annex_b,alloc_error
cargo test
```

Integration tests use the harness in `tests/harness`, run through the alias `cargo btest` (or `cargo brimstone-test`, see `.cargo/config.toml`). Fetch the test262 corpus first; the script clones tc39/test262 and checks out a pinned revision:

```
./tests/test262/install_test262.sh
cargo btest -- --reindex                          # build the test index, then run
cargo btest -- -s integration                     # first-party suite only
cargo btest -- -s test262 --ignore-unimplemented
cargo btest -- --report-test262-progress
cargo btest -- --test-timeout-secs 60 language/expressions
```

`cargo btest -- --help` lists all options. See `tests/README.md` for the suites and the ignore lists.

## Licence

MIT, see `LICENSE` (copyright Hans Halverson and LucinaNet contributors). Third-party notices, including the Unicode License v3 that covers the ICU4X baked data in `src/brimstone_intl_data` and `icu/`, are in `NOTICE`.
