function report=validate_user_run_workflow
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'),fullfile(root,'layout','appearance'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');hash=teach_hash(fullfile(root,[m '.slx']));
before=teach_snapshot(m);baseIds=Simulink.sdi.getAllRunIDs;
fprintf('USER_RUN_OFF\n');in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','.004');out1=sim(in);
fprintf('USER_RUN_BIAS\n');in=in.setBlockParameter([m '/采样设置'],'bias_on','on');in=in.setBlockParameter([m '/采样设置'],'bias_A','[.1 -.1 .05]');out2=sim(in);
in=in.setBlockParameter([m '/采样设置'],'bias_A','[.2 -.1 .05]');out3=sim(in);
assert(max(abs(teach_values(out2.log_iabc_meas)-teach_values(out2.log_iabc_true)),[],'all')>.09);
pmsm_reference('restore');assert(isequaln(before,teach_snapshot(m)));cfg=pmsm_config('read');topics={'speed','sampling','power'};makers={@open_pmsm_speed_lesson,@open_pmsm_sampling_lesson,@open_pmsm_deadtime_lesson};checks=0;ids=cell(1,3);
target=fullfile(root,'signal_chain','user_runs');if ~isfolder(target),mkdir(target);end
for topicIndex=1:3
 topic=topics{topicIndex};key=['PMSMUserRuns_' topic];assert(~isappdata(groot,key));panel=makers{topicIndex}();
 keep=findall(panel,'Tag',['user_keep_' topic]);compare=findall(panel,'Tag',['user_compare_' topic]);assert(isscalar(keep)&&isscalar(compare));
 assignin('base','out',out1);keep.ButtonPushedFcn(keep,[]);state=getappdata(groot,key);assert(numel(state)==1);keep.ButtonPushedFcn(keep,[]);assert(numel(getappdata(groot,key))==1);
 if topicIndex==1,one=pmsm_user_runs('compare',topic);assert(numel(one)==1);end
 assignin('base','out',out2);keep.ButtonPushedFcn(keep,[]);state=getappdata(groot,key);assert(numel(state)==2);ids{topicIndex}=[state.id];
 compare.ButtonPushedFcn(compare,[]);[rows,layout]=pmsm_user_run_signals(topic);
 for runIndex=1:2
  o=out1;if runIndex==2,o=out2;end
  run=Simulink.sdi.getRun(state(runIndex).id);assert(run.SignalCount==size(rows,1));
  for j=1:run.SignalCount
   sig=run.getSignalByIndex(j);index=find(strcmp(rows(:,1),sig.Name));assert(isscalar(index));original=o.get(rows{index,2});v=teach_values(original);column=abs(rows{index,3});y=v(:,column);
   if rows{index,3}<0,q=o.get(rows{index,6});w=teach_values(q);y=y-w(:,column);end
   assert(isequal(sig.Values.Time,original.Time)&&isequal(teach_values(sig.Values),y)&&sig.Checked);checks=checks+1;
  end
 end
 exportapp(panel,fullfile(target,[topic '_panel.png']));delete(panel);
 if strcmp(topic,'sampling'),drawnow;Simulink.sdi.snapshot('To','file','Filename',fullfile(target,'sampling_comparison.png'));end
end
assert(checks==62); % 2*(10 speed + 12 sampling + 9 power)
third=pmsm_user_runs('keep','sampling',out3);selected=pmsm_user_runs('compare','sampling');assert(isequal([selected.id],[ids{2}(2) third.id]));
oldRun=Simulink.sdi.getRun(ids{2}(1));for j=1:oldRun.SignalCount,sig=oldRun.getSignalByIndex(j);assert(~sig.Checked);end
% Reject absent/wrong output without creating another retained record.
failed=false;try,pmsm_user_runs('keep','speed',struct);catch,failed=true;end;assert(failed);
assert(isequaln(cfg,pmsm_config('read'))&&isequaln(before,teach_snapshot(m))&&strcmp(hash,teach_hash(fullfile(root,[m '.slx']))));
% Leave pre-existing SDI data untouched; remove only this worker's new runs.
newIds=setdiff(Simulink.sdi.getAllRunIDs,baseIds);for id=newIds(:)',Simulink.sdi.deleteRun(id);end
for topic=topics,rmappdata(groot,['PMSMUserRuns_' topic{1}]);rmappdata(groot,['PMSMUserRuns_' topic{1} '_Sequence']);end;evalin('base','clear out');
assert(all(ismember(baseIds,Simulink.sdi.getAllRunIDs)));
report=struct('passed',true,'actual_simulations',3,'simulation_duration_s',.004,'topics',{topics},'sdi_signal_records_exact',checks,'duplicate_capture_reused',true,'single_run_view_checked',true,'latest_two_rolling_checked',true,'actual_button_callbacks_checked',true,'unrelated_runs_preserved',true,'model_parameters_preserved',true,'model_sha256',hash,'scope','Manual keep of actual outputs; native SDI overlay; time-domain records only, no algorithm performance claim.');
teach_writejson(fullfile(target,'validation.json'),report);disp('USER_RUN_WORKFLOW_VALIDATED');
end
