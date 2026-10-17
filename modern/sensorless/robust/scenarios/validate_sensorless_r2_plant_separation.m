function report=validate_sensorless_r2_plant_separation(folder)
% Configuration-only checks; no compile, no simulation, no precision claim.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~isfolder(folder)&&~bdIsLoaded(mdl));mkdir(folder);cleanup=onCleanup(@()close_private(mdl));
sourceHash=teach_hash(fullfile(here,'sensorless_r2_plant_parameters.m'));modelHash=teach_hash(fullfile(modern,[mdl '.slx']));
load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');original=teach_snapshot(mdl);ws=get_param(mdl,'ModelWorkspace');
nominal=[getVariable(ws,'Rs') getVariable(ws,'Ld') getVariable(ws,'Lq')];pairs=[1.2 .8;.8 1.2];
report=struct('kind','plant_only_parameter_configuration','simulation_called',false,'compile_called',false,...
 'all_passed',false,'nominal_R_Ld_Lq',nominal,'source_sha256',sourceHash,'model_sha256',modelHash);
for f=dir(fullfile(here,'*.m'))',report.sources.(erase(f.name,'.m'))=teach_hash(fullfile(f.folder,f.name));end
report.contract_sha256=teach_hash(fullfile(base,'contracts/nonideal_r2_plant_adapter_design.json'));
for k=1:size(pairs,1)
 backup=sensorless_r2_plant_parameters(mdl,pairs(k,1),pairs(k,2));
 actual=[getVariable(ws,'R2plant_Rs') getVariable(ws,'R2plant_Ld') getVariable(ws,'R2plant_Lq')];
 assert(isequaln(actual,nominal.*[pairs(k,1) pairs(k,2) pairs(k,2)]));
 assert(isequaln(nominal,[getVariable(ws,'Rs') getVariable(ws,'Ld') getVariable(ws,'Lq')]));
 for entry=backup.expressions(:)',assert(contains(get_param(entry.path,'Expr'),'R2plant_'));end
 sensorless_r2_restore_plant(mdl,backup);assert(isequaln(original,teach_snapshot(mdl)));
 assert(~hasVariable(ws,'R2plant_Rs')&&~hasVariable(ws,'R2plant_Ld')&&~hasVariable(ws,'R2plant_Lq'));
 report.cases(k)=struct('R_multiplier',pairs(k,1),'L_multiplier',pairs(k,2),'actual_R_Ld_Lq',actual,'expressions',numel(backup.expressions),'restored',true);
end
assert(strcmp(modelHash,teach_hash(fullfile(modern,[mdl '.slx'])))&&strcmp(sourceHash,teach_hash(fullfile(here,'sensorless_r2_plant_parameters.m'))));
report.all_passed=true;teach_writejson(fullfile(folder,'report.json'),report);fprintf('R2_PLANT_SEPARATION_CONFIGURATION_PASSED cases=2 no_compile=1\n');
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
