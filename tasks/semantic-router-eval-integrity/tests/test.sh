#!/bin/bash
set -uo pipefail

OUT=/logs/verifier
mkdir -p "$OUT"
echo 0 > "$OUT/reward.txt"
cd /app || { echo "missing /app" > "$OUT/error.txt"; exit 2; }
git diff > "$OUT/model.patch" 2>/dev/null || true

python /tests/test_eval_integrity.py -v > "$OUT/f2p.txt" 2>&1
f2p_rc=$?

python -m unittest discover -s src/training/tests -p 'test_*.py' -v > "$OUT/p2p-1.txt" 2>&1
p2p1=$?
python -m unittest discover -s src/training/model_embeddings/mmbert_32k/tests -p 'test_*.py' -v > "$OUT/p2p-2.txt" 2>&1
p2p2=$?
python -m unittest discover -s src/training/model_classifier/safety_classifier/tests -p 'test_*.py' -v > "$OUT/p2p-3.txt" 2>&1
p2p3=$?

pass_count=$(grep -cE '^test_(training_pipeline_uses_disjoint_heldout_and_emits_manifest|evaluation_registry_matches_served_32k_artifacts).* ok$' "$OUT/f2p.txt" || true)
remaining=$((2-pass_count))
printf '{"f2p_total":2,"f2p_remaining":%s,"p2p_failed":%s}\n' "$remaining" "$((p2p1+p2p2+p2p3))" > "$OUT/summary.json"

if [ "$p2p1" -ne 0 ] || [ "$p2p2" -ne 0 ] || [ "$p2p3" -ne 0 ]; then
  echo "PASS_TO_PASS regression; see p2p logs" > "$OUT/error.txt"
  exit 0
fi
if [ "$f2p_rc" -ne 0 ] || [ "$remaining" -ge 1 ]; then
  echo "$remaining of 2 FAIL_TO_PASS contracts remain (>=50%); see f2p.txt" > "$OUT/error.txt"
  exit 0
fi

echo 1 > "$OUT/reward.txt"
exit 0
