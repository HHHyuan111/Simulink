"""Narrow code generation to the actual observer; retain original parent."""
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
ARCHIVE = BASE / "runs/N3R2_staged_short_once/build/source/robust/portable_execution"
OUT = BASE / "robust/observer_codegen"
assert not (BASE / "runs/N3R2_observer_codegen_short_once").exists()
OUT.mkdir(exist_ok=True)
inputs = {}


def read(path):
    raw = path.read_bytes()
    inputs[str(path.relative_to(BASE)).replace('\\', '/')] = hashlib.sha256(raw).hexdigest()
    return raw.decode("utf8")


def change(value, old, new):
    assert value.count(old) == 1, old
    return value.replace(old, new)


bridge = """
function value=bridge_metadata(mdl)
rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/Universal Bridge/续流']);assert(isscalar(c));
value=struct('update',c.ChartUpdate,'sample_time',c.SampleTime,'script',c.Script);
end
"""
builder = read(ARCHIVE / "build_sensorless_r2_staged.m")
builder = change(builder, "function record=build_sensorless_r2_staged", "function record=build_sensorless_r2_observer_codegen")
builder = change(builder, "record=sensorless_r2_staged_snapshot(folder)", "record=sensorless_r2_observer_codegen_snapshot(folder)")
builder = change(builder, " configured=teach_snapshot(mdl);", " bridgeOriginal=bridge_metadata(mdl);assert(strcmp(bridgeOriginal.update,'CONTINUOUS'));\n configured=teach_snapshot(mdl);")
builder = change(builder, " save_system(child,record.reference_adapter.child_file);record.reference_adapter.child_model_sha256=", """ references=find_system(mdl,'LookUnderMasks','all','BlockType','ModelReference','ModelName',child);assert(numel(references)==1);
 set_param(child,'ModelReferenceNumInstancesAllowed','Single');set_param(references{1},'SimulationMode','Accelerator');
 record.execution_boundary=struct('parent','Normal','child','Accelerator','allowed_instances','Single','actual_instances',1);
 save_system(child,record.reference_adapter.child_file);record.reference_adapter.child_model_sha256=""")
builder = builder.replace('check_sensorless_r2_generated_graph(', 'check_sensorless_r2_observer_codegen_graph(')
builder = change(builder, "'dynamic',dynamic,'pwm',pwm,'plant',plant);", "'dynamic',dynamic,'pwm',pwm,'plant',plant,'bridgeOriginal',bridgeOriginal);")
builder = change(builder, " record.callbacks_restored=", " record.main_bridge_preserved=isequaln(bridgeOriginal,bridge_metadata(mdl));assert(record.main_bridge_preserved);\n record.callbacks_restored=")
builder += bridge

executor = read(ARCHIVE / "execute_sensorless_r2_staged.m")
executor = change(executor, "function report=execute_sensorless_r2_staged", "function report=execute_sensorless_r2_observer_codegen")
executor = change(executor, "for k=1:numel(record.contracts),copyfile(fullfile(buildFolder,record.contracts(k).path),fullfile(folder,record.contracts(k).path));end", """for k=1:numel(record.contracts)
 target=fullfile(folder,record.contracts(k).path);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(buildFolder,record.contracts(k).path),target);
end
record.builder_proof=struct('layer_restored',buildRecord.layer_restored,'reference_restored',buildRecord.reference_restored,...
 'callbacks_restored',buildRecord.callbacks_restored,'saved_exports_unchanged',buildRecord.saved_exports_unchanged,'main_bridge_preserved',buildRecord.main_bridge_preserved);
record.layer_restored=false;record.reference_restored=false;record.callback_restored=false;record.callbacks_restored=false;
record.saved_exports_unchanged=false;record.main_bridge_preserved=false;record.native_endpoint_verified=false;record.metrics_passed=false;
sensorless_v2_guard_sources(record);""")
executor = change(executor, "'kind','portable_staged_execution'", "'kind','normal_parent_accelerated_observer'")
executor = executor.replace('check_sensorless_r2_generated_graph(', 'check_sensorless_r2_observer_codegen_graph(')
executor = change(executor, " report.compile_requested=true;stage('build_generated_target_once');", " assert(isequaln(state.bridgeOriginal,bridge_metadata(mdl))&&strcmp(state.bridgeOriginal.update,'CONTINUOUS'));\n report.compile_requested=true;stage('prepare_observer_codegen');")
executor = change(executor, "'.build','staged_execution'", "'.build','observer_codegen'")
executor = change(executor, " rtp=Simulink.BlockDiagram.buildRapidAcceleratorTarget(mdl);save(fullfile(folder,'runtime_parameters.mat'),'rtp');\n record.generated_target=target_inventory(generation,folder,mdl);", """ report.child_target_builds=1;stage('build_child_sim_target_once');slbuild(child,'ModelReferenceSimTarget');
 record.generated_target=target_inventory(generation,folder,child);
 report.parent_compile_pairs_requested=1;stage('verify_original_continuous_rate');
 feval(mdl,[],[],[],'compile');terminate=onCleanup(@()feval(mdl,[],[],[],'term'));
 report.bridge_compiled_sample_time=get_param([mdl '/Universal Bridge/续流'],'CompiledSampleTime');assert(isequal(report.bridge_compiled_sample_time,[0 0]));
 clear terminate;""")
