function finalize_timing_stage3
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','timing_stage');mdl='PMSM_FOC_R2026a';file=fullfile(work,[mdl '.slx']);
record=jsondecode(fileread(fullfile(folder,'timing_stage3_results.json')));assert(record.all_passed&&strcmp(teach_hash(file),record.model_sha256));
record.finite_log_audit=struct;
for name={'off','real','window','window_hold','fine','stress_reference','stress_window','stress_hold'}
 saved=load(fullfile(work,[name{1} '.mat']));if strcmp(name{1},'fine'),out=saved.fine;else,out=saved.o;end
 count=0;keys=out.who;
 for k=1:numel(keys)
  signal=out.get(keys{k});if ~isa(signal,'timeseries'),continue;end
  assert(all(isfinite(signal.Time),'all')&&all(isfinite(signal.Data),'all'),'Nonfinite %s/%s',name{1},keys{k});count=count+1;
 end
 record.finite_log_audit.(name{1})=count;clear saved out signal;
end
load_system(file);g=onCleanup(@()close_system(mdl,0));cache=load(fullfile(work,'before.mat'));now=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');
assert(startsWith(mw.MATLABCode,cache.code));assert(isequaln(cache.before.regions,now.regions));
assert(numel(find_system(mdl,'SearchDepth',1,'Type','Block'))==188);
changes=struct('path',{},'parameter_changed',{},'input_changed',{});
for b=cache.before.blocks
 n=now.blocks(strcmp({now.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(b.path,n.path)&&strcmp(b.type,n.type)&&isequal(b.position,n.position)&&strcmp(b.orientation,n.orientation));
 params=~isequaln(b.params,n.params);mask=~isequaln(b.mask,n.mask);inputs=~isequaln(b.inputs,n.inputs);
 if params||mask||inputs
  changes(end+1)=struct('path',b.path,'parameter_changed',params||mask,'input_changed',inputs); %#ok<AGROW>
  if inputs
   if strcmp(b.path,[mdl '/时序观测/总览'])
    assert(isequaln(b.inputs,n.inputs(1:numel(b.inputs))),'Existing scope inputs changed.');
   else
    assert(ismember(b.path,{[mdl '/采样设置/捕获'],[mdl '/输出延迟/生效'],[mdl '/输出延迟/记录_log_Tcm_applied']}),'Unexpected original wiring change %s',b.path);
   end
  end
  for field=fieldnames(b.params)'
   key=field{1};if isequaln(b.params.(key),n.params.(key)),continue;end
   assert(ismember(key,{'SampleTime','real_on','window_on','invalid_hold_on','real_mode','trigger_us','sync_us','compute_us','settle_us','update_mode','grid_divider'}) ...
    ||strcmp(b.path,[mdl '/时序观测/总览'])||strcmp(b.path,[mdl '/采样设置/启用'])||strcmp(b.path,[mdl '/Carrier Wave']),'Unexpected parameter change %s/%s',b.path,key);
  end
 end
end
for k=1:size(cache.before.scripts,1)
 idx=strcmp(now.scripts(:,1),cache.before.scripts{k,1});assert(nnz(idx)==1&&strcmp(now.scripts{idx,2},cache.before.scripts{k,2}));
end
for row={'顺序采样','采样设置','timing_adc.m';'CCR预装载','输出延迟','timing_pwm.m'}'
 idx=strcmp(now.scripts(:,1),[mdl '/' row{2} '/' row{1}]);assert(nnz(idx)==1&&strcmp(now.scripts{idx,2},fileread(fullfile(folder,row{3}))));
end
% Verify saved load, unchanged settings, and event source independence.
record.original_changes=changes;record.original_geometry_preserved=true;record.original_scripts_preserved=true;
record.default_settings=teach_settings(mdl);for s=record.default_settings,for p=s.parameters,if endsWith(p.name,'_on'),assert(strcmp(p.value,'off'));end,end,end
record.notes={'45 old timeseries match in time and normalized channel values; Tcm_applied raw array orientation can differ.', ...
 'Trigger phase 24.375us is an explicit unmeasured assumption. Compute5us and settling0.5us are demonstrations.', ...
 'Window OFF samples ideal phase currents; ON invalid samples are zeroed as a teaching approximation. Optional hold is not firmware current reconstruction.', ...
 'Original 622 blocks, all nine regions and PI gains are preserved. Short runs verify timing, not full-speed performance.', ...
 'Physical deadtime/diode conduction, ADC2 bus timing, amplifier dynamics, ABZ and active protection remain future work.'};
record.reviewed_at=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
record.publication_status='verified_candidate_pending_desktop_release';
record.candidate_path=file;record.canonical_path=fullfile(root,[mdl '.slx']);record.canonical_sha256=teach_hash(record.canonical_path);
teach_writejson(fullfile(folder,'timing_stage3_results.json'),record);
print(['-s' mdl],'-dpng','-r120',fullfile(work,'candidate.png'));
fprintf('TIMING_REVIEW_READY %s\n',record.model_sha256);
end
