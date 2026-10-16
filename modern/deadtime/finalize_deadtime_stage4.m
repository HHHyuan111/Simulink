function finalize_deadtime_stage4
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','deadtime_stage');mdl='PMSM_FOC_R2026a';file=fullfile(work,[mdl '.slx']);
record=jsondecode(fileread(fullfile(folder,'deadtime_stage4_results.json')));assert(record.all_passed&&strcmp(teach_hash(file),record.model_sha256));
load_system(file);g=onCleanup(@()close_system(mdl,0));cache=load(fullfile(work,'before.mat'));now=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');
assert(startsWith(mw.MATLABCode,cache.code));assert(startsWith(get_param(mdl,'InitFcn'),cache.init));assert(isequaln(cache.before.regions,now.regions));
assert(numel(find_system(mdl,'SearchDepth',1,'Type','Block'))==188);
allowedInputs={[mdl '/Universal Bridge/Vabc'],[mdl '/限压/输入'],[mdl '/限压/输出_d'],[mdl '/限压/输出_q'], ...
 [mdl '/限压/残差_d'],[mdl '/限压/残差_q'],[mdl '/限压/诊断']};
motor=getfullname(Simulink.ID.getHandle([mdl ':626']));allowedInputs=[allowedInputs,{[motor '/ia'],[motor '/ib'],[motor '/ic']}];
changes=struct('path',{},'input_changed',{},'parameters_changed',{},'geometry_changed',{});
for b=cache.before.blocks
 n=now.blocks(strcmp({now.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(b.path,n.path)&&strcmp(b.type,n.type)&&strcmp(b.orientation,n.orientation));
 geometry=~isequal(b.position,n.position);assert(~geometry||strcmp(b.path,[mdl '/功率观测/总览']));
 inputs=~isequaln(b.inputs,n.inputs);params=~isequaln(b.params,n.params);mask=~isequaln(b.mask,n.mask);
 if inputs
  if strcmp(b.path,[mdl '/功率观测/总览']),assert(isequaln(b.inputs,n.inputs(1:numel(b.inputs))));
  else,assert(ismember(b.path,allowedInputs),'Unexpected input change %s',b.path);end
 end
 if params,assert(ismember(b.path,{[mdl '/功率设置'],[mdl '/功率设置/启用'],[mdl '/采样设置/门极']}),'Unexpected parameter change %s',b.path);end
 if mask,assert(strcmp(b.path,[mdl '/功率设置']),'Unexpected mask change %s',b.path);end
 if inputs||params||mask||geometry,changes(end+1)=struct('path',b.path,'input_changed',inputs,'parameters_changed',params||mask,'geometry_changed',geometry);end %#ok<AGROW>
end
for k=1:size(cache.before.scripts,1),idx=strcmp(now.scripts(:,1),cache.before.scripts{k,1});assert(nnz(idx)==1&&strcmp(now.scripts{idx,2},cache.before.scripts{k,2}));end
for row={'Universal Bridge','门极死区','gate_deadtime.m';'Universal Bridge','续流','bridge_freewheel.m';'限压','死区补偿','deadtime_comp.m'}'
 idx=strcmp(now.scripts(:,1),[mdl '/' row{1} '/' row{2}]);assert(nnz(idx)==1&&strcmp(now.scripts{idx,2},fileread(fullfile(folder,row{3}))));
end
record.original_changes=changes;record.root_geometry_preserved=true;record.regions_preserved=true;record.original_scripts_preserved=true;
record.internal_scope_resize_only=true;record.default_settings=teach_settings(mdl);
for s=record.default_settings,for q=s.parameters,if endsWith(q.name,'_on'),assert(strcmp(q.value,'off'));end,end,end
record.notes={'Same 600rpm/0.207Nm initialized operating point and original PI gains in all three demonstrations.', ...
 'Ideal demo uses zero deadtime on the same gate grid and bridge; it isolates deadtime from edge quantization.', ...
 '0.5us is programmed timer deadtime. Driver propagation, device data and measurement calibration remain unknown.', ...
 'Zero-current band0.01A and compensation hysteresis0.05A are demonstrations; floating-star non-salient PMSM only.', ...
 'THD covers angular harmonics2-25 in the last two settled electrical cycles of PWM-period averaged current, not switching-frequency THD.', ...
 'Active protection, minimum on-time rules, switching losses and detailed capacitance/recovery remain absent.'};
record.publication_status='verified_candidate';record.reviewed_at=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
teach_writejson(fullfile(folder,'deadtime_stage4_results.json'),record);
print(['-s' mdl],'-dpng','-r120',fullfile(work,'candidate.png'));fprintf('DEADTIME_REVIEW_READY %s\n',record.model_sha256);
end
