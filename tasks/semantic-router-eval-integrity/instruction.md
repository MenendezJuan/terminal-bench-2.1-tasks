Repair two integrity failures in the model-evaluation pipeline.

The intent classifier currently derives training data and its reported evaluation from overlapping MMLU-Pro `test` rows. Reserve 20% of that split before any training sample selection, using a deterministic stratified split. Exact duplicate question text must never occur on both sides: keep one selected copy in the held-out slice and exclude its other copies from the training pool. Apply the same exclusion to supplemental training rows. Training and validation must come only from the remaining pool; final reported evaluation must run on the reserved rows.

Write `heldout_eval.json` beside the LoRA adapter with the dataset and split, fraction and seed, held-out row indices and count, and the held-out accuracy and F1. Preserve that file when producing the merged model.

The evaluation registry must also point every classifier role at the same 32K merged checkpoint and LoRA adapter that the download manifest and runtime configuration serve. Existing legacy 8K repositories still resolve, so successful loading alone is insufficient.

Keep the split and manifest logic dependency-light so it can be checked without downloading models or datasets. Do not change dependencies or fetch external data. Preserve existing public CLI behavior and unrelated training contracts.

Place that dependency-light logic in `src/training/model_classifier/classifier_model_fine_tuning_lora/heldout_split.py` and expose these interfaces:

- `reserve_heldout(texts, labels, fraction=0.2, seed=42) -> (pool_indices, heldout_indices)`
- `drop_reserved_questions(samples, heldout_texts) -> filtered_samples`
- `build_manifest(heldout_indices, metrics, dataset, split="test", fraction=0.2, seed=42) -> dict`

The returned indices must be sorted plain integers. `build_manifest` must record `dataset`, `split`, `heldout_fraction`, `seed`, `num_heldout_rows`, `heldout_row_indices`, `accuracy`, and `f1`; the metric inputs use the trainer's `eval_accuracy` and `eval_f1` keys.
