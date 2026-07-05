# Contributing

MoonJournalKit treats binary compatibility and crash safety as public contracts.

## Workflow

1. Open an issue with a concrete storage use case and invariant.
2. Add a failing test or crash fixture before changing behavior.
3. Keep format changes separate from storage adapters.
4. Run the complete validation set.
5. Update `docs/FORMAT.md` and `CHANGELOG.md` when public behavior changes.

```bash
moon fmt --check
moon check --target all
moon test --target wasm
moon test --target wasm-gc
moon test --target js
moon run cmd/main --target js
moon run bench/main --target js
```

Do not accept bytes after the first invalid boundary and do not turn semantic
errors into replay actions merely to tolerate malformed input.
