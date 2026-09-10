# Docker Agent Strict Schema Compatibility

## Overview

This task reproduces a schema-conversion defect from `docker/docker-agent` issue
#4106 and PR #4155 at base commit `1650e997`. MCP tool schemas could be marked
compatible with OpenAI strict mode even when unsupported constructs were nested
outside the converter's limited walk. Normalization could also add invalid
constraints beside references.

## Skills Tested

- Traversing heterogeneous recursive JSON Schema containers consistently
- Validating local JSON Pointers, including escaping and invalid targets
- Separating compatibility decisions from normalization
- Preserving reference, composition, nullable and ordinary-object semantics

## Environment

- Base image: `golang:1.27-bookworm`
- Repository sealed at `base_commit` with its git remote removed
- Resources: 2 CPUs, 4096 MB memory, 10240 MB storage
- Internet disabled during the agent phase
- Working directory: `/app`
- No OpenAI credential or live API request is needed

## Difficulty

Estimated hard until calibration runs are complete. The visible failure suggests adding checks for `oneOf`, but that only fixes one
surface. A complete repair must use the same recursive schema coverage for
eligibility and normalization, validate references without looping through
recursive definitions, preserve supported `anyOf`, and avoid making optional
reference wrappers non-nullable or unsatisfiable. Several locally plausible fixes pass
the simple reproduction while failing one of those interactions.

## Solution

`solution/solve.sh` applies the two production-file changes from upstream PR
#4155. It modifies `pkg/model/provider/openai/schema.go` and
`pkg/tools/schema.go`; it does not modify dependency files or install packages.

## Verification

The verifier copies two task-owned Go test files into the corresponding package
directories under fresh names and runs both complete native package suites with
`go test -json`. The tests exercise public conversion behavior and package-local
compatibility helpers without any live service.

Reward requires a clean test run, a minimum collected-test count, and every
critical task test name. This prevents an empty collection, renamed test files,
or a partial implementation from scoring as success. The floor and final
FAIL_TO_PASS/PASS_TO_PASS split are populated from base and oracle control runs.

## Relevant experience

This task is natural for engineers who have implemented schema validators,
serializers, compilers or recursive AST visitors. The transferable skill is
maintaining one semantic contract across traversal, validation and
normalization while handling cycles and reference indirection safely.
