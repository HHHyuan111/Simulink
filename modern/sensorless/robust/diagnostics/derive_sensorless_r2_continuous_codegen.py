"""Assert mechanical derivation for the separately preregistered bridge adapter."""
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
OUT = BASE / "robust/continuous_codegen"
ARCHIVE = BASE / "runs/N3R2_staged_short_once/build/source/robust/portable_execution"
assert not (BASE / "runs/N3R2_continuous_codegen_short_once").exists()
OUT.mkdir(exist_ok=True)
inputs = {}


def source(name):
    p = ARCHIVE / name
    raw = p.read_bytes()
    inputs[name] = hashlib.sha256(raw).hexdigest()
    return raw.decode("utf8")


def change(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)


builder = source("build_sensorless_r2_staged.m")
builder = change(builder, "function record=build_sensorless_r2_staged", "function record=build_sensorless_r2_continuous")
builder = change(builder, "record=sensorless_r2_staged_snapshot(folder)", "record=sensorless_r2_continuous_snapshot(folder)")
builder = change(builder, " configured=teach_snapshot(mdl);", " bridgeBackup=sensorless_r2_bridge_codegen('apply',mdl);record.bridge_adaptation=bridgeBackup;\n configured=teach_snapshot(mdl);")
builder = change(builder, "'dynamic',dynamic,'pwm',pwm,'plant',plant);", "'dynamic',dynamic,'pwm',pwm,'plant',plant,'bridgeBackup',bridgeBackup);")
builder = change(builder, " set_param(mdl,'InitFcn',originalInit);if ~isempty(dynamic)", " record.bridge_metadata_restored=sensorless_r2_bridge_codegen('restore',mdl,bridgeBackup);assert(record.bridge_metadata_restored);\n set_param(mdl,'InitFcn',originalInit);if ~isempty(dynamic)")
builder = change(builder, "'sensorless/robust/portable_execution','teaching'", "'sensorless/robust/portable_execution','sensorless/robust/continuous_codegen','teaching'")

executor = source("execute_sensorless_r2_staged.m")
executor = change(executor, "function report=execute_sensorless_r2_staged", "function report=execute_sensorless_r2_continuous")
executor = change(executor, "'sensorless/robust/portable_execution','teaching'", "'sensorless/robust/portable_execution','sensorless/robust/continuous_codegen','teaching'")
executor = change(executor, "for k=1:numel(record.contracts),copyfile(fullfile(buildFolder,record.contracts(k).path),fullfile(folder,record.contracts(k).path));end", """for k=1:numel(record.contracts)
 target=fullfile(folder,record.contracts(k).path);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(buildFolder,record.contracts(k).path),target);
end
record.builder_proof=struct('layer_restored',buildRecord.layer_restored,'reference_restored',buildRecord.reference_restored,...
 'callbacks_restored',buildRecord.callbacks_restored,'saved_exports_unchanged',buildRecord.saved_exports_unchanged,'bridge_metadata_restored',buildRecord.bridge_metadata_restored);
record.layer_restored=false;record.reference_restored=false;record.callback_restored=false;record.callbacks_restored=false;
record.saved_exports_unchanged=false;record.bridge_metadata_restored=false;record.native_endpoint_verified=false;record.metrics_passed=false;
sensorless_v2_guard_sources(record);""")
executor = change(executor, "'kind','portable_staged_execution'", "'kind','continuous_inherited_codegen_adapter'")
executor = change(executor, " report.compile_requested=true;stage('build_generated_target_once');", " report.bridge_adaptation_verified=sensorless_r2_bridge_codegen('verify',mdl,state.bridgeBackup);assert(report.bridge_adaptation_verified);\n report.compile_requested=true;stage('prepare_continuous_codegen');")
executor = change(executor, "'.build','staged_execution'", "'.build','continuous_codegen'")
executor = change(executor, " rtp=Simulink.BlockDiagram.buildRapidAcceleratorTarget(mdl);", """ report.normal_compile_pairs_requested=1;stage('verify_actual_continuous_rate');
 feval(mdl,[],[],[],'compile');terminate=onCleanup(@()feval(mdl,[],[],[],'term'));
 report.bridge_compiled_sample_time=get_param([mdl '/Universal Bridge/续流'],'CompiledSampleTime');assert(isequal(report.bridge_compiled_sample_time,[0 0]));
 clear terminate;
 assert(isequaln(state.parentWorkspace,values(ws))&&isequaln(state.childWorkspace,values(childWs)));
 stage('build_generated_target_once');
 rtp=Simulink.BlockDiagram.buildRapidAcceleratorTarget(mdl);""")
executor = change(executor, " set_param(mdl,'InitFcn',state.originalInit);if ~isempty(state.dynamic)", " record.bridge_metadata_restored=sensorless_r2_bridge_codegen('restore',mdl,state.bridgeBackup);assert(record.bridge_metadata_restored);\n set_param(mdl,'InitFcn',state.originalInit);if ~isempty(state.dynamic)")
executor = change(executor, " record.layer_restored=report.layer_restored;", " record.saved_exports_unchanged=report.files_unchanged;record.callbacks_restored=strcmp(get_param(mdl,'InitFcn'),state.originalInit);\n record.layer_restored=report.layer_restored;")
executor = change(executor, "'no_graph_construction_in_executor',true", "'no_graph_construction_in_executor',true,'continuous_bridge_inheritance_verified',true")

outputs = {"build_sensorless_r2_continuous.m": builder, "execute_sensorless_r2_continuous.m": executor}
for name, value in outputs.items():
    (OUT / name).write_bytes(value.encode("utf8"))
record = {"schema": 1, "inputs_from_archived_builder": inputs,
          "outputs_sha256": {name: hashlib.sha256(value.encode("utf8")).hexdigest() for name, value in outputs.items()},
          "contract": "contracts/nonideal_r2_continuous_codegen_adaptation.json",
          "changes": ["New entry names and snapshot/path/version binding.",
                      "Owned bridge activation adaptation, independent verification, explicit continuous-rate compile and actual metadata restoration.",
                      "Complete parent-directory creation and fresh execution-only flags before loading.",
                      "All existing case stimulus, observer/frontend/math, save/archive/endpoint/metric statements retained."]}
(OUT / "derivation.json").write_bytes((json.dumps(record, ensure_ascii=True, indent=2)+"\n").encode())
print(json.dumps(record))
