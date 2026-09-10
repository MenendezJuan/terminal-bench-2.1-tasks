# JC candidate 6 selection: Floci Kinesis concurrency

## Candidate

- Repository: `floci-io/floci`
- Pull request: https://github.com/floci-io/floci/pull/3000
- Sealed base: `1f87f7c48238a5adbaa278a575eb215bab25769d`
- Gold merge: `73deb13c01dbde2c17ff9b3a3045ab8856d6465d`
- Scope: six production files and six test files; no dependency or lockfile changes
- Status: offline acceptance gate in progress; no paid runs

## Why it is promising

The reported symptom is silent loss of committed DynamoDB CDC records. The state path crosses forwarding, sequence allocation, shard selection, append, persistence, stream deletion, and shard topology changes. A solver can protect only the append path and appear to fix the headline symptom while leaving deletion resurrection, WAL recovery, pagination, or post-commit error semantics broken.

This is a causal hypothesis, not a claim of calibrated difficulty.

## Pre-registered scoring units

1. **Accepted-record durability and order:** concurrent CDC and direct writes are retained, ordered coherently, and survive WAL reload.
2. **Lifecycle non-resurrection:** delete wins over in-flight append and representative metadata updates; stale writers cannot recreate a deleted stream.
3. **Reshard read consistency:** readers and pagination see a valid snapshot; split children are unique and topology is published completely.
4. **Forwarding failure semantics:** forwarding loss is observable, but failure after a source commit does not become a false request failure; TTL persistence continues.

Each gate needs deterministic diagnostic leaf tests. The grouping is valid only if the delivery contract permits semantic scoring units.

## Verifier constraint

Do not copy the upstream tests verbatim. Some use gold-only hooks/helpers and others use probabilistic stress loops. Build mechanism-neutral tests through existing service APIs and injectable storage boundaries. Stress tests may remain non-scored diagnostics. A non-gold alternative synchronization/snapshot design must pass.

## Pre-registered mutations

- Synchronize only the record list.
- Lock append without re-resolving live stream state.
- Leave one metadata path outside lifecycle coordination.
- Use copy-on-write topology with live sub-list pagination.
- Generate unique child IDs but publish children sequentially.
- Snapshot pagination while retaining unsafe topology iteration.
- Log forwarding errors without observable counting.
- Rethrow a forwarding error after the source write committed.
- Persist outside the ordering boundary.

## Rejection conditions

Drop before spend if we cannot create at least two deterministic behavior-only base failures, if a valid alternative is rejected, if failures depend on timing, if tests require gold-only APIs, or if the contract disallows the natural scoring units.
