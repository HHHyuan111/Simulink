"""Derive the user-approved Normal-only serialized acceptance path."""
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
ORIGIN = BASE / 'runs/N3R2_observer_codegen_short_once/build/source/robust/observer_codegen'
DEST = BASE / 'robust/normal_serialized'
assert not (BASE / 'runs/N3R2_normal_serialized_short_once').exists()
DEST.mkdir(exist_ok=True)
inputs = {}


def read(name):
    raw = (ORIGIN / name).read_bytes()
    assert raw == (BASE / 'robust/observer_codegen' / name).read_bytes()
    inputs[name] = hashlib.sha256(raw).hexdigest()
    return raw.decode('utf8').replace('observer_codegen', 'normal_serialized')


def change(value, old, new):
    assert value.count(old) == 1, old
    return value.replace(old, new)


builder = read('build_sensorless_r2_observer_codegen.m')
builder = change(builder, "set_param(references{1},'SimulationMode','Accelerator')", "set_param(references{1},'SimulationMode','Normal')")
builder = change(builder, "'parent','Normal','child','Accelerator'", "'parent','Normal','child','Normal'")
executor = read('execute_sensorless_r2_observer_codegen.m')
executor = change(executor, "'kind','normal_parent_accelerated_observer'", "'kind','normal_serialized_parent_and_observer'")
executor = change(executor, "'simulation_starts',0,'compile_requested',false,'R2_passed',false", "'simulation_starts',0,'compile_requested',false,'explicit_generated_target_builds',0,'compiler_setup_performed',false,'R2_passed',false")
executor = change(executor, " record.compiler=struct('C',compiler_info('C'),'CXX',compiler_info('C++'),'private_preferences',prefdir);\n", '')
executor = change(executor, " report.child_target_builds=1;stage('build_child_sim_target_once');slbuild(child,'ModelReferenceSimTarget');\n record.generated_target=target_inventory(generation,folder,child);\n", '')
executor = change(executor, 'execute_normal_parent_accelerated_child_once', 'execute_normal_parent_normal_child_once')
executor = change(executor, "'child_mode','accelerator'", "'child_mode','normal'")
begin = executor.index('function info=compiler_info(language)')
end = executor.index('function value=bridge_metadata(mdl)', begin)
executor = executor[:begin] + executor[end:]
checker = read('check_sensorless_r2_observer_codegen_graph.m')
checker = checker.replace('accelerated_reference', 'normal_reference')
checker = change(checker, "get_param(reference,'SimulationMode'),'accelerator'", "get_param(reference,'SimulationMode'),'normal'")
normalizer = read('normalize_sensorless_r2_observer_codegen_archive.m')
verifier = read('verify_sensorless_r2_observer_codegen_short.m')
verifier = change(verifier, "r.execution.child_mode,'accelerator'", "r.execution.child_mode,'normal'")
outputs = {'build_sensorless_r2_normal_serialized.m': builder,
           'execute_sensorless_r2_normal_serialized.m': executor,
           'check_sensorless_r2_normal_serialized_graph.m': checker,
           'normalize_sensorless_r2_normal_serialized_archive.m': normalizer,
           'verify_sensorless_r2_normal_serialized_short.m': verifier}
for name, value in outputs.items():
    (DEST / name).write_bytes(value.encode('utf8'))
record = {'schema': 1, 'archived_input_sha256': inputs,
          'outputs_sha256': {name: hashlib.sha256(value.encode('utf8')).hexdigest() for name, value in outputs.items()},
          'contract': 'contracts/nonideal_r2_normal_serialized_acceptance.json',
          'changes': ['New Normal serialized source/path/version binding.',
                      'Both parent and child Normal; childSingle and original continuous bridge preserved.',
                      'Remove explicit slbuild/target inventory/compiler setup; retain explicit Normal compile/term and one sim.',
                      'Retain all physical cases/math/configs, raw/native checks, actual restoration and strict81/96 comparison; Time encoder unchanged.']}
(DEST / 'derivation.json').write_bytes((json.dumps(record, ensure_ascii=True, indent=2)+'\n').encode())
print(json.dumps(record))
