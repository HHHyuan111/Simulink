"""Derive only the diagnosed single-instance metadata correction."""
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
SOURCE = BASE / "runs/N3R2_continuous_codegen_short_once/build/source/robust/continuous_codegen"
OUT = BASE / "robust/single_instance_codegen"
assert not (BASE / "runs/N3R2_single_instance_codegen_short_once").exists()
OUT.mkdir(exist_ok=True)
inputs = {}


def read(name):
    raw = (SOURCE / name).read_bytes()
    inputs[name] = hashlib.sha256(raw).hexdigest()
    assert (BASE / "robust/continuous_codegen" / name).read_bytes() == raw
    return raw.decode("utf8")


def change(value, old, new):
    assert value.count(old) == 1, old
    return value.replace(old, new)


builder = read("build_sensorless_r2_continuous.m")
executor = read("execute_sensorless_r2_continuous.m")
builder = change(builder, "function record=build_sensorless_r2_continuous", "function record=build_sensorless_r2_single_instance")
builder = change(builder, "record=sensorless_r2_continuous_snapshot(folder)", "record=sensorless_r2_single_instance_snapshot(folder)")
builder = change(builder, " save_system(child,record.reference_adapter.child_file);record.reference_adapter.child_model_sha256=", """ references=find_system(mdl,'LookUnderMasks','all','BlockType','ModelReference','ModelName',child);assert(numel(references)==1);
 set_param(child,'ModelReferenceNumInstancesAllowed','Single');
 record.reference_instance_policy=struct('allowed','Single','actual_count',numel(references));
 save_system(child,record.reference_adapter.child_file);record.reference_adapter.child_model_sha256=""")
executor = change(executor, "function report=execute_sensorless_r2_continuous", "function report=execute_sensorless_r2_single_instance")
executor = change(executor, "'kind','continuous_inherited_codegen_adapter'", "'kind','single_instance_continuous_codegen_adapter'")
executor = change(executor, " report.compile_requested=true;stage('prepare_continuous_codegen');", """ references=find_system(mdl,'LookUnderMasks','all','BlockType','ModelReference','ModelName',child);
 report.single_reference_metadata_verified=numel(references)==1&&strcmp(get_param(child,'ModelReferenceNumInstancesAllowed'),'Single');assert(report.single_reference_metadata_verified);
 report.compile_requested=true;stage('prepare_continuous_codegen');""")
executor = change(executor, "'.build','continuous_codegen'", "'.build','single_instance_codegen'")
for name in ("builder", "executor"):
    value = locals()[name]
    value = change(value, "'sensorless/robust/continuous_codegen','teaching'", "'sensorless/robust/continuous_codegen','sensorless/robust/single_instance_codegen','teaching'")
    if name == "builder":
        builder = value
    else:
        executor = value
outputs = {"build_sensorless_r2_single_instance.m": builder, "execute_sensorless_r2_single_instance.m": executor}
for name, value in outputs.items():
    (OUT / name).write_bytes(value.encode("utf8"))
record = {"schema": 1, "inputs_from_archived_builder": inputs,
          "outputs_sha256": {name: hashlib.sha256(value.encode()).hexdigest() for name, value in outputs.items()},
          "contract": "contracts/nonideal_r2_single_instance_codegen_adaptation.json",
          "changes": ["New names, paths, source map and version binding.",
                      "Declare and persist Single, assert actual one reference; assert persisted metadata before compile.",
                      "No change to simulation, physical parameters/functions, sampling, solver, logging, restoration or comparison."]}
(OUT / "derivation.json").write_bytes((json.dumps(record, indent=2)+"\n").encode())
print(json.dumps(record))
