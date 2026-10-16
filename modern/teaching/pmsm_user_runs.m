function result=pmsm_user_runs(action,topic,out)
% Manual capture and overlay in native SDI. No simulation, callback or model edits.
[rows,layout,titleText]=pmsm_user_run_signals(topic);key=['PMSMUserRuns_' topic];state=struct('id',{},'fingerprint',{},'name',{});
if isappdata(groot,key),state=getappdata(groot,key);end
valid=Simulink.sdi.getAllRunIDs;state=state(ismember([state.id],valid));result=[];
for k=1:numel(state),run=Simulink.sdi.getRun(state(k).id);state(k).name=run.Name;end
switch action
 case 'keep'
  if nargin<3
   assert(evalin('base','exist(''out'',''var'')==1'),'请先运行模型，生成本次out。');out=evalin('base','out');
  end
  assert(isa(out,'Simulink.SimulationOutput'),'本次out不是仿真输出。');meta=out.SimulationMetadata;
  assert(strcmp(meta.ModelInfo.ModelName,'PMSM_FOC_R2026a'),'out不是当前PMSM模型的输出。');
  assert(ismember(meta.ExecutionInfo.StopEvent,{'ReachedStopTime','StopCommand','ModelStop'}),'仿真尚未正常结束，请检查诊断信息。');
  ds=Simulink.SimulationData.Dataset;digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(uint8(meta.TimingInfo.WallClockTimestampStart));digest.update(uint8(meta.TimingInfo.WallClockTimestampStop));digest.update(typecast(double(meta.TimingInfo.TotalElapsedWallTime),'uint8'));
  for k=1:size(rows,1)
   source=out.get(rows{k,2});assert(isa(source,'timeseries'));t=double(source.Time(:));v=teach_values(source);column=abs(rows{k,3});y=v(:,column);
   if rows{k,3}<0
    second=out.get(rows{k,6});assert(isequal(source.Time,second.Time),'误差信号时间不一致。');v=teach_values(second);y=y-v(:,column);
   end
   assert(numel(t)>=2&&all(diff(t)>0)&&all(isfinite(y)),'本次输出缺失或无效。');
   ts=timeseries(y,t,'Name',rows{k,1});ts.DataInfo.Interpolation=tsdata.interpolation('zoh');ds=ds.addElement(ts,rows{k,1});
   digest.update(typecast(t(:),'uint8'));digest.update(typecast(y(:),'uint8'));
  end
  fingerprint=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));found=find(strcmp({state.fingerprint},fingerprint),1);
  if isempty(found)
   sequenceKey=[key '_Sequence'];sequence=0;if isappdata(groot,sequenceKey),sequence=getappdata(groot,sequenceKey);end;sequence=sequence+1;
   name=[titleText num2str(sequence)];id=Simulink.sdi.createRun(name,'vars',ds);run=Simulink.sdi.getRun(id);setappdata(groot,sequenceKey,sequence);
   run.Description=['手动保留的实际输出；仿真结束时刻 ' meta.TimingInfo.WallClockTimestampStop '。未把点击保留时的参数冒充运行参数；可在SDI中重命名并导出会话。'];
   state(end+1)=struct('id',id,'fingerprint',fingerprint,'name',name);found=numel(state);
  end
  setappdata(groot,key,state);result=state(found);
 case 'compare'
  assert(~isempty(state),'请先运行并点击“保留本次运行”。');setappdata(groot,key,state);
  selected=state(max(1,end-1):end);Simulink.sdi.clearAllSubPlots;Simulink.sdi.setSubPlotLayout(layout(1),layout(2));colors=[0 .447 .741;.84 .15 .16];
  for k=1:numel(selected)
   run=Simulink.sdi.getRun(selected(k).id);assert(run.SignalCount==size(rows,1));
   for j=1:run.SignalCount
    sig=run.getSignalByIndex(j);index=find(strcmp(rows(:,1),sig.Name));assert(isscalar(index));sig.LineColor=colors(k,:);sig.LineDashed=rows{index,5};sig.LineWidth=1;sig.InterpMethod='zoh';
    group=rows{index,4};row=floor((group-1)/layout(2))+1;col=mod(group-1,layout(2))+1;sig.plotOnSubPlot(row,col,true);
   end
  end
  Simulink.sdi.view;result=selected;
 otherwise,error('pmsm:UserRunAction','未知操作。');
end
end
