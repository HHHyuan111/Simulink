"""Verify frozen N0 evidence. Does not execute or validate SMO/PLL."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def read(relative):
    return json.loads((HERE / relative).read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest = read("baseline/source_manifest.json")
    checks = []
    for entry in manifest["source_files"] + manifest["contracts"]:
        path = ROOT / entry["path"]
        checks.append((entry["path"], path.is_file() and sha(path) == entry["sha256"]))
    inventory = read("baseline/n0_inventory.json")
    logs = read("baseline/log_schema.json")
    rates = {row["path"]: row["sample_time"] for row in read("baseline/compiled_rates.json")}
    prefix = "PMSM_FOC_R2026a/"
    checks.extend([
        ("matlab_baseline_passed", inventory["status"] == "passed"),
        ("actual_worktree_model", Path(inventory["loaded_file"]).resolve() == (ROOT / "modern/PMSM_FOC_R2026a.slx").resolve()),
        ("model_file_unchanged", inventory["model_sha256_before"] == inventory["model_sha256_after"]),
        ("model_matches_fixed_reference", inventory["model_sha256_after"] == inventory["reference"]["model_sha256"]),
        ("structure_restored", inventory["structure_unchanged"]),
        ("configuration_restored", inventory["reference_state_restored"]),
        ("observer_absent", inventory["observer_installed"] is False),
        ("speed_integrator_100us", rates[prefix + "PI Controller_w/Discrete-Time\nIntegrator"] == [100e-6, 0]),
        ("d_integrator_50us", rates[prefix + "PI Controller_w1/Discrete-Time\nIntegrator"] == [50e-6, 0]),
        ("q_integrator_50us", rates[prefix + "PI Controller_w2/Discrete-Time\nIntegrator"] == [50e-6, 0]),
        ("logs_count_and_unique", len(logs) == inventory["log_count"] == len({row["name"] for row in logs})),
        ("minimum_required_logs", {"log_iabc_meas", "log_Tcm_applied", "log_UDC", "log_theta_true", "log_speed"} <= {row["name"] for row in logs}),
    ])
    raw = HERE / inventory["raw_data_relative"]
    checks.append(("local_raw_data_intact", raw.is_file() and sha(raw) == inventory["raw_data_sha256"]))
    plan = read("contracts/test_plan_v1.json")
    checks.append(("case_ids_unique", len(plan["cases"]) == len({c["id"] for c in plan["cases"]})))
    for case in plan["cases"]:
        if "window_s" in case:
            start, end = case["window_s"]
            checks.append((case["id"] + "/window", 0 <= start < end <= case["duration_s"]))
        for event in case.get("events", []):
            checks.append((case["id"] + "/event", 0 <= event["time_s"] < case["duration_s"]))
    report = {"schema": 1, "node": "N0", "all_passed": all(v for _, v in checks),
              "check_count": len(checks), "failures": [k for k, v in checks if not v],
              "source_file_count": len(manifest["source_files"]), "contract_count": len(manifest["contracts"]),
              "scenario_count": len(plan["cases"]), "baseline_log_count": len(logs),
              "scope": "N0指纹、冻结契约、实际编译速率及100ms原模型运行证据；未验收SMO/PLL"}
    (HERE / "baseline/n0_validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    if not report["all_passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
