function fig=open_pmsm_speed_probe_time(folder,index,amplitude)
if nargin<1,folder=[];end;if nargin<2,index=2;end;if nargin<3,amplitude=1;end
folder=pmsm_speed_probe_folder(folder);verify_pmsm_speed_probe(folder);a=load(fullfile(folder,'analysis.mat'),'p');p=a.p;
assert(ismember(index,1:numel(p.frequency_Hz))&&ismember(amplitude,1:numel(p.amplitudes_rpm)));
s=load(fullfile(folder,sprintf('probe_%d_raw.mat',amplitude)));raw=s.raw;seg=p.segments(index);
tick=round(raw.speed_ref.Time/p.sample_time_s);ix=tick>=seg.end_tick-3*p.samples_per_period(index)&tick<seg.end_tick;
for key=fieldnames(raw)'
 ts=raw.(key{1});assert(isequal(ts.Time,raw.speed_ref.Time));data=teach_values(ts);
 clipped.(key{1})=timeseries(data(ix,:),ts.Time(ix));
end
fig=plot_pmsm_speed_step(clipped,p,p.amplitudes_rpm(amplitude));fig.Name='速度环正弦响应';
layout=findall(fig,'-isa','matlab.graphics.layout.TiledChartLayout');title(layout,sprintf('速度环正弦响应 · %g Hz',seg.frequency_Hz));
axesList=findall(fig,'Type','axes');xlim(axesList(1),[clipped.speed_ref.Time(1) clipped.speed_ref.Time(end)]*1000);
fig.UserData=struct('kind','speed_sine_probe','frequency_Hz',seg.frequency_Hz,'source_indices',find(ix),'amplitude_rpm',p.amplitudes_rpm(amplitude));
menu=uimenu(fig,'Text','给定幅值');for k=1:numel(p.amplitudes_rpm)
 uimenu(menu,'Text',sprintf('%g rpm',p.amplitudes_rpm(k)),'MenuSelectedFcn',@(~,~)open_pmsm_speed_probe_time(folder,index,k));
end
end
