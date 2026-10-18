"""Publish verified component results and the closed main adapter qualification."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import shutil
import sys

BASE = Path(__file__).resolve().parents[2]
DEST = BASE / "milestones/N3R2/continuous_codegen_20261018"


def read(path):
    return json.loads(path.read_text("utf-8-sig"))


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main(component_only=False, single=False):
    global DEST
    if single:
        DEST = BASE / "milestones/N3R2/single_instance_codegen_20261018"
    DEST.mkdir(parents=True, exist_ok=True)
    published = []

    def publish(path, name):
        target = DEST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        published.append({"path": name, "sha256": sha(target)})

    fixture = BASE / "runs/N3R2_freewheel_inheritance_once"
    report = read(fixture / "report.json")
    launch = read(BASE / "runs/N3R2_freewheel_inheritance_launch.json")
    assert launch["status"] == "completed_passed" and report["all_passed"]
    assert report["normal_starts"] == 2 and report["rapid_starts"] == 1 and not report["main_model_loaded"]
    assert report["normal_comparison"]["all_passed"] and report["rapid_comparison"]["all_passed"]
    assert all(rate == [0, 0] for rate in report["compiled_sample_times"])
    assert sha(fixture / "probe_source.m.txt") == report["probe_sha256"] == launch["probe_sha256"]
    assert sha(fixture / "contract.json") == report["contract_sha256"]
    assert sha(BASE.parent / "deadtime/bridge_freewheel.m") == report["kernel_sha256"]
    assert sha(BASE.parent / "PMSM_FOC_R2026a.slx") == report["original_model_sha256"]
    for name, digest in report["raw_files"].items():
        assert sha(fixture / (name + ".mat")) == digest
    publish(fixture / "report.json", "component/report.json")
    publish(BASE / "runs/N3R2_freewheel_inheritance_launch.json", "component/launch.json")
    result = {"captured_at": datetime.now().astimezone().isoformat(), "analysis_only": True,
              "simulation_reexecuted_by_curator": False, "component_continuous_normal_equals_inherited_normal": True,
              "component_inherited_normal_equals_rapid": True, "component_logs": 13, "native_rows_each": 21601,
              "both_compiled_bridge_rates_continuous": True, "strict96_main_short_passed": False,
              "R2_passed": False, "native_root_cause_confirmed": False,
              "main_qualification_published": False}
    if single:
        fixture = BASE / "runs/N3R2_single_reference_logging_once"
        proof = read(fixture / "report.json")
        launch = read(BASE / "runs/N3R2_single_reference_logging_launch.json")
        assert launch["status"] == "completed_passed" and proof["all_passed"] and proof["comparison"]["all_passed"]
        assert proof["actual_references"] == 1 and proof["allowed_references"] == "Single"
        assert sha(fixture / "probe_source.m.txt") == proof["probe_sha256"] == launch["probe_sha256"]
        assert sha(fixture / "contract.json") == proof["contract_sha256"]
        assert sha(fixture / "normal_raw.mat") == proof["normal_raw_sha256"]
        assert sha(fixture / "rapid_raw.mat") == proof["rapid_raw_sha256"]
        publish(fixture / "report.json", "single_reference_component/report.json")
        publish(BASE / "runs/N3R2_single_reference_logging_launch.json", "single_reference_component/launch.json")
        result["single_reference_component_exact3_logs_passed"] = True
    if not component_only:
        root = BASE / ("runs/N3R2_single_instance_codegen_short_once" if single else "runs/N3R2_continuous_codegen_short_once")
        campaign = read(root / "campaign.json")
        assert campaign["status"] != "running", "Do not publish unfinished qualification."
        publish(root / "campaign.json", "main/campaign.json")
        provenance = []
        for job in campaign["jobs"]:
            folder = Path(job["folder"])
            record = read(folder / "record.json")
            for entry in record["source_files"]:
                assert sha(BASE / entry["path"]) == entry["sha256"] == sha(folder / "source" / entry["path"])
            for entry in record["contracts"]:
                assert sha(BASE / entry["path"]) == entry["sha256"] == sha(folder / entry["path"])
            item = {k: record[k] for k in ("case_id", "execution_version", "process_id", "status", "phase", "simulation_starts") if k in record}
            item["record_sha256"] = sha(folder / "record.json")
            item["source_files"] = record["source_files"]
            item["contracts"] = record["contracts"]
            for key in ("raw_sha256", "native_endpoint_verified", "layer_restored", "reference_restored", "bridge_metadata_restored", "callbacks_restored", "saved_exports_unchanged", "metrics_passed", "elapsed_s", "log_count"):
                if key in record:
                    item[key] = record[key]
            provenance.append(item)
            if job["stage"] == "build" and job["status"] == "passed":
                assert sha(folder / "handoff.mat") == record["handoff_sha256"]
                assert sha(Path(record["owned_parent_file"])) == record["exported_parent_sha256"]
                assert sha(Path(record["reference_adapter"]["child_file"])) == record["exported_child_sha256"]
                assert record["bridge_metadata_restored"] and record["reference_restored"]
            if (folder / "report.json").exists():
                execution = read(folder / "report.json")
                publish(folder / "report.json", "main/execution_report.json")
                result["last_durable_phase"] = execution.get("phase_at_error", execution["phase"])
                result["simulation_starts_requested"] = execution["simulation_starts"]
                result["full_model_bridge_compiled_sample_time"] = execution.get("bridge_compiled_sample_time")
        result["main_status"] = campaign["status"]
        result["main_qualification_published"] = True
        if campaign["status"] == "completed_passed":
            folder = Path(campaign["jobs"][1]["folder"])
            record = read(folder / "record.json")
            comparison = read(folder / "log_format/v7_complete_log_comparison.json")
            assert comparison["all_passed"] and comparison["logs"] == 96 and comparison["all_Time_Data_equal"]
            assert record["native_endpoint_verified"] and record["bridge_metadata_restored"] and record["reference_restored"]
            assert sha(folder / "signals.mat") == record["raw_sha256"]
            result["strict96_main_short_passed"] = True
            for name in ("log_format/v7_complete_log_comparison.json", "log_format_recovery.json", "metrics.json", "generated_target_inventory.json"):
                publish(folder / name, "main/" + name)
        (DEST / "main/source_provenance.json").write_bytes((json.dumps(provenance, ensure_ascii=True, indent=2)+"\n").encode())
        published.append({"path": "main/source_provenance.json", "sha256": sha(DEST / "main/source_provenance.json")})
    result["published"] = published
    (DEST / "summary.json").write_bytes((json.dumps(result, ensure_ascii=True, indent=2)+"\n").encode())
    print(json.dumps({k: result[k] for k in ("component_continuous_normal_equals_inherited_normal", "component_inherited_normal_equals_rapid", "main_qualification_published", "strict96_main_short_passed", "R2_passed")}))


if __name__ == "__main__":
    main("--component-only" in sys.argv, "--single" in sys.argv)
