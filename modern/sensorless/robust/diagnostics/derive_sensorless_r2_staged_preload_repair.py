"""Apply only the prospectively registered, pre-load staging correction."""
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
BUILD = BASE / "runs/N3R2_staged_short_once/build"
RELATIVE = "robust/portable_execution/execute_sensorless_r2_staged.m"
source = (BUILD / "source" / RELATIVE).read_bytes()
target = BASE / RELATIVE
existing_derivation = BASE / "robust/diagnostics/staged_preload_repair.json"
allowed = [source]
if existing_derivation.exists():
    prior = json.loads(existing_derivation.read_bytes())
    assert hashlib.sha256(source).hexdigest() == prior["input_sha256"]
    assert hashlib.sha256(target.read_bytes()).hexdigest() == prior["output_sha256"]
    allowed.append(target.read_bytes())
assert target.read_bytes() in allowed, "Correction must derive from the archived builder source."
assert not (BASE / "runs/N3R2_staged_preload_repair_once").exists(), "Never revise a started execution."
old = b"for k=1:numel(record.contracts),copyfile(fullfile(buildFolder,record.contracts(k).path),fullfile(folder,record.contracts(k).path));end"
new = b"""for k=1:numel(record.contracts)
 target=fullfile(folder,record.contracts(k).path);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(buildFolder,record.contracts(k).path),target);
end
% Bind the sole corrected executor while retaining the builder's original source map.
repairPath='robust/diagnostics/staged_preload_repair.json';
repair=jsondecode(fileread(fullfile(base,repairPath)));self=[mfilename('fullpath') '.m'];
assert(strcmp(teach_hash(self),repair.output_sha256));
assert(strcmp(teach_hash(fullfile(buildFolder,'record.json')),repair.builder_record_sha256));
index=find(strcmp({record.source_files.path},repair.source_path));assert(isscalar(index));
assert(strcmp(record.source_files(index).sha256,repair.input_sha256));
record.source_files(index).sha256=repair.output_sha256;
copyfile(self,fullfile(folder,'source',repair.source_path));
for relative={repairPath,'contracts/nonideal_r2_staged_preload_repair.json'}
 target=fullfile(folder,relative{1});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(base,relative{1}),target);
 record.contracts(end+1)=struct('path',relative{1},'sha256',teach_hash(fullfile(base,relative{1})));
end
record.preload_staging_repair=repair;
record.builder_restoration_proof=struct('layer_restored',buildRecord.layer_restored,'reference_restored',buildRecord.reference_restored);
record.layer_restored=false;record.reference_restored=false;record.callback_restored=false;
record.native_endpoint_verified=false;record.metrics_passed=false;
sensorless_v2_guard_sources(record);"""
assert source.count(old) == 1
corrected = source.replace(old, new)
sha = lambda data: hashlib.sha256(data).hexdigest()
record = {
    "schema": 1,
    "source_path": RELATIVE,
    "input_sha256": sha(source),
    "output_sha256": sha(corrected),
    "builder_record_sha256": sha((BUILD / "record.json").read_bytes()),
    "retained_campaign_sha256": sha((BUILD.parent / "campaign.json").read_bytes()),
    "contract_path": "contracts/nonideal_r2_staged_preload_repair.json",
    "contract_sha256": sha((BASE / "contracts/nonideal_r2_staged_preload_repair.json").read_bytes()),
    "transformations": [
        "Create each metadata target's parent directory before copying.",
        "Bind and archive only the corrected executor, repair contract and derivation before any load.",
        "Retain builder restoration evidence separately; reset executor completion flags before work.",
        "All model load, compile, sim, archive, comparison and restoration statements unchanged."
    ],
    "physical_code_unchanged": corrected.split(b"try\n assert(strcmp(teach_hash(state.parentFile)", 1)[1]
        == source.split(b"try\n assert(strcmp(teach_hash(state.parentFile)", 1)[1],
}
assert record["physical_code_unchanged"]
target.write_bytes(corrected)
(BASE / "robust/diagnostics/staged_preload_repair.json").write_bytes(
    (json.dumps(record, ensure_ascii=True, indent=2) + "\n").encode()
)
print(json.dumps(record, ensure_ascii=True))
