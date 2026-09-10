# JC task 01 candidate selection

## Selected candidate

- Repository: `docker/docker-agent`
- Issue: <https://github.com/docker/docker-agent/issues/4106>
- Pull request: <https://github.com/docker/docker-agent/pull/4155>
- Base commit: `1650e9977af21a07974a5bc406dc7ec20c4c0809`
- Gold commit: `99ba4ba621c62e2c3c3422ccd2aa0d73e6cbda71`
- Owner/category/status: `JC` / `Software` / `WIP`

The issue has a concrete reproduction and more than 800 characters of detail.
The merged fix changes two production files and two corresponding Go test files,
with no dependency or lockfile churn. It was merged on 2026-09-03, after the
target model's stated training cutoff.

## Reproduced gate evidence

At the base commit, before installing the PR tests:

```text
go test ./pkg/model/provider/openai ./pkg/tools -count=1
PASS
```

After replacing only the two affected test files with their post-fix versions,
the base fails assertions covering unsupported composition keywords, recursive
`$defs`/`definitions` traversal, invalid and external `$ref` values, sibling
keywords on `$ref`, nullable optional references, and schema normalization.

At the gold commit:

```text
go test ./pkg/model/provider/openai ./pkg/tools -count=1
PASS
```

This proves a healthy base environment, a causal FAIL_TO_PASS surface, and a
passing upstream solution. Docker oracle/no-op evidence is still required for
the authored task itself.

## Why it may calibrate well

The visible symptom is a rejected strict-mode request. Several partial repairs
look reasonable: reject `oneOf`, recurse through properties only, validate a
`$ref` string without resolving its target, or normalize definitions while
adding illegal siblings to reference nodes. The full behavior crosses two
schema-processing packages and requires the post-normalization result to retain
the compatibility invariant.

## Alternatives reviewed

1. `lerd-env/lerd` PR 1687: clean Go scope and strong issue, but likely easier;
   the new test points directly at reusing existing dev-server setup logic.
2. `vllm-project/semantic-router` PR 3657: strong concurrency task, with higher
   Rust/CGO and race-test infrastructure risk.
3. `github/gh-aw` PR 59745: good semantic classification problem, but its public
   history contains more model-generated implementation detail.
4. `stacklok/toolhive` PR 6549: rejected because the merged change documents a
   residual behavior that conflicts with the linked requirement.

## Remaining gate

Do not mark the task ready for paid runs until the Docker image is pinned, the
remote/base assertions pass, the complete F2P/P2P map is frozen, oracle is
repeated successfully, no-op fails causally, adversarial mutations fail, and the
private packager/Harbor contract is available.

