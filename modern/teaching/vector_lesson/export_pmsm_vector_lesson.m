function record=export_pmsm_vector_lesson(data,caseIndex,windowIndex,time_s,showAxes,folder)
% Derived, versioned outputs. Never writes into the source experiment folder.
here=fileparts(mfilename('fullpath'));teach=fileparts(here);
if nargin<5,showAxes=true;end
if nargin<6||isempty(folder)
 stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));id=char(java.util.UUID.randomUUID);
 folder=fullfile(here,'exports',[stamp '_' id(1:8)]);
end
assert(~isfolder(folder),'导出目录已存在；请选择新的目录，保留已有档案。');
% Reverify provenance before exporting, including archives changed since opening.
fresh=pmsm_vector_load(data.folder);
assert(isequaln(fresh,data),'载入后源档案或派生数据发生变化。');mkdir(folder);
record=struct('schema',1,'kind','pmsm_coordinates_export_v1','status','running','folder',folder, ...
 'matlab_version',version,'source_folder',data.folder,'source_id',data.source_id, ...
 'source_record_sha256',data.source_record_sha256,'model_sha256',data.model_sha256, ...
 'source_files',data.source_files,'source_case_labels',{{data.cases.label}}, ...
 'derived_source_files',struct('path',{},'sha256',{}),'files',struct('path',{},'sha256',{}), ...
 'sampling_period_s',data.sample_period_s,'resampling','none','show_coordinate_axes',logical(showAxes));
names={'pmsm_vector_transform.m','pmsm_vector_load.m','pmsm_vector_frame.m','pmsm_vector_plot.m','export_pmsm_vector_lesson.m','verify_pmsm_vector_export.m'};
for name=names,record.derived_source_files(end+1)=struct('path',['vector_lesson/' name{1}],'sha256',teach_hash(fullfile(here,name{1})));end
record.derived_source_files(end+1)=struct('path','open_pmsm_vector_lesson.m','sha256',teach_hash(fullfile(teach,'open_pmsm_vector_lesson.m')));
teach_writejson(fullfile(folder,'record.json'),record);
try
 frame=pmsm_vector_frame(data,caseIndex,windowIndex,time_s);record.selected_frame=rmfield(frame,{'indices','history_indices'});
 f=figure('Visible','off','Color','white','Position',[60 60 1360 920]);guard=onCleanup(@()close(f));
 tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');ax=gobjects(1,4);
 for k=1:4,ax(k)=nexttile(tl);end
 pmsm_vector_plot(ax,data,frame,showAxes);title(tl,'坐标与矢量','FontName','Microsoft YaHei','FontSize',18,'FontWeight','normal');
 exportgraphics(f,fullfile(folder,'snapshot.png'),'Resolution',150);clear guard;
 f=figure('Visible','off','Color','white','Position',[60 60 1400 900]);guard=onCleanup(@()close(f));
 tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');colors=[.12 .40 .72;.89 .34 .11];
 for row=1:2
  c=data.cases(row);ii=frame.indices;
  for col=1:2
   a=nexttile(tl);hold(a,'on');plot(a,c.time_s(ii)*1000,c.dq_true_A(ii,col),'Color',colors(1,:),'LineWidth',1.1);
   plot(a,c.time_s(ii)*1000,c.dq_feedback_A(ii,col),'Color',colors(2,:),'LineWidth',1.1);
   plot(a,c.time_s(ii)*1000,c.dq_reference_A(ii,col),'--','Color',[.3 .32 .35],'LineWidth',1);
   letter='d';limits=frame.limits.d_A;if col==2,letter='q';limits=frame.limits.q_A;end
   title(a,[c.label ' · ' letter '轴']);xlabel(a,'时间 [ms]');ylabel(a,'电流 [A]');
   xlim(a,frame.bounds_s*1000);ylim(a,limits);grid(a,'on');legend(a,{'真实','反馈','给定'});
  end
 end
 title(tl,'角度偏置','FontName','Microsoft YaHei','FontSize',18,'FontWeight','normal');pmsm_plot_style(f);
 exportgraphics(f,fullfile(folder,'comparison.png'),'Resolution',150);clear guard;
 writetable(data.dictionary,fullfile(folder,'signals.csv'),'Encoding','UTF-8');
 windows=data.windows;windows=rmfield(windows,'indices');teach_writejson(fullfile(folder,'windows.json'),windows);
 metrics=struct([]);
 for k=1:2
  c=data.cases(k);ii=frame.indices;
  currentMetrics=struct('case_id',c.id,'label',c.label,'bounds_s',frame.bounds_s,'samples',numel(ii), ...
   'mean_true_dq_A',mean(c.dq_true_A(ii,:),1),'mean_feedback_dq_A',mean(c.dq_feedback_A(ii,:),1), ...
   'mean_angle_error_deg',mean(c.angle_error_deg(ii)),'transform_residual',c.residual);
  if k==1,metrics=currentMetrics;else,metrics(k)=currentMetrics;end
 end
 teach_writejson(fullfile(folder,'metrics.json'),metrics);
 copyfile(fullfile(here,'带读说明.md'),fullfile(folder,'notes.md'));
 for name={'snapshot.png','comparison.png','signals.csv','windows.json','metrics.json','notes.md'}
  record.files(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(folder,name{1})));
 end
 record.status='completed';teach_writejson(fullfile(folder,'record.json'),record);verify_pmsm_vector_export(folder);
catch err
 record.status='failed';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
end
