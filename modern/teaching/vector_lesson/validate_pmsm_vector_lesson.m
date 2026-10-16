function report=validate_pmsm_vector_lesson
% Validate transformations against model logs and exercise the real UI callbacks.
here=fileparts(mfilename('fullpath'));teach=fileparts(here);root=fileparts(teach);
addpath(teach,here);work=fullfile(root,'.build',['vector_validation_' char(java.util.UUID.randomUUID)]);mkdir(work);
watch={fullfile(root,'PMSM_FOC_R2026a.slx'),fullfile(teach,'reference_v1','manifest.json'), ...
 fullfile(teach,'reference_v1','state.json'),fullfile(root,'framework','open_pmsm_framework.m')};
before=cellfun(@teach_hash,watch,'UniformOutput',false);
runtime={'open_pmsm_vector_lesson.m','open_pmsm_teaching.m','vector_lesson/pmsm_vector_transform.m', ...
 'vector_lesson/pmsm_vector_load.m','vector_lesson/pmsm_vector_frame.m','vector_lesson/pmsm_vector_plot.m', ...
 'vector_lesson/export_pmsm_vector_lesson.m','vector_lesson/verify_pmsm_vector_export.m','vector_lesson/validate_pmsm_vector_lesson.m'};
runtimeHashes=cellfun(@(p)teach_hash(fullfile(teach,p)),runtime,'UniformOutput',false);
checks=struct('name',{},'passed',{},'detail',{});
fprintf('VECTOR_TEST_TRANSFORMS\n');
theta=(0:360)'*pi/180;desired=[.3*ones(size(theta)) 4.8*ones(size(theta))];
alpha=desired(:,1).*cos(theta)-desired(:,2).*sin(theta);beta=desired(:,1).*sin(theta)+desired(:,2).*cos(theta);
zero=.12;abc=[alpha+zero,-alpha/2+sqrt(3)*beta/2+zero,-alpha/2-sqrt(3)*beta/2+zero];
v=pmsm_vector_transform(abc,theta);
add('known_dq_and_nonzero_zero_sequence',max(abs(v.dq_A-desired),[],'all')<1e-12&&max(abs(v.zero_A-zero))<1e-12, ...
 'Known rotating vector including nonzero zero sequence, 0..360 electrical degrees.');
add('clarke_roundtrip',max(abs(v.abc_reconstructed_A-abc),[],'all')<1e-12,'Full inverse retains zero sequence.');
rejects(@()pmsm_vector_transform(abc,theta(1:end-1)),'mismatched_sample_count');
bad=abc;bad(2,1)=NaN;rejects(@()pmsm_vector_transform(bad,theta),'nonfinite_input');
fprintf('VECTOR_TEST_ARCHIVE\n');d=pmsm_vector_load;again=pmsm_vector_load(d.folder);
add('independent_reload_exact',isequaln(d,again),'Two separate reads produce identical full derived records.');
for k=1:2
 c=d.cases(k);add(['model_log_transform_' c.id],all(structfun(@(x)x<1e-9,c.residual)),jsonencode(c.residual));
 delta=c.angle_error_deg*pi/180;
 projected=[c.dq_true_A(:,1).*cos(delta)+c.dq_true_A(:,2).*sin(delta), ...
  -c.dq_true_A(:,1).*sin(delta)+c.dq_true_A(:,2).*cos(delta)];
 add(['bias_rotation_' c.id],max(abs(projected-c.dq_feedback_A),[],'all')<1e-10,'The two frames obey the rotation identity at every sample.');
end
for j=1:3
 for k=1:2
  low=pmsm_vector_frame(d,k,j,-1);high=pmsm_vector_frame(d,k,j,1e3);
  mid=pmsm_vector_frame(d,k,j,mean(low.bounds_s)+.000013);
  add(sprintf('native_cursor_case%d_window%d',k,j),low.index==low.indices(1)&&high.index==high.indices(end)&& ...
   mid.time_s==d.cases(k).time_s(mid.index)&&isequal(mid.abc_A,d.cases(k).abc_A(mid.index,:))&& ...
   mid.history_indices(end)==mid.index,'Clamping and snapping without interpolation.');
 end
end
rejects(@()pmsm_vector_load(fullfile(work,'not_an_archive')),'missing_archive');
fprintf('VECTOR_TEST_UI\n');f=open_pmsm_vector_lesson(d.folder,'off');guard=onCleanup(@()closeIfValid(f));
caseChoice=findall(f,'Tag','vector_case');window=findall(f,'Tag','vector_window');axisToggle=findall(f,'Tag','vector_axes');
timeBox=findall(f,'Tag','vector_time');slider=findall(f,'Tag','vector_slider');play=findall(f,'Tag','vector_play');reset=findall(f,'Tag','vector_reset');
for j=1:3
 window.Value=j;invoke(window.ValueChangedFcn,window,struct);
 for k=1:2
  caseChoice.Value=k;invoke(caseChoice.ValueChangedFcn,caseChoice,struct);
  bounds=d.windows(j).bounds_s;invoke(slider.ValueChangingFcn,slider,struct('Value',mean(bounds)*1000+.013));
  frame=getappdata(f,'vector_frame');h=getappdata(f,'vector_plot_handles');c=d.cases(k);
  add(sprintf('linked_ui_case%d_window%d',k,j),frame.time_s==c.time_s(frame.index)&& ...
   isequal(h.vector.XData,[0 c.alpha_beta_A(frame.index,1)])&& ...
   isequal(h.abcPoints.YData,c.abc_A(frame.index,:))&& ...
   all(h.dqCursor(1).XData==frame.time_s*1000)&& ...
   isequal(h.dqPoints(1).YData,[c.dq_true_A(frame.index,1) c.dq_feedback_A(frame.index,1)]), ...
   'Actual dropdown and scrub callbacks update all four plots from one native sample.');
 end
