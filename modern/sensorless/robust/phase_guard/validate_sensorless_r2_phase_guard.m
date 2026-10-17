function result=validate_sensorless_r2_phase_guard(folder)
% Independent wrapped-angle oracle: boundary, alias, scale and live vetoes.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for d={'sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3','sensorless/robust/phase_guard','teaching'},addpath(fullfile(modern,d{1}));end
record=sensorless_r2_guard_snapshot(folder);trace=[];count=0;
for theta=linspace(-2*pi,2*pi,13)
 for delta=[-180 -90 -5.000001 -5 -4 0 4 5 5.000001 90 180]*pi/180
  for magnitude=[.25 1 4 16]
   vector=magnitude*[cos(theta+delta);sin(theta+delta)];[valid,diag]=sensorless_r2_phase_guard(theta,vector,true,true,false,.5);
   difference=atan2(sin(delta),cos(delta));expected=abs(difference)<=5*pi/180+8*eps&&cos(difference)>0&&magnitude>=.5;
   assert(valid==expected);count=count+1;trace(count,:)=[theta delta magnitude double(valid) diag']; %#ok<AGROW>
  end
 end
end
vetoes={false,true,false;true,false,false;true,true,true};
for k=1:size(vetoes,1),[valid,~]=sensorless_r2_phase_guard(.4,[cos(.4);sin(.4)],vetoes{k,1},vetoes{k,2},vetoes{k,3},.5);assert(~valid);end
for vector={[0;0],[NaN;1],[Inf;1]},[valid,diag]=sensorless_r2_phase_guard(0,vector{1},true,true,false,.5);assert(~valid&&all(isfinite(diag)));end
[valid,~]=sensorless_r2_phase_guard(NaN,[1;0],true,true,false,.5);assert(~valid);
cfg=sensorless_v2_config_values(.105125,.0001037615,20,12,false,0);c=sensorless_v2_config_rt(cfg);
e0=sensorless_event_plan(0,0,0,c);e1=sensorless_event_plan(1,0,0,c);s=sensorless_v2_queue_state;
firstReady=round(e0.observer_available_s/c.h_s);secondReference=round(e1.reference_time_s/c.h_s);secondReady=round(e1.observer_available_s/c.h_s);
queue=zeros(secondReady+3,17);
for tick=0:secondReady+2
 delta=4*pi/180;if tick>=secondReference,delta=6*pi/180;end
 safe=sensorless_r2_phase_guard(1,4*[cos(1+delta);sin(1+delta)],true,true,false,.5);
 [s,values,permit,reason]=sensorless_v2_queue_step(s,tick*c.h_s,1,50,safe,true,true,c);
 queue(tick+1,:)=[tick*c.h_s values' double(permit) reason double(safe)];
 if tick<firstReady,assert(~permit);end
 if tick==firstReady||tick==secondReference,assert(permit);end
 if tick>=secondReady,assert(~permit&&all(values(9:11)==0));end
end
result=struct('all_passed',true,'geometry_cases',count,'veto_cases',3,'invalid_cases',4,...
 'queue_native_samples',size(queue,1),'publication_delay_s',c.observer_exec_s,'no_truth_input',true,'phase_limit_deg',5);
save(fullfile(folder,'phase_guard.mat'),'trace','queue','result','-v7.3');sensorless_v2_guard_sources(record);
record.status='passed';record.phase='completed';record.raw_sha256=teach_hash(fullfile(folder,'phase_guard.mat'));
teach_writejson(fullfile(folder,'record.json'),record);teach_writejson(fullfile(folder,'metrics.json'),result);fprintf('R2_PHASE_GUARD_COMPONENT_PASSED cases=%d\n',count+7);
end