executor = change(executor, "stage('execute_generated_target_once')", "stage('execute_normal_parent_accelerated_child_once')")
executor = change(executor, "out=sim(mdl,'SimulationMode','rapid-accelerator'", "out=sim(mdl,'SimulationMode','normal'")
executor = change(executor, "'mode','rapid-accelerator'", "'mode','normal','child_mode','accelerator','actual_reference_count',1")
executor = change(executor, " record.layer_restored=report.layer_restored;", " record.main_bridge_preserved=isequaln(state.bridgeOriginal,bridge_metadata(mdl));assert(record.main_bridge_preserved);\n record.saved_exports_unchanged=report.files_unchanged;record.callbacks_restored=strcmp(get_param(mdl,'InitFcn'),state.originalInit);\n record.layer_restored=report.layer_restored;")
executor = change(executor, "'.dll','.mk','.c','.h','.rtw','.tlc'", "'.mexw64','.dll','.mk','.c','.cpp','.h','.rtw','.tlc'")
executor = change(executor, "if strcmp(name,mdl)&&strcmp(ext,'.dll')", "if startsWith(name,mdl)&&strcmp(ext,'.mexw64')")
executor = change(executor, "'parent_target_exists',hasParent", "'observer_mex_target_exists',hasParent")
executor += bridge

graph = read(BASE / "robust/generated_backend/check_sensorless_r2_generated_graph.m")
graph = change(graph, "function result=check_sensorless_r2_generated_graph", "function result=check_sensorless_r2_observer_codegen_graph")
graph = graph.replace('normal_reference', 'accelerated_reference')
graph = change(graph, "strcmpi(get_param(reference,'SimulationMode'),'normal')", "strcmpi(get_param(reference,'SimulationMode'),'accelerator')&&strcmp(get_param(info.child_model,'ModelReferenceNumInstancesAllowed'),'Single')")

normalizer = read(BASE / "robust/execution_v8/normalize_sensorless_r2_v8_archive.m")
normalizer = change(normalizer, "function report=normalize_sensorless_r2_v8_archive", "function report=normalize_sensorless_r2_observer_codegen_archive")
normalizer = change(normalizer, " verify_sensorless_r2_logging(destination);verify_sensorless_r2_v8_short(destination);report.strict96_and_R1_81_comparisons_passed=true;", " verify_sensorless_r2_observer_codegen_short(destination);report.strict96_and_R1_81_comparisons_passed=true;")
for label in ("builder", "executor"):
    value = locals()[label]
    value = change(value, "'sensorless/robust/portable_execution','teaching'", "'sensorless/robust/portable_execution','sensorless/robust/observer_codegen','teaching'")
    if label == "builder":
        builder = value
    else:
        executor = value
outputs = {"build_sensorless_r2_observer_codegen.m": builder,
           "execute_sensorless_r2_observer_codegen.m": executor,
           "check_sensorless_r2_observer_codegen_graph.m": graph,
           "normalize_sensorless_r2_observer_codegen_archive.m": normalizer}
for name, value in outputs.items():
    (OUT / name).write_bytes(value.encode())
record = {"schema": 1, "input_sha256": inputs,
          "outputs_sha256": {name: hashlib.sha256(value.encode()).hexdigest() for name, value in outputs.items()},
          "contract": "contracts/nonideal_r2_observer_codegen_boundary.json",
          "unchanged": "Original case formulas/parameters, native period/solver, observer math, raw archive, endpoint/metrics and actual restore; timestamp conversion bytes unchanged.",
          "changes": "Only observer acceleration/Single boundary, source/provenance fixes, child target build/inventory, actual continuous parent verification and new equivalent exact verifier call."}
(OUT / "derivation.json").write_bytes((json.dumps(record, indent=2)+"\n").encode())
print(json.dumps(record))
