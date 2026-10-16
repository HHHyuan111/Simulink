function r=pmsm_current_sampling_metrics(out,window)
% Read-only statistics of actual native-Scope data and recorded ADC events.
ds=out.native_current_sampling_scope;assert(ds.numElements==4,'需要电流与采样Scope的四组记录');
signals=cell(1,4);values=cell(1,4);width=[3 3 3 2];
for k=1:4
 signals{k}=ds.getElement(k).Values;values{k}=teach_values(signals{k});
 assert(size(values{k},2)==width(k)&&all(isfinite(values{k}),'all'));
 assert(isequal(signals{k}.Time,signals{1}.Time),'Scope时间轴不一致');
end
t=double(signals{1}.Time(:));h=gridStep(t);
if nargin<2||isempty(window),window=[max(t(1),t(end)-.0005) t(end)];end
validateattributes(window,{'double'},{'vector','numel',2,'finite','increasing'});
assert(window(1)>=t(1)-h*1e-6&&window(2)<=t(end)+h*1e-6,'统计区间超出Scope保留记录');
keep=t>=window(1)-h*1e-6&t<=window(2)+h*1e-6;assert(nnz(keep)>=2,'统计区间至少需要两个样本');
truth=values{1};chain=values{2};feedback=values{3};
assert(max(abs(chain(:,1)-truth(:,1)))<1e-10&&max(abs(chain(:,3)-feedback(:,1)))<1e-10,'A相链与三相记录不一致');
error=feedback(keep,:)-truth(keep,:);holdError=chain(keep,2)-truth(keep,1);
r=struct('schema',1,'requested_window_s',window(:)','actual_window_s',[t(find(keep,1)) t(find(keep,1,'last'))], ...
 'sample_count',nnz(keep),'grid_step_s',h,'phase_order',{{'A','B','C'}}, ...
 'feedback_minus_truth',statistics(error),'hold_minus_truth_A',statistics(holdError), ...
 'feedback_minus_hold_A',statistics(chain(keep,3)-chain(keep,2)), ...
 'truth_window_peak_to_peak_ABC_A',max(truth(keep,:),[],1)-min(truth(keep,:),[],1), ...
 'adc',struct,'analysis_source_sha256',teach_hash([mfilename('fullpath') '.m']), ...
 'definitions','Discrete equal-weight RMS, inclusive endpoints. Current errors include all enabled factors; peak-to-peak includes window trend. Event intervals are not inferred signal delays.');
% Full event log supplies predecessors outside the selected statistics window.
adc=out.obs_adc_timing;at=double(adc.Time(:));a=teach_values(adc);ah=gridStep(at);
assert(size(a,2)==15&&all(isfinite(a),'all')&&abs(ah-h)<h*1e-6,'需要完整时序网格上的15列ADC记录');
ix=round((t-at(1))/ah)+1;
assert(all(ix>=1&ix<=numel(at))&&max(abs(at(ix)-t))<h*1e-6);
assert(isequal(values{4},a(ix,[2 6])),'Scope事件与原ADC事件记录不一致');
events=a(:,2:6);assert(all(events==0|events==1,'all'),'ADC事件不是二值脉冲');
eventIndices=cell(1,5);
for k=1:5,eventIndices{k}=find(events(:,k)>0&[true;events(1:end-1,k)==0]);end
selectedJEOS=eventIndices{5};selectedJEOS=selectedJEOS(at(selectedJEOS)>=r.actual_window_s(1)-h*1e-6&at(selectedJEOS)<=r.actual_window_s(2)+h*1e-6);
% ADC phase is measured from the PWM cycle start. Pair within that cycle,
% never pair with the nearest arbitrary earlier pulse or across a missing cycle.
base=round((at-a(:,1))/h);columns=[1 4 3 2];names={'trigger_to_JEOS','A_end_to_JEOS','B_end_to_JEOS','C_end_to_JEOS'};
timing=struct;validity=struct;
for k=1:4
 delta=[];missing=0;ambiguous=0;ids=eventIndices{columns(k)};
 for j=selectedJEOS(:)'
  if nnz(base(eventIndices{5})==base(j))>1,ambiguous=ambiguous+1;continue;end
  candidates=ids(base(ids)==base(j)&at(ids)<=at(j)+h*1e-6);
  if isempty(candidates),missing=missing+1;elseif numel(candidates)>1,ambiguous=ambiguous+1;
  else,delta(end+1)=(at(j)-at(candidates))*1e6;end %#ok<AGROW>
 end
 summary=struct('available',~isempty(delta),'paired_count',numel(delta),'missing_count',missing,'ambiguous_count',ambiguous, ...
  'min_us',[],'mean_us',[],'max_us',[]);
 if ~isempty(delta),summary.min_us=min(delta);summary.mean_us=mean(delta);summary.max_us=max(delta);end
 timing.(names{k})=summary;
end
if ~isempty(selectedJEOS)
 validity=struct('sample_count',numel(selectedJEOS),'valid_fraction_ABC',mean(a(selectedJEOS,7:9)>0,1));
end
triggers=eventIndices{1};triggerCount=nnz(at(triggers)>=r.actual_window_s(1)-h*1e-6&at(triggers)<=r.actual_window_s(2)+h*1e-6);
r.adc=struct('trigger_count',triggerCount,'JEOS_count',numel(selectedJEOS),'intervals',timing,'window_validity',validity, ...
 'definitions','Intervals between recorded events in the same PWM cycle. Validity flags are separate; an aperture-end pulse does not prove a new valid sample was delivered.');
end
function h=gridStep(t)
assert(numel(t)>=2&&all(isfinite(t))&&all(diff(t)>0),'时间轴无效');h=median(diff(t));
assert(max(abs(diff(t)-h))<h*1e-6,'需要均匀时间网格');
end
function s=statistics(x)
s=struct('rms_A',sqrt(mean(x.^2,1)),'mean_A',mean(x,1),'max_abs_A',max(abs(x),[],1));
end
