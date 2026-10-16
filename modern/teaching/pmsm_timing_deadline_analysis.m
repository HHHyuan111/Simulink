function [r,traces]=pmsm_timing_deadline_analysis(outputs,plan)
% Integer event ticks avoid floating-point ambiguity at exact UEV boundaries.
assert(strcmp(plan.scenario.id,'timing_deadline')&&numel(outputs)==3);
c=plan.comparison_contract;h=c.event_step_s;N=round(c.pwm_period_s/h);U=N/2;
tr=round((c.trigger_phase_s+c.trigger_sync_s)/h);rank=round(c.rank_s/h);ap=round(c.aperture_s/h);J=tr+3*rank;
speedN=round(c.speed_period_s/h);origin=(round(plan.duration_s/h)-2*N)*h;
r=struct('schema',1,'scope',c.scope,'event_step_s',h,'trigger_phase_us',tr*h*1e6, ...
 'sample_offsets_CBA_us',(tr+(0:2)*rank+ap)*h*1e6,'jeos_phase_us',J*h*1e6, ...
 'speed_period_us',speedN*h*1e6,'speed_offset_us',(J+speedN-N)*h*1e6, ...
 'plot_window_s',[origin origin+2*N*h],'cases',struct([]), ...
 'events',struct('case_id',{},'case_label',{},'event',{},'time_s',{},'cycle_index',{},'phase_us',{}));traces=cell(1,3);
for k=1:3
 s=outputs{k};t=s.obs_pwm_timing.Time;a=teach_values(s.obs_adc_timing);p=teach_values(s.obs_pwm_timing);ticks=round(t/h);
 assert(isequal(t,s.obs_adc_timing.Time)&&size(a,2)==15&&size(p,2)==12&&all(diff(ticks)==1));
 assert(max(abs(a(:,1)-mod(ticks,N)*h))<1e-12);
 offsets=[tr tr+ap tr+rank+ap tr+2*rank+ap J];
 for col=2:6
  ix=find(a(:,col)>0);assert(numel(ix)>=2&&all(mod(ticks(ix),N)==offsets(col-1))&&all(diff(ticks(ix))==N));
 end
 assert(isequal(a(:,15)>0,a(:,6)>0));speed=find(a(:,14)>0);
 assert(~isempty(speed)&&all(mod(ticks(speed),speedN)==J+speedN-N)&&all(diff(ticks(speed))==speedN));
 C=round(c.compute_us(k)*1e-6/h);W=J+C;L=(floor(W/U)+1)*U;
 w=find(p(:,4)>0);u=find(p(:,5)>0);uev=find(p(:,3)>0);
 assert(numel(w)>=2&&numel(u)>=2&&all(mod(ticks(w),N)==W)&&all(mod(ticks(uev),U)==0));
 assert(all(mod(ticks(u),N)==mod(L,N))&&all(diff(p(w,6))==1)&&all(diff(p(u,7))==1));
 commands=struct('sequence',{},'jeos_time_s',{},'write_time_s',{},'apply_time_s',{},'compute_us',{},'write_wait_us',{},'jeos_to_apply_us',{});matchedErrors=[];
 tt=s.log_Tcm_applied.Time;actual=teach_values(s.log_Tcm_applied);at=round(tt/h);
 assert(all(diff(at)==1));[found,where]=ismember(ticks,at);assert(all(found));actual=actual(where,:);
 for iw=w(:)'
  seq=p(iw,6);active=find(p(:,7)==seq);if isempty(active),continue;end
  % Shadow at WRITE owns this sequence. A same-tick new write may have already
  % overwritten shadow at APPLY; reading that row would compare the wrong CCR.
  error=max(abs(actual(active,:)-p(iw,10:12)),[],'all');matchedErrors(end+1)=error; %#ok<AGROW>
  iu=u(p(u,7)==seq);if isempty(iu),continue;end;assert(isscalar(iu));
  jt=floor(ticks(iw)/N)*N+J;assert(ticks(iu)==floor(ticks(iw)/N)*N+L);
  assert(abs(p(iu,9)-(L-J)*h)<1e-12);
  commands(end+1)=struct('sequence',seq,'jeos_time_s',jt*h,'write_time_s',t(iw), ...
   'apply_time_s',t(iu),'compute_us',C*h*1e6,'write_wait_us',(L-W)*h*1e6, ...
   'jeos_to_apply_us',(L-J)*h*1e6); %#ok<AGROW>
 end
 assert(numel(commands)>=2&&~isempty(matchedErrors)&&max(matchedErrors)<1e-14);
 % At the coincident boundary, UEV occurs before the new write: pending stays 1.
 collision=w(p(w,3)>0);
 if W==U,assert(~isempty(collision)&&all(p(collision,8)==1)&&all(p(collision,7)<p(collision,6)));else,assert(isempty(collision));end
 ft=round(s.obs_current_fast.Time/h);truth=teach_values(s.obs_current_fast);assert(all(diff(ft)==1));j=find(a(:,6)>0);errors=zeros(numel(j),3);
 for phase=1:3
  sample=floor(ticks(j)/N)*N+tr+(3-phase)*rank+ap;[found,where]=ismember(sample,ft);assert(all(found));
  errors(:,phase)=a(j,phase+9)-truth(where,phase);
 end
 assert(max(abs(errors),[],'all')<1e-8);
 assert(abs(s.log_speed.Time(1)-J*h)<1e-12&&abs(median(diff(s.log_speed.Time))-N*h)<1e-12);
 row=struct('id',plan.cases(k).id,'label',plan.cases(k).label,'compute_us',C*h*1e6, ...
  'write_phase_us',W*h*1e6,'apply_phase_us',L*h*1e6,'boundary_margin_us',(U-W)*h*1e6, ...
  'write_wait_us',(L-W)*h*1e6,'jeos_to_apply_us',(L-J)*h*1e6, ...
  'sample_error_max_ABC_A',max(abs(errors),[],1),'applied_command_max_error_s',max(matchedErrors), ...
  'paired_command_count',numel(commands),'coincident_write_count',numel(collision),'commands',commands);
 if k==1,r.cases=row;else,r.cases(k)=row;end
 defs={'jeos','JEOS','adc',6;'write','CCR写入','pwm',4;'uev','UEV机会','pwm',3;'apply','CCR生效','pwm',5};
 for d=defs'
  data=p;if strcmp(d{3},'adc'),data=a;end
  for ix=find(data(:,d{4})>0)'
   r.events(end+1)=struct('case_id',row.id,'case_label',row.label,'event',d{1}, ...
    'time_s',t(ix),'cycle_index',floor(ticks(ix)/N),'phase_us',mod(ticks(ix),N)*h*1e6); %#ok<AGROW>
  end
 end
 traces{k}=struct('time_us',(t-origin)*1e6,'adc',a,'pwm',p,'window_us',[0 2*N*h*1e6]);
end
% Common ADC schedule, not a forced common physical trajectory.
for k=2:3
 assert(isequal(outputs{1}.obs_adc_timing.Time,outputs{k}.obs_adc_timing.Time));
 a=teach_values(outputs{1}.obs_adc_timing);b=teach_values(outputs{k}.obs_adc_timing);
 assert(isequal(a(:,[1:6 14 15]),b(:,[1:6 14 15])));
end
end
