"""Verify and publish owned-model handoff/short evidence, without private logs."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import shutil

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / "milestones/N3R2/portable_execution_20261018"


def read(path):
    return json.loads(path.read_text("utf-8-sig"))


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    published = []

    def publish(path, relative):
        target = DEST / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        published.append({"path": relative, "sha256": sha(target)})

    def verify_build(folder, repaired=False):
        record = read(folder / "record.json")
        assert record["status"] == "passed" and record["simulation_starts"] == 0
        assert record["layer_restored"] and record["reference_restored"] and record["callbacks_restored"]
        assert sha(folder / "handoff.mat") == record["handoff_sha256"]
        parent = Path(record["owned_parent_file"])
        child = Path(record["reference_adapter"]["child_file"])
        assert sha(parent) == record["exported_parent_sha256"]
        assert sha(child) == record["exported_child_sha256"]
        for entry in record["source_files"]:
            assert sha(folder / "source" / entry["path"]) == entry["sha256"]
            if repaired and entry["path"] == "robust/portable_execution/execute_sensorless_r2_staged.m":
                continue  # Original archived executor is intentionally retained; repaired binding checked below.
            assert sha(BASE / entry["path"]) == entry["sha256"]
        for entry in record["contracts"]:
            assert sha(BASE / entry["path"]) == entry["sha256"] == sha(folder / entry["path"])
        return {"process_id": record["process_id"], "record_sha256": sha(folder / "record.json"),
                "handoff_sha256": record["handoff_sha256"], "parent_file": str(parent),
                "parent_sha256": sha(parent), "child_file": str(child), "child_sha256": sha(child),
                "source_files": record["source_files"], "contracts": record["contracts"],
                "simulation_starts": 0, "restoration_passed": True}

    handoff = BASE / "runs/N3R2_portable_model_once"
    manifest = read(handoff / "manifest.json")
    assert manifest["status"] == "completed_passed"
    proof = verify_build(handoff / "build")
    reopened = read(handoff / "reopen/report.json")
    assert reopened["all_passed"] and reopened["simulation_starts"] == 0
    assert reopened["process_id"] != proof["process_id"]
    assert sha(handoff / "reopen/probe_source.m.txt") == reopened["probe_sha256"]
    publish(handoff / "manifest.json", "handoff/manifest.json")
    publish(handoff / "reopen/report.json", "handoff/reopen_report.json")
    publish(handoff / "reopen/graph.json", "handoff/graph.json")
    (DEST / "handoff/build_provenance.json").write_bytes((json.dumps(proof, ensure_ascii=True, indent=2)+"\n").encode())
    published.append({"path": "handoff/build_provenance.json", "sha256": sha(DEST / "handoff/build_provenance.json")})

    original = BASE / "runs/N3R2_staged_short_once"
    repair = read(BASE / "robust/diagnostics/staged_preload_repair.json")
    assert sha(original / "campaign.json") == repair["retained_campaign_sha256"]
    old = read(original / "campaign.json")
    assert old["status"] == "stopped_execution_failure" and old["jobs"][1]["exit_code"] == 1
    old_execution = Path(old["jobs"][1]["folder"])
    assert not any((old_execution / name).exists() for name in
                   ("report.json", "record.json", "signals.mat", "generated_target_inventory.json"))
    staged = verify_build(original / "build", repaired=True)
    assert staged["record_sha256"] == repair["builder_record_sha256"]
    assert sha(original / "build/source" / repair["source_path"]) == repair["input_sha256"]
    assert sha(BASE / repair["source_path"]) == repair["output_sha256"]
    publish(original / "campaign.json", "staged/retained_preload_failure.json")
    publish(BASE / "robust/diagnostics/staged_preload_repair.json", "staged/preload_repair_derivation.json")

    root = BASE / "runs/N3R2_staged_preload_repair_once"
    current = read(root / "campaign.json")
    assert current["status"] != "running", "Do not publish an unfinished executor as a result."
    folder = Path(current["jobs"][0]["folder"])
    report = read(folder / "report.json")
    record = read(folder / "record.json")
    assert report["builder_process_id"] == staged["process_id"]
    assert report["process_id"] != staged["process_id"]
    assert report["probe_sha256"] == repair["output_sha256"] == sha(folder / "probe_source.m.txt")
    for entry in record["source_files"]:
        assert sha(BASE / entry["path"]) == entry["sha256"] == sha(folder / "source" / entry["path"])
    for entry in record["contracts"]:
        assert sha(BASE / entry["path"]) == entry["sha256"] == sha(folder / entry["path"])
    publish(root / "campaign.json", "staged/corrected_campaign.json")
    publish(folder / "report.json", "staged/execution_report.json")
    publish(folder / "graph.json", "staged/graph.json")
    strict = False
    known_build_incompatibility = False
    if report.get("error_identifier") == "Simulink:tools:rapidAccelBuildFailed":
        message = record.get("error", "")
        known_build_incompatibility = all(text in message for text in
            ("Simulink Coder", "Universal Bridge/续流", "连续更新"))
    if current["status"] == "completed_passed":
        comparison = read(folder / "log_format/v7_complete_log_comparison.json")
        assert comparison["all_passed"] and comparison["logs"] == 96 and comparison["all_Time_Data_equal"]
        assert record["phase"] == "completed" and record["status"] == "passed"
        assert record["native_endpoint_verified"] and record["reference_restored"] and record["layer_restored"]
        assert sha(folder / "signals.mat") == record["raw_sha256"]
        for name in ("log_format/v7_complete_log_comparison.json", "log_format_recovery.json", "metrics.json", "generated_target_inventory.json"):
            publish(folder / name, "staged/" + name)
        strict = True
    summary = {"captured_at": datetime.now().astimezone().isoformat(), "analysis_only": True,
               "simulation_reexecuted_by_curator": False, "portable_reopen_passed": True,
               "workspace_count_parent_and_child": 86, "persistent_backup_verified": True,
               "staged_builder": {k: v for k, v in staged.items() if k not in ("source_files", "contracts")},
               "retained_preload_failure_status": old["status"], "corrected_executor_status": current["status"],
               "last_durable_phase": report.get("phase_at_error", report["phase"]), "simulation_starts_requested": report["simulation_starts"],
               "continuous_bridge_codegen_incompatibility_observed": known_build_incompatibility,
               "build_incompatibility_block": "Universal Bridge/续流" if known_build_incompatibility else None,
               "strict96_short_passed": strict, "R2_passed": False, "native_root_cause_confirmed": False,
               "inherited_builder_flag_note": "record.callbacks_restored and saved_exports_unchanged belong to builder; executor proof uses report and record.callback_restored.",
               "formal_candidate_still_closed_at_passed_cases": 1, "formal_total_cases": 14,
               "published": published}
    (DEST / "summary.json").write_bytes((json.dumps(summary, ensure_ascii=True, indent=2)+"\n").encode())
    print(json.dumps({k: summary[k] for k in ("portable_reopen_passed", "corrected_executor_status", "strict96_short_passed", "R2_passed")}))


if __name__ == "__main__":
    main()