end
window.Value=1;invoke(window.ValueChangedFcn,window,struct);timeBox.Value=195.013;invoke(timeBox.ValueChangedFcn,timeBox,struct);
frame=getappdata(f,'vector_frame');add('numeric_time_snaps',abs(frame.time_s-.195)<1e-12,'195.013ms resolves to native 195.000ms.');
axisToggle.Value=false;invoke(axisToggle.ValueChangedFcn,axisToggle,struct);h=getappdata(f,'vector_plot_handles');
add('axis_toggle',strcmp(h.rotorD.Visible,'off')&&strcmp(h.controlD.Visible,'off')&&~h.axesShown,'Optional coordinate axes and legends switch together.');
axisToggle.Value=true;invoke(axisToggle.ValueChangedFcn,axisToggle,struct);
invoke(reset.ButtonPushedFcn,reset,struct);first=getappdata(f,'vector_frame');
invoke(play.ButtonPushedFcn,play,struct);pause(.22);drawnow;
timerObject=getappdata(f,'vector_timer');progress=getappdata(f,'vector_frame');
if strcmp(timerObject.Running,'on'),invoke(play.ButtonPushedFcn,play,struct);end
add('play_pause',progress.index>first.index&&strcmp(timerObject.Running,'off')&&strcmp(play.Text,'播放'), ...
 'Timer advances native samples and pause stops it.');
invoke(reset.ButtonPushedFcn,reset,struct);frame=getappdata(f,'vector_frame');
add('reset_cursor',frame.index==frame.indices(1),'Reset returns to window start.');
timeBox.Value=195;invoke(timeBox.ValueChangedFcn,timeBox,struct);
for p={[80 60 1380 940],[80 60 1100 760],[80 60 1680 1000]}
 f.Position=p{1};drawnow;pause(1.2);drawnow;
 filename=sprintf('ui_%dx%d.png',p{1}(3),p{1}(4));exportapp(f,fullfile(work,filename));
end
f.Position=[80 60 950 650];invoke(f.SizeChangedFcn,f,struct);drawnow;
add('minimum_layout',all(f.Position(3:4)>=[1100 760]),'Resize callback restores the minimum 1100×760 layout.');
close(f);add('timer_cleanup',~isvalid(f)&&~isvalid(timerObject),'Closing only this lesson releases its playback timer.');clear guard;
fprintf('VECTOR_TEST_EXPORT\n');
out=fullfile(work,'export');r=export_pmsm_vector_lesson(d,2,1,.195,true,out);verified=verify_pmsm_vector_export(out);
add('export_manifest',strcmp(verified.status,'completed')&&numel(verified.files)==6,'Source fingerprints and six generated files verified.');
rejects(@()export_pmsm_vector_lesson(d,2,1,.195,true,out),'overwrite_existing_export');
tampered=d;tampered.cases(1).abc_A(1,1)=tampered.cases(1).abc_A(1,1)+1;
rejects(@()export_pmsm_vector_lesson(tampered,1,1,.195,true,fullfile(work,'tampered_input')),'in_memory_data_change');
copy=fullfile(work,'tampered_export');copyfile(out,copy);fid=fopen(fullfile(copy,'notes.md'),'a');fprintf(fid,'tampered');fclose(fid);
rejects(@()verify_pmsm_vector_export(copy),'tampered_export_rejected');
fresh=pmsm_vector_load(d.folder);add('source_archive_unchanged',isequaln(d,fresh),'Source record and both MAT files retain their exact identities.');
f=open_pmsm_teaching('off');add('workbench_entry',isscalar(findall(f,'Tag','vector_lesson_entry')),'Lesson wrapper adds a workbench entry without changing the old launcher.');close(f);
after=cellfun(@teach_hash,watch,'UniformOutput',false);add('baseline_files_unchanged',isequal(before,after),'SLX, fixed reference and original launcher are unchanged.');
currentHashes=cellfun(@(p)teach_hash(fullfile(teach,p)),runtime,'UniformOutput',false);
assert(isequal(runtimeHashes,currentHashes),'验收期间源码发生变化，拒绝发布。');
sourceFiles=struct('path',runtime,'sha256',runtimeHashes);
report=struct('schema',1,'kind','coordinates_lesson_validation_v1','matlab_version',version, ...
 'source_id',d.source_id,'source_record_sha256',d.source_record_sha256,'model_sha256',d.model_sha256, ...
 'work_folder',work,'sample_period_s',d.sample_period_s,'case_samples',[numel(d.cases(1).time_s),numel(d.cases(2).time_s)], ...
 'residuals',[d.cases.residual],'source_files',sourceFiles,'checks',checks,'all_passed',all([checks.passed]), ...
 'scope','Archived data transforms, actual UI callbacks, native-sample playback and derived exports. No new simulation or algorithm validation.');
teach_writejson(fullfile(here,'validation.json'),report);fprintf('VECTOR_VALIDATION_PASSED %d %s\n',numel(checks),work);
 function add(name,passed,detail)
  checks(end+1)=struct('name',name,'passed',logical(passed),'detail',detail);assert(passed,'验证失败：%s',name);
 end
 function rejects(fn,name)
  rejected=false;try,fn();catch,rejected=true;end
  add(name,rejected,'Invalid input or archive rejected.');
 end
end
function invoke(fn,source,event),fn(source,event);end
function closeIfValid(f),if isvalid(f),close(f);end,end
