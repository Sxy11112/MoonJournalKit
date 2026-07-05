## Problem

Describe the storage or recovery problem.

## Safety impact

- [ ] MWAL v1 bytes remain compatible, or a version change is documented
- [ ] Uncommitted transactions still cannot replay
- [ ] Decoder resource limits remain enforced
- [ ] Crash or corruption behavior has a regression test

## Verification

- [ ] `moon fmt --check`
- [ ] `moon check --target all`
- [ ] `moon test --target wasm`
- [ ] `moon test --target wasm-gc`
- [ ] `moon test --target js`
- [ ] Public changes are recorded in `CHANGELOG.md`
