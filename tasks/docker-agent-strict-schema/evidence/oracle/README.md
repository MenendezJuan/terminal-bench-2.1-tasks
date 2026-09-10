# oracle evidence

A real Harbor trial directory (`harbor run -p tasks/docker-agent-strict-schema
--agent oracle -e docker --force-build`), 2026-09-10, after fixing the WSL2
kernel gap that blocked network isolation (`CONFIG_NFT_FIB_INET` missing on
the old kernel, resolved by `wsl --update` to 6.18.33.2) and forcing a clean
image build (a cached broken image from an earlier interrupted build had an
empty `/app` — `--force-build` fixed it; the task itself was never the
problem).

`verifier/reward.txt` = `1`. Full agent/artifacts/verifier trial tree as
produced by Harbor, not a manual reproduction.
