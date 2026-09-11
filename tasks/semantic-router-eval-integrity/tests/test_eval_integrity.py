from __future__ import annotations

import importlib
import importlib.util
import json
import logging
import sys
import tempfile
import types
import unittest
from collections import Counter
from pathlib import Path
from unittest.mock import Mock


ROOT = Path("/app")
TRAINER = ROOT / "src/training/model_classifier/classifier_model_fine_tuning_lora/ft_linear_lora.py"
sys.path.insert(0, str(ROOT))


def install_training_stubs() -> None:
    torch = types.ModuleType("torch")
    torch.float32 = object()
    torch.norm = lambda *args, **kwargs: 0
    torch.tensor = lambda value: value
    torch.argmax = lambda value, dim=None: value
    torch.no_grad = lambda: __import__("contextlib").nullcontext()
    nn = types.ModuleType("torch.nn")
    nn.Module = object
    nn.CrossEntropyLoss = type("CrossEntropyLoss", (), {"__call__": lambda self, *a, **k: 0})
    nn.functional = types.SimpleNamespace(softmax=lambda value, dim=None: value)
    torch.nn = nn
    sys.modules["torch"] = torch
    sys.modules["torch.nn"] = nn

    datasets = types.ModuleType("datasets")
    datasets.Dataset = type("Dataset", (), {"from_dict": staticmethod(lambda value: value)})
    datasets.load_dataset = lambda *args, **kwargs: None
    sys.modules["datasets"] = datasets

    peft = types.ModuleType("peft")
    for name in ("LoraConfig", "PeftConfig", "PeftModel", "TaskType"):
        setattr(peft, name, type(name, (), {}))
    peft.get_peft_model = lambda *args, **kwargs: args[0]
    sys.modules["peft"] = peft

    sklearn = types.ModuleType("sklearn")
    metrics = types.ModuleType("sklearn.metrics")
    metrics.accuracy_score = lambda *a, **k: 0.0
    metrics.f1_score = lambda *a, **k: 0.0
    metrics.precision_recall_fscore_support = lambda *a, **k: (0, 0, 0, 0)
    model_selection = types.ModuleType("sklearn.model_selection")
    model_selection.train_test_split = lambda values, *rest, **kwargs: (
        list(values)[: max(1, len(values) // 2)],
        list(values)[max(1, len(values) // 2) :],
    ) if not rest else (
        list(values)[: max(1, len(values) // 2)],
        list(values)[max(1, len(values) // 2) :],
        list(rest[0])[: max(1, len(rest[0]) // 2)],
        list(rest[0])[max(1, len(rest[0]) // 2) :],
    )
    sys.modules.update({"sklearn": sklearn, "sklearn.metrics": metrics, "sklearn.model_selection": model_selection})

    transformers = types.ModuleType("transformers")
    for name in ("AutoModelForSequenceClassification", "AutoTokenizer", "TrainingArguments"):
        setattr(transformers, name, type(name, (), {"__init__": lambda self, *a, **k: None}))
    transformers.Trainer = type("Trainer", (), {})
    sys.modules["transformers"] = transformers

    common = types.ModuleType("common_lora_utils")
    common.setup_logging = lambda: logging.getLogger("eval-integrity-test")
    for name in (
        "clear_gpu_memory", "create_lora_config", "find_free_gpu", "get_all_gpu_info",
        "log_memory_usage", "resolve_model_path", "set_gpu_device", "validate_lora_config",
    ):
        setattr(common, name, Mock())
    sys.modules["common_lora_utils"] = common


def load_trainer_module():
    install_training_stubs()
    name = "tb_eval_integrity_trainer"
    sys.modules.pop(name, None)
    spec = importlib.util.spec_from_file_location(name, TRAINER)
    if spec is None or spec.loader is None:
        raise AssertionError(f"cannot load {TRAINER}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class EvalIntegrityContract(unittest.TestCase):
    def test_training_pipeline_uses_disjoint_heldout_and_emits_manifest(self):
        helper_path = TRAINER.with_name("heldout_split.py")
        self.assertTrue(helper_path.is_file(), "dependency-light held-out split module is missing")
        helper_spec = importlib.util.spec_from_file_location("heldout_split", helper_path)
        self.assertIsNotNone(helper_spec)
        helper = importlib.util.module_from_spec(helper_spec)
        sys.modules["heldout_split"] = helper
        assert helper_spec and helper_spec.loader
        helper_spec.loader.exec_module(helper)

        categories = ["biology", "law", "math", "other"]
        texts, labels = [], []
        for category in categories:
            for i in range(100):
                texts.append(f"{category} unique {i}")
                labels.append(category)
        first = helper.reserve_heldout(texts, labels)
        second = helper.reserve_heldout(texts, labels)
        self.assertEqual(first, second, "the reserved slice must be deterministic")
        pool, heldout = first
        self.assertFalse(set(pool) & set(heldout))
        self.assertEqual(sorted(pool + heldout), list(range(len(texts))))
        counts = Counter(labels[i] for i in heldout)
        self.assertEqual(counts, Counter({category: 20 for category in categories}))

        repeated = "Which statement is false?"
        dup_texts = texts + [repeated] * 5
        dup_labels = labels + ["law"] * 5
        pool, heldout = helper.reserve_heldout(dup_texts, dup_labels)
        self.assertEqual(sum(dup_texts[i] == repeated for i in heldout), 1)
        self.assertFalse(any(dup_texts[i] == repeated for i in pool))
        kept = helper.drop_reserved_questions(
            [(repeated, "law"), ("new supplement", "other")], [repeated]
        )
        self.assertEqual(kept, [("new supplement", "other")])

        manifest = helper.build_manifest(
            [9, 3], {"eval_accuracy": 0.75, "eval_f1": 0.5}, dataset="TIGER-Lab/MMLU-Pro"
        )
        self.assertEqual(manifest["split"], "test")
        self.assertEqual(manifest["num_heldout_rows"], 2)
        self.assertEqual(manifest["heldout_row_indices"], [9, 3])
        self.assertEqual(manifest["accuracy"], 0.75)
        self.assertEqual(manifest["f1"], 0.5)

        module = load_trainer_module()
        heldout_payload = {
            "data": [{"text": "never trained", "label": 0}],
            "row_indices": [17],
            "dataset": "TIGER-Lab/MMLU-Pro",
        }
        module.set_gpu_device = lambda **kwargs: ("cpu", None)
        module.get_all_gpu_info = lambda: []
        module.clear_gpu_memory = lambda: None
        module.log_memory_usage = lambda *args: None
        module.resolve_model_path = lambda name: name
        module.create_lora_config = lambda *args: object()
        module.create_mmlu_dataset = lambda *args: (
            [{"text": "train-a", "label": 0}, {"text": "train-b", "label": 0}],
            heldout_payload,
            {"other": 0},
            {0: "other"},
        )
        module.train_test_split = lambda values, **kwargs: (values[:1], values[1:])
        tokenizer = types.SimpleNamespace(save_pretrained=lambda path: None)
        module.create_lora_model = lambda *args: (object(), tokenizer)
        module.tokenize_data = lambda data, tokenizer: ("tokenized", tuple(item["text"] for item in data))
        module.TrainingArguments = lambda **kwargs: object()

        class FakeTrainer:
            instances = []
            def __init__(self, **kwargs):
                self.eval_dataset = kwargs["eval_dataset"]
                self.calls = []
                self.__class__.instances.append(self)
            def train(self): pass
            def save_model(self, path): pass
            def evaluate(self, eval_dataset=None):
                self.calls.append(eval_dataset)
                return {"eval_accuracy": 0.91 if eval_dataset is not None else 0.4,
                        "eval_f1": 0.82 if eval_dataset is not None else 0.3}

        module.EnhancedLoRATrainer = FakeTrainer
        with tempfile.TemporaryDirectory() as output:
            module.main(max_samples=2, output_dir=output)
            recorded = json.loads((Path(output) / "heldout_eval.json").read_text(encoding="utf-8"))
        trainer = FakeTrainer.instances[-1]
        self.assertEqual(trainer.calls[0], None, "validation evaluation must remain separate")
        self.assertEqual(trainer.calls[1], ("tokenized", ("never trained",)))
        self.assertEqual(recorded["heldout_row_indices"], [17])
        self.assertEqual(recorded["accuracy"], 0.91)
        self.assertEqual(recorded["f1"], 0.82)

    def test_evaluation_registry_matches_served_32k_artifacts(self):
        constants = importlib.import_module("src.training.model_eval.constants")
        registry = constants.MODEL_REGISTRY
        models_mk = (ROOT / "tools/make/models.mk").read_text(encoding="utf-8")
        config = (ROOT / "config/config.yaml").read_text(encoding="utf-8")
        role_to_key = {
            "feedback": "feedback_detector",
            "jailbreak": "prompt_guard",
            "fact-check": "fact_check_classifier",
            "intent": "domain_classifier",
            "pii": "pii_classifier",
        }
        self.assertEqual(set(registry), set(role_to_key))
        for role, key in role_to_key.items():
            merged = registry[role]["id"]
            adapter = registry[role]["lora_id"]
            self.assertIn("mmbert32k-", merged)
            self.assertFalse("/mmbert-" in merged)
            self.assertEqual(merged.removesuffix("-merged"), adapter.removesuffix("-lora"))
            basename = merged.split("/", 1)[1]
            self.assertIn(basename, models_mk)
            self.assertIn(f"{key}: models/{basename}", config)


if __name__ == "__main__":
    unittest.main(verbosity=2)
