function report=export_pmsm_experiment_examples(indexFile)
% Replot numeric archives into the curated gallery; never rewrite run packs.
here=fileparts(mfilename('fullpath'));defaultIndex=nargin<1;
if defaultIndex,indexFile=fullfile(here,'experiment_reproducibility_validation.json');end
index=jsondecode(fileread(indexFile));assert(index.all_passed);
pairIndex=fullfile(here,'experiment_paired_deadtime_validation.json');pairHash='';
lowIndex=fullfile(here,'experiment_low_speed_comp_validation.json');lowHash='';
noiseIndex=fullfile(here,'experiment_noise_filter_validation.json');noiseHash='';
timingIndex=fullfile(here,'experiment_timing_events_validation.json');timingHash='';
deadlineIndex=fullfile(here,'experiment_timing_deadline_validation.json');deadlineHash='';
windowIndex=fullfile(here,'experiment_sampling_window_validation.json');windowHash='';
encoderIndex=fullfile(here,'experiment_encoder_validation.json');encoderHash='';
speedIndex=fullfile(here,'experiment_encoder_speed_validation.json');speedHash='';
feedbackIndex=fullfile(here,'experiment_speed_feedback_validation.json');feedbackHash='';
speedFilterIndex=fullfile(here,'experiment_speed_filter_validation.json');speedFilterHash='';
if defaultIndex&&isfile(pairIndex)
 pairedRecord=jsondecode(fileread(pairIndex));assert(pairedRecord.all_passed);
 index.run_folders.gate_deadtime_pair=pairedRecord.run_folders.default_pair;pairHash=teach_hash(pairIndex);
end
if defaultIndex&&isfile(lowIndex)
 lowRecord=jsondecode(fileread(lowIndex));assert(lowRecord.all_passed);
 index.run_folders.low_speed_compensation=lowRecord.run_folders.default_three;lowHash=teach_hash(lowIndex);
end
if defaultIndex&&isfile(noiseIndex)
 noiseRecord=jsondecode(fileread(noiseIndex));assert(noiseRecord.all_passed);
 index.run_folders.noise_filter=noiseRecord.run_folders.default_three;noiseHash=teach_hash(noiseIndex);
end
if defaultIndex&&isfile(timingIndex)
 timingRecord=jsondecode(fileread(timingIndex));assert(timingRecord.all_passed);
 index.run_folders.timing_events=timingRecord.run_folders.default_pair;timingHash=teach_hash(timingIndex);
end
if defaultIndex&&isfile(deadlineIndex)
 deadlineRecord=jsondecode(fileread(deadlineIndex));assert(deadlineRecord.all_passed);
 index.run_folders.timing_deadline=deadlineRecord.run_folders.default_three;deadlineHash=teach_hash(deadlineIndex);
end
if defaultIndex&&isfile(windowIndex)
 windowRecord=jsondecode(fileread(windowIndex));assert(windowRecord.all_passed);
 index.run_folders.sampling_window=windowRecord.run_folders.default_three;windowHash=teach_hash(windowIndex);
end
if defaultIndex&&isfile(encoderIndex)
 encoderRecord=jsondecode(fileread(encoderIndex));assert(encoderRecord.all_passed);
 index.run_folders.encoder_angle=encoderRecord.run_folders.default_three;encoderHash=teach_hash(encoderIndex);
end
if defaultIndex&&isfile(speedIndex)
 speedRecord=jsondecode(fileread(speedIndex));assert(speedRecord.all_passed);
 index.run_folders.encoder_speed=speedRecord.run_folders.default_parallel;speedHash=teach_hash(speedIndex);
end
if defaultIndex&&isfile(feedbackIndex)
 feedbackRecord=jsondecode(fileread(feedbackIndex));assert(feedbackRecord.all_passed);
 index.run_folders.speed_feedback=feedbackRecord.run_folders.default_three;feedbackHash=teach_hash(feedbackIndex);
end
if defaultIndex&&isfile(speedFilterIndex)
 speedFilterRecord=jsondecode(fileread(speedFilterIndex));assert(speedFilterRecord.all_passed);
 index.run_folders.speed_filter=speedFilterRecord.run_folders.default_pair;speedFilterHash=teach_hash(speedFilterIndex);
end
stage=fullfile(fileparts(here),'.build',['gallery_' char(java.util.UUID.randomUUID)]);mkdir(stage);
report=struct('all_passed',false,'scope','从已校验MAT原始记录生成简洁展示图及独立文字说明；不改原始结果包。', ...
 'source_index_sha256',teach_hash(indexFile),'renderer_files',struct('path',{},'sha256',{}),'examples',struct);
if ~isempty(pairHash),report.additional_pair_index_sha256=pairHash;end
if ~isempty(lowHash),report.additional_low_speed_index_sha256=lowHash;end
if ~isempty(noiseHash),report.additional_noise_filter_index_sha256=noiseHash;end
if ~isempty(timingHash),report.additional_timing_events_index_sha256=timingHash;end
if ~isempty(deadlineHash),report.additional_timing_deadline_index_sha256=deadlineHash;end
if ~isempty(windowHash),report.additional_sampling_window_index_sha256=windowHash;end
if ~isempty(encoderHash),report.additional_encoder_index_sha256=encoderHash;end
if ~isempty(speedHash),report.additional_encoder_speed_index_sha256=speedHash;end
if ~isempty(feedbackHash),report.additional_speed_feedback_index_sha256=feedbackHash;end
if ~isempty(speedFilterHash),report.additional_speed_filter_index_sha256=speedFilterHash;end
for file={'plot_pmsm_speed_filter.m','pmsm_speed_filter_analysis.m'}
 report.renderer_files(end+1)=struct('path',file{1},'sha256',teach_hash(fullfile(here,file{1})));
end
for file={'plot_pmsm_speed_feedback.m','pmsm_speed_feedback_analysis.m'}
 report.renderer_files(end+1)=struct('path',file{1},'sha256',teach_hash(fullfile(here,file{1})));
end
for file={'plot_pmsm_encoder_speed.m','pmsm_encoder_speed_analysis.m'}
 report.renderer_files(end+1)=struct('path',file{1},'sha256',teach_hash(fullfile(here,file{1})));
end
for file={'plot_pmsm_encoder.m','pmsm_encoder_analysis.m'}
 report.renderer_files(end+1)=struct('path',file{1},'sha256',teach_hash(fullfile(here,file{1})));
end
for file={'plot_pmsm_sampling_window.m','pmsm_sampling_window_analysis.m'}
 report.renderer_files(end+1)=struct('path',file{1},'sha256',teach_hash(fullfile(here,file{1})));
end
for file={'plot_pmsm_timing_deadline.m','pmsm_timing_deadline_analysis.m'}
 report.renderer_files(end+1)=struct('path',file{1},'sha256',teach_hash(fullfile(here,file{1})));
end
for file={'plot_pmsm_experiment.m','plot_pmsm_mechanism.m','plot_pmsm_deadtime_pair.m','plot_pmsm_low_speed_comp.m','plot_pmsm_noise_filter.m','pmsm_noise_filter_analysis.m','plot_pmsm_timing_events.m','pmsm_timing_events_analysis.m','pmsm_deadtime_pair_alignment.m','pmsm_plot_style.m','export_pmsm_experiment_examples.m'}
 report.renderer_files(end+1)=struct('path',file{1},'sha256',teach_hash(fullfile(here,file{1})));
end
ids=fieldnames(index.run_folders);
for id=ids'
 folder=index.run_folders.(id{1});r=pmsm_experiment_verify(folder);plan=jsondecode(fileread(fullfile(folder,'plan.json')));
 outputs=cell(1,numel(r.cases));
 for k=1:numel(r.cases),data=load(fullfile(folder,[r.cases(k).id '.mat']),'signals');outputs{k}=data.signals;end
 target=fullfile(stage,id{1});mkdir(target);paired=strcmp(r.scenario.id,'gate_deadtime_pair');lowSpeed=strcmp(r.scenario.id,'low_speed_compensation');noiseFilter=strcmp(r.scenario.id,'noise_filter');
 timingEvents=strcmp(r.scenario.id,'timing_events');
 deadline=strcmp(r.scenario.id,'timing_deadline');
 samplingWindow=strcmp(r.scenario.id,'sampling_window');
 encoderAngle=strcmp(r.scenario.id,'encoder_angle');
 encoderSpeed=strcmp(r.scenario.id,'encoder_speed');
 speedFeedback=strcmp(r.scenario.id,'speed_feedback');
 speedFilter=strcmp(r.scenario.id,'speed_filter');
 if speedFilter
  plot_pmsm_speed_filter(outputs,plan,target);names={'comparison','response','mechanism'};
 elseif speedFeedback
  plot_pmsm_speed_feedback(outputs,plan,target);names={'comparison','response','mechanism'};
 elseif encoderSpeed
  plot_pmsm_encoder_speed(outputs,plan,target);names={'comparison','response','mechanism'};
 elseif encoderAngle
  plot_pmsm_encoder(outputs,plan,target);names={'comparison','response','mechanism'};
 elseif samplingWindow
  plot_pmsm_sampling_window(outputs,plan,target);names={'comparison','response','mechanism'};
 elseif deadline
  plot_pmsm_timing_deadline(outputs,plan,target);names={'comparison','response','mechanism'};
 elseif timingEvents
  plot_pmsm_timing_events(outputs,plan,target);names={'comparison','response','mechanism'};
 elseif noiseFilter
  plot_pmsm_noise_filter(outputs,plan,target);names={'comparison','response','mechanism'};
 elseif lowSpeed
  plot_pmsm_low_speed_comp(outputs,plan,target);names={'comparison','response','mechanism','startup'};
 elseif paired
  plot_pmsm_deadtime_pair(outputs,plan,target);names={'comparison','response','mechanism','startup'};
 else
  plot_pmsm_experiment(outputs,plan,target);names={'comparison','response'};
  if ismember(r.scenario.id,{'digital_filter','angle_bias','gate_deadtime'})
   plot_pmsm_mechanism(outputs,plan,target);names{end+1}='mechanism';
  end
 end
 extended=[];
 if speedFeedback&&~isempty(feedbackHash)&&isfield(feedbackRecord.run_folders,'custom_three')
  er=pmsm_experiment_verify(feedbackRecord.run_folders.custom_three);assert(strcmp(er.scenario.id,'speed_feedback'));
  ep=jsondecode(fileread(fullfile(er.folder,'plan.json')));eo=cell(1,3);
  for k=1:3,d=load(fullfile(er.folder,[er.cases(k).id '.mat']),'signals');eo{k}=d.signals;end
  extra=fullfile(stage,'speed_feedback_extended');mkdir(extra);plot_pmsm_speed_feedback(eo,ep,extra);
  copyfile(fullfile(extra,'response.png'),fullfile(target,'extended_response.png'));
  copyfile(fullfile(extra,'feedback.json'),fullfile(target,'extended_feedback.json'));
  names{end+1}='extended_response';
  extended=struct('source_run_folder',er.folder,'source_record_sha256',teach_hash(fullfile(er.folder,'record.json')), ...
   'factor_value',er.factor_value,'duration_s',er.duration_s,'statistics_window_s',er.statistics_window_s, ...
   'feedback_sha256',teach_hash(fullfile(target,'extended_feedback.json')));
  pmsm_experiment_verify(er.folder);
 end
 summary=struct('scope','简洁展示图与摘要；完整数值档案在source_run_folder。说明文字见notes.md。', ...
  'scenario',r.scenario,'factor_value',r.factor_value,'factor_unit',r.factor_unit,'duration_s',r.duration_s, ...
  'statistics_window_s',r.statistics_window_s,'plot_window_s',r.plot_window_s, ...
  'model_sha256',r.model_sha256,'baseline_manifest_sha256',r.baseline_manifest_sha256, ...
  'source_run_id',r.id,'source_run_folder',folder,'source_record_sha256',teach_hash(fullfile(folder,'record.json')), ...
  'numerical',r.numerical,'cases',struct('id',{},'label',{},'metrics',{}),'figure_sha256',struct, ...
  'renderer_files',report.renderer_files);
 for k=1:numel(r.cases),summary.cases(k)=struct('id',r.cases(k).id,'label',r.cases(k).label,'metrics',r.cases(k).metrics);end
 for name=names,summary.figure_sha256.(name{1})=teach_hash(fullfile(target,[name{1} '.png']));end
 if paired||lowSpeed,summary.comparison_contract=r.comparison_contract;summary.alignment_sha256=teach_hash(fullfile(target,'alignment.json'));end
 if noiseFilter,summary.comparison_contract=r.comparison_contract;summary.analysis_sha256=teach_hash(fullfile(target,'analysis.json'));end
 if timingEvents
  summary.comparison_contract=r.comparison_contract;summary.timing_sha256=teach_hash(fullfile(target,'timing.json'));summary.events_sha256=teach_hash(fullfile(target,'events.csv'));
 end
 if deadline
  summary.comparison_contract=r.comparison_contract;summary.deadline_sha256=teach_hash(fullfile(target,'deadline.json'));summary.events_sha256=teach_hash(fullfile(target,'events.csv'));
 end
 if samplingWindow
  summary.comparison_contract=r.comparison_contract;summary.window_sha256=teach_hash(fullfile(target,'window.json'));summary.samples_sha256=teach_hash(fullfile(target,'samples.csv'));
 end
 if encoderAngle
  summary.comparison_contract=r.comparison_contract;summary.encoder_sha256=teach_hash(fullfile(target,'encoder.json'));summary.encoder_samples_sha256=teach_hash(fullfile(target,'encoder_samples.csv'));
 end
 if encoderSpeed
  summary.comparison_contract=r.comparison_contract;summary.speed_sha256=teach_hash(fullfile(target,'speed.json'));summary.speed_samples_sha256=teach_hash(fullfile(target,'speed_samples.csv'));
 end
 if speedFeedback
  summary.comparison_contract=r.comparison_contract;summary.feedback_sha256=teach_hash(fullfile(target,'feedback.json'));summary.feedback_samples_sha256=teach_hash(fullfile(target,'feedback_samples.csv'));
 end
 if speedFilter
  summary.comparison_contract=r.comparison_contract;summary.speed_filter_sha256=teach_hash(fullfile(target,'speed_filter.json'));summary.filter_samples_sha256=teach_hash(fullfile(target,'filter_samples.csv'));
 end
 if isfield(r,'common_variables'),summary.common_variables=r.common_variables;end
 if ~isempty(extended),summary.extended=extended;end
 writeNotes(fullfile(target,'notes.md'),r,outputs{end});
 if ~isempty(extended)
  fid=fopen(fullfile(target,'notes.md'),'a','n','UTF-8');guard=onCleanup(@()fclose(fid));
  fprintf(fid,'## 扩展工况\n\n`extended_response.png`为另一份已验证结果：每机械转计数/窗口/长窗`%s`，每组%.3fs，统计窗口%.3f—%.3fs。三组共用该工况；它与默认50ms同时改变计数、窗口和长度，不能跨工况作单因素归因。\n\n',mat2str(extended.factor_value(:)'),extended.duration_s,extended.statistics_window_s(1),extended.statistics_window_s(2));
  fprintf(fid,'默认50ms中iq给定为8A限幅，真实闭环响应接近；延长后能观察退出限幅时计数阶梯向iq给定、真实q轴电流和转矩的传递。长窗口并非所有工况都更好。独立指标见extended_feedback.json，来源与配置见summary.json的extended字段。\n\n');
  fprintf(fid,'重跑：`run_pmsm_experiment(''speed_feedback'',%s,%.17g)`；完整原始结果目录：`%s`。\n',mat2str(extended.factor_value(:)'),extended.duration_s,extended.source_run_folder);clear guard;
 end
 summary.notes_sha256=teach_hash(fullfile(target,'notes.md'));teach_writejson(fullfile(target,'summary.json'),summary);
 report.examples.(id{1})=summary.figure_sha256;pmsm_experiment_verify(folder);
end
% Publish only after every scene has rendered completely.
for id=ids'
 target=fullfile(here,'experiments','examples',id{1});if ~isfolder(target),mkdir(target);end
 files=dir(fullfile(stage,id{1}));
 for file=files(:)'
  if file.isdir,continue;end
  [ok,message]=copyfile(fullfile(file.folder,file.name),fullfile(target,file.name),'f');assert(ok,'展示图更新失败：%s',message);
 end
 summary=jsondecode(fileread(fullfile(target,'summary.json')));
 for name=fieldnames(summary.figure_sha256)'
  assert(strcmp(teach_hash(fullfile(target,[name{1} '.png'])),summary.figure_sha256.(name{1})));
 end
 assert(strcmp(teach_hash(fullfile(target,'notes.md')),summary.notes_sha256));
 if isfield(summary,'alignment_sha256'),assert(strcmp(teach_hash(fullfile(target,'alignment.json')),summary.alignment_sha256));end
 if isfield(summary,'analysis_sha256'),assert(strcmp(teach_hash(fullfile(target,'analysis.json')),summary.analysis_sha256));end
 if isfield(summary,'timing_sha256')
  assert(strcmp(teach_hash(fullfile(target,'timing.json')),summary.timing_sha256));assert(strcmp(teach_hash(fullfile(target,'events.csv')),summary.events_sha256));
 end
 if isfield(summary,'deadline_sha256')
  assert(strcmp(teach_hash(fullfile(target,'deadline.json')),summary.deadline_sha256));assert(strcmp(teach_hash(fullfile(target,'events.csv')),summary.events_sha256));
 end
 if isfield(summary,'window_sha256')
  assert(strcmp(teach_hash(fullfile(target,'window.json')),summary.window_sha256));assert(strcmp(teach_hash(fullfile(target,'samples.csv')),summary.samples_sha256));
 end
 if isfield(summary,'encoder_sha256')
  assert(strcmp(teach_hash(fullfile(target,'encoder.json')),summary.encoder_sha256));assert(strcmp(teach_hash(fullfile(target,'encoder_samples.csv')),summary.encoder_samples_sha256));
 end
 if isfield(summary,'speed_sha256')
  assert(strcmp(teach_hash(fullfile(target,'speed.json')),summary.speed_sha256));assert(strcmp(teach_hash(fullfile(target,'speed_samples.csv')),summary.speed_samples_sha256));
 end
 if isfield(summary,'feedback_sha256')
  assert(strcmp(teach_hash(fullfile(target,'feedback.json')),summary.feedback_sha256));assert(strcmp(teach_hash(fullfile(target,'feedback_samples.csv')),summary.feedback_samples_sha256));
 end
 if isfield(summary,'speed_filter_sha256')
  assert(strcmp(teach_hash(fullfile(target,'speed_filter.json')),summary.speed_filter_sha256));assert(strcmp(teach_hash(fullfile(target,'filter_samples.csv')),summary.filter_samples_sha256));
 end
 if isfield(summary,'extended'),assert(strcmp(teach_hash(fullfile(target,'extended_feedback.json')),summary.extended.feedback_sha256));pmsm_experiment_verify(summary.extended.source_run_folder);end
end
report.all_passed=true;teach_writejson(fullfile(here,'experiment_gallery_validation.json'),report);
fprintf('CLEAN_GALLERY_ALL_PASS %d\n',numel(ids));
end

function writeNotes(path,r,s)
fid=fopen(path,'w','n','UTF-8');g=onCleanup(@()fclose(fid));
fprintf(fid,'# %s\n\n',r.scenario.name);
qualifier='为演示值';if strcmp(r.scenario.id,'encoder_angle'),qualifier='10000计数为固件配置，修改后的计数与延迟/零位为教学设置，未实板校准';end
if ismember(r.scenario.id,{'encoder_speed','speed_feedback'}),qualifier='10000计数与2拍来自固件配置，长窗口为教学扩展，未实板校准';end
if strcmp(r.scenario.id,'speed_filter'),qualifier='10000计数、2拍、200Hz为固件源码配置，其他值为教学设置，未实板校准';end
fprintf(fid,'因素大小：`%s` %s，%s。共%d组，每组运行%.3fs，统计窗口%.3f—%.3fs。\n\n', ...
 mat2str(r.factor_value(:)',5),r.factor_unit,qualifier,numel(r.cases),r.duration_s,r.statistics_window_s(1),r.statistics_window_s(2));
if ~ismember(r.scenario.id,{'low_speed_compensation','timing_events','timing_deadline','sampling_window'}),fprintf(fid,'时间域误差图窗口%.3f—%.3fs。\n\n',r.plot_window_s(1),r.plot_window_s(2));end
if strcmp(r.scenario.id,'speed_filter')
 fprintf(fid,'两组为同一计数窗口的无滤波/加滤波，各自闭环轨迹可以改变；角度、PI、初态、负载与真实事件时序相同，仅切换速度滤波。默认100ms用于观察限幅退出后的响应，未预设稳态或所有指标改善。\n\n');
 fprintf(fid,'沿用固件一阶递推a=1/(1+2πfcTs)、b=1-a，y=b*x+a*y_prev；滤波每50μs更新，速度PI每100μs消费。零滤波初态；无效时输入及发布零，内部状态按零输入递推，不回填真值。固件缺样保持、完整启动/故障策略及浮点位级等价不在本轮范围。\n\n');
 fprintf(fid,'平滑与滞后页只使用滤波组同一轨迹，将总误差分为滤后计数量化贡献、滤波动态误差和窗口平均误差。量化贡献变小不代表实际反馈总误差或闭环性能全面改善。对照页同一行纵轴一致，响应页两组曲线按各自记录时间显示。\n\n');
elseif strcmp(r.scenario.id,'speed_feedback')
 fprintf(fid,'三组分别为原速度、窗口测速、长窗测速。同一真实时序、原PI、理想角度与工况；仅速度来源或选用窗口不同，无速度滤波。每组闭环轨迹独立变化，不能把后两组当作同一计数轨迹。计数无效时用零并标无效，不回填真值；有效性尚未接启动或保护状态机。\n\n');
 fprintf(fid,'选择位于原速度任务保持之前：测速20kHz更新，速度PI10kHz执行，实际保持输出另有日志并按历史计数核对。测速反馈页显示真实速度与实际PI输入、iq给定；响应页保留各组物理结果；来源页显示启动、有效性及来源开关。未预设性能改善。8拍长窗为教学扩展，不能直接套到固件8槽历史缓存。\n\n');
elseif strcmp(r.scenario.id,'encoder_speed')
 fprintf(fid,'一次50ms仿真并行观测三个窗口，共用同一机械计数和物理轨迹，不是三次独立闭环运行。控制器保持理想角度与原速度反馈；仅新增计数测速观测，未加速度滤波或接管速度PI。真实时序读取20kHz/JEOS偏移28.875μs，原速度PI为10kHz/偏移78.875μs。\n\n');
 fprintf(fid,'计数测速页区分瞬时机械速度、相同窗口内机械真角度差分平均速度与整数计数差分速度；总误差分解为计数量化误差和窗口平均误差。历史不足时原始速度0且标无效，图中不连接这段无效估计；原始MAT保留零值与有效标志。所有单位为机械rpm，不乘极对数。\n\n');
 fprintf(fid,'本观测使用完整W+1端点后置有效；固件首次ready使用W次调用及零历史，初始化不逐位等价。8拍及更长由Simulink Delay支持，不能直接套到原8槽环形缓存。单圈解绕要求窗口内机械位移小于半圈，半圈方向歧义标无效；仅凭端点计数不能识别多圈混叠。\n\n');
elseif strcmp(r.scenario.id,'encoder_angle')
 fprintf(fid,'三组为理想角度、计数角度、同一计数加延迟。共同使用真实时序、62.5ns网格、24.375μs触发、28.875μs读取/JEOS、原PI和工况；速度反馈仍走原路径。机械计数方向与软件修正都为−1，默认零位为手动对齐假设；未模拟上电标定、Z相和ABZ电气边沿。原模型临时接入实际可展开模块，结束恢复原连接。\n\n');
 fprintf(fid,'角度页基于同拍机械真值与Park实际使用的角度，以最短角差在真角度附近展开。dq页区分真实转子坐标与控制器反馈；原有顺序电流采样也会造成反馈/真值差异，不把这些全部归因于编码器。运行状态页保留50ms启动，未预设稳态或性能提升。延迟起始无历史时输出0，有效标志为0；逐样本来源见encoder_samples.csv。\n\n');
elseif strcmp(r.scenario.id,'sampling_window')
 fprintf(fid,'三组为窗口关闭、无效置零、保持上次有效样本；同一真实时序、62.5ns网格、峰谷更新、5μs计算、原PI/3000rpm/24V/0.207N·m负载及零初态。触发%.6gμs、低侧稳定等待%.6gμs均为演示值，各组共同应用，不写回参考。其他附加因素关闭。\n\n',r.factor_value(1),r.factor_value(2));
 fprintf(fid,'电流页各列一组、各行一相，同相纵轴一致。灰线为事件网格原始物理电流，彩色阶梯为送入控制器的反馈，叉号为窗口无效标志；窗口关闭组即使标志无效仍接受物理真值，因此它是忽略窗口的对照，不代表低侧分流此时真的可测。运行状态页显示完整短时启动，不预设稳态或保持策略改善。\n\n');
elseif strcmp(r.scenario.id,'timing_deadline')
 fprintf(fid,'三组均为同一真实事件架构、62.5ns网格、峰谷双更新、10μs教学触发相位、原3000rpm/24V/0.207N·m负载、零初态和PI；仅计算耗时不同，其他附加因素关闭。JEOS为14.5μs。10μs触发相位和软件耗时未实测，不写回固定参考。\n\n');
 fprintf(fid,'更新边界页显示原始事件点，指令序号页显示已写入和已生效序号；相对时间0对应%.6fms。运行状态页保留各组闭环轨迹，默认50ms启动不作稳态验收。\n\n',r.plot_window_s(1)*1000);
elseif strcmp(r.scenario.id,'timing_events')
 fprintf(fid,'两组是简化模式与已有事件模式。共同使用原3000rpm、24V、0.207N·m负载、零初态及PI；其他附加因素关闭，低侧窗口和旧整拍延迟均关闭。计算耗时参数在两组相同，仅事件模式使用。\n\n');
 fprintf(fid,'模式切换包括1μs→62.5ns步长、载波方向、顺序采样、任务相位、CCR量化及预装载更新，不能将两组全部差异称为纯计算延迟或性能改善。运行状态页使用各组自己的记录时间轴，短时启动不作为稳态或完整性能验收。\n\n');
elseif strcmp(r.scenario.id,'noise_filter')
 fprintf(fid,'三组分别为无噪声无滤波、固定噪声、同一噪声加数字低通。共同保持原3000rpm、24V、0.207N·m负载、零初态、PI、理想桥及1μs步长。噪声RMS %.5gA，截止频率%.5gHz；后两组注入序列完全相同。其余附加因素关闭。\n\n',r.factor_value(1),r.factor_value(2));
 fprintf(fid,'三相电流页每列一组，每行一相；灰色为1μs真实电流，彩色阶梯为50μs反馈，同相纵轴一致。闭环响应页显示末20ms真实dq、转矩和速度，q轴给定仅显示滤波组；各组闭环轨迹与iq命令各自变化，未强制相同。\n\n');
elseif strcmp(r.scenario.id,'low_speed_compensation')
 fprintf(fid,'三组为零死区、死区、已有补偿。共同采用600rpm给定、24V母线、原0.207N·m负载、相同零初态、PI、详细续流桥和62.5ns步长。零死区→死区只改变gate_us；死区→补偿只改变comp_on。comp_us在三组都设为相同演示值，仅末组启用。\n\n');
 fprintf(fid,'电流按真实转子电角度对齐，保留同一完整周期内的1μs原始样本。电角度同拍记录，不按电流峰值平移、不平滑、不重采样。三组各自时间窗口见alignment.json。\n\n');
 fprintf(fid,'闭环响应页显示完整启动过程的转速、转矩及真实dq；q轴给定显示补偿组的命令。测量附加因素关闭，dq反馈与真值一致。末20ms指标基于50μs控制记录，不是全带宽开关纹波统计；不预设严格稳态，不据此计算或宣称THD。\n\n');
elseif strcmp(r.scenario.id,'gate_deadtime_pair')
 fprintf(fid,'两组均启用同一详细续流桥、62.5ns固定步长、相同PI、3000rpm给定、24V母线、负载及零初态。唯一设置差异为门极死区0/设定值，补偿和其他附加因素关闭。\n\n');
 fprintf(fid,'三相电流图以真实转子电角度为横轴，叠加同一完整电角周期的1μs电流原始样本；未按电流峰值平移，未平滑或插值重采样。真实电角度也按1μs记录，与电流同拍。周期与各自时间窗口见alignment.json。\n\n');
else
 fprintf(fid,'参考与实验保持相同PI、3000rpm给定、24V母线、负载及零初态。参考关闭所有附加因素，实验只开启`%s.%s`。\n\n',r.scenario.section,r.scenario.switch);
 fprintf(fid,'三相电流图：左列参考，右列实验；真实电流按1μs记录，测量电流按50μs控制周期记录，以阶梯显示。同相纵轴一致。\n\n');
end
if ~ismember(r.scenario.id,{'low_speed_compensation','noise_filter','timing_events','timing_deadline','sampling_window','encoder_angle','encoder_speed','speed_feedback','speed_filter'})
 fprintf(fid,'闭环响应图：“参考真值”为参考组物理dq；“实验真值”为实验组物理dq；“实验反馈”为控制器计算的dq。“测量误差”=实验组测量电流−同时刻真实电流；“电流变化”=实验组真值−参考组真值，含整体闭环轨迹变化，不直接等同于某次谐波。末20ms统计不预设已经严格稳态。\n\n');
end
fprintf(fid,'观察顺序：%s\n\n边界：%s\n\n',r.scenario.observe,r.scenario.boundary);
switch r.scenario.id
 case 'speed_filter'
  a=jsondecode(fileread(fullfile(fileparts(path),'speed_filter.json')));
  for k=1:2
   q=a.cases(k);fprintf(fid,'%s：截止%.6gHz，a=%.12g，递推核对误差%.6g rpm；末20ms原始计数量化RMS %.6g rpm、量化贡献RMS %.6g rpm、滤波动态误差RMS %.6g rpm、窗口平均误差RMS %.6g rpm、实际PI反馈误差RMS %.6g rpm；iq给定逐拍变化RMS %.6g A，转矩标准差%.6g N·m。\n\n',q.label,q.cutoff_hz,q.filter_a,q.filter_recursion_max_error_rpm,q.raw_quantization_rms_rpm,q.quantization_contribution_rms_rpm,q.filter_dynamic_error_rms_rpm,q.window_average_error_rms_rpm,q.feedback_error_rms_rpm,q.iq_command_step_rms_A,q.torque_std_Nm);
  end
  fprintf(fid,'iq逐拍变化包含20kHz记录中的保持零差；转矩标准差包含短时动态趋势，不是纯谐波幅值。filter_samples.csv按速度PI实际消费时刻记录滤波状态与来源，20kHz完整递推保存在MAT日志。\n\n');
 case 'speed_feedback'
  a=jsondecode(fileread(fullfile(fileparts(path),'feedback.json')));
  for k=1:3
   q=a.cases(k);fprintf(fid,'%s：选用%d拍候选，计数反馈开关%d；实际PI输入核对误差%.6g rpm，历史不足的速度任务样本%d个；末20ms反馈误差RMS %.6g rpm，iq给定逐拍变化RMS %.6g A，转矩标准差%.6g N·m，末端速度%.6g rpm。\n\n',q.label,q.window_ticks,q.feedback_on,q.pi_input_max_check_error_rpm,q.invalid_speed_task_samples,q.feedback_error_rms_rpm,q.iq_command_step_rms_A,q.torque_std_Nm,q.final_speed_rpm);
  end
  fprintf(fid,'默认50ms仍为启动加速，不能当作稳态性能；候选无效不代表原速度组输入无效。逐次实际PI输入及候选历史来源见feedback_samples.csv。\n\n');
 case 'encoder_speed'
  a=jsondecode(fileread(fullfile(fileparts(path),'speed.json')));
  for k=1:3
   q=a.windows(k);fprintf(fid,'%d拍：窗口%.6gμs，单计数间隔%.6g rpm；末20ms计数量化RMS %.6g rpm，窗口平均误差RMS %.6g rpm，总误差RMS %.6g rpm；前%d个记录历史不足。\n\n',q.window_ticks,q.window_s*1e6,q.rpm_per_count,q.quantization_rms_rpm,q.window_error_rms_rpm,q.total_error_rms_rpm,q.invalid_initial_samples);
  end
  fprintf(fid,'实际速度PI输入与原速度路径核对最大误差%.6g rpm。窗口更长可能降低计数阶梯，同时增加加速段平均滞后；不能把本观测图称为闭环性能改进。逐次窗口来源与误差分解见speed_samples.csv。\n\n',a.speed_control_input_max_error_rpm);
 case 'encoder_angle'
  a=jsondecode(fileread(fullfile(fileparts(path),'encoder.json')));
  for k=1:3
   q=a.cases(k);fprintf(fid,'%s：末20ms电角误差RMS %.6g°，峰值%.6g°；读取时来源年龄最大%.6gμs，初始无历史样本%d次。实际Park角核对误差%.6g rad，Park递推核对误差%.6g A。\n\n',r.cases(k).label,q.angle_rms_electrical_deg,q.angle_peak_electrical_deg,q.source_age_us,q.invalid_initial_samples,q.actual_park_angle_max_error_rad,q.park_formula_max_error_A);
  end
  fprintf(fid,'默认10000计数、5极对，单计数为0.036°机械角/0.18°电角；两拍延迟为100μs教学值。理想组也记录未采用的计数候选路径，其候选量化指标不代表控制器施加了量化。有效标志仅作诊断，尚未接启动或故障门控。\n\n');
 case 'sampling_window'
  a=jsondecode(fileread(fullfile(fileparts(path),'window.json')));
  fprintf(fid,'采样窗口页以%.6fms为相对时间0，显示第%d个PWM周期；选择规则：%s。门极历史为SW请求延迟一网格，与窗口模块输入一致；绿色/红色孔径分别为有效/无效。判定还要求孔径开始前满足稳定等待，不只检查孔径结束点。本场景门极死区关闭，不能据此宣称组合死区时已按实际门极校准。\n\n',a.example.cycle_start_time_s*1000,a.example.cycle_index,a.example.selection);
  fprintf(fid,'JEOS %.6gμs，C/B/A孔径结束 %.6g/%.6g/%.6gμs。三组各自闭环轨迹会改变调制和窗口，未强制共同真值；置零是教学近似，保持只沿用该相过去有效样本，初值为0，不是电流重构或主动保护。\n\n',a.jeos_phase_us,a.sample_end_CBA_us(1),a.sample_end_CBA_us(2),a.sample_end_CBA_us(3));
  for k=1:3
   q=a.cases(k);fprintf(fid,'%s：全程有效比例ABC [%s]；末20ms有效比例ABC [%s]；最大已知来源年龄ABC [%s]μs。孔径标志不一致%d个，接受样本真值/处理策略/反馈路径最大误差 %.6g/%.6g/%.6gA。\n\n',q.label,sprintf('%.6g ',q.valid_fraction_full_ABC),sprintf('%.6g ',q.valid_fraction_tail_ABC),sprintf('%.6g ',q.max_known_source_age_us_ABC),q.aperture_flag_mismatch_count,q.accepted_sample_max_error_A,q.policy_max_error_A,q.controller_path_max_error_A);
  end
  fprintf(fid,'samples.csv逐次记录三相孔径真值、有效标志、实际发布值、来源样本序号和年龄。sample_index从1开始，source_sample_index=0表示无历史有效来源的初值/置零，年龄NaN表示没有有效来源，不是丢失物理曲线。ADC诊断全程按JEOS快照；请求门极/物理电流按事件网格全程记录，实际门极/阈值尾部8000点，PWM诊断尾部4000点。\n\n');
 case 'timing_deadline'
  a=jsondecode(fileread(fullfile(fileparts(path),'deadline.json')));
  for k=1:3
   q=a.cases(k);fprintf(fid,'%s：计算%.6gμs，写入相位%.6gμs，生效%.6gμs，写后等待%.6gμs，JEOS至生效%.6gμs；配对%d条指令，实际阈值最大误差%.6g秒。\n\n',q.label,q.compute_us,q.write_phase_us,q.apply_phase_us,q.write_wait_us,q.jeos_to_apply_us,q.paired_command_count,q.applied_command_max_error_s);
  end
  fprintf(fid,'同拍先处理UEV再写CCR为已有模型约定；中间组写入虽正好25μs仍等50μs生效。误差核对按指令序号追溯写入时的阈值，不把生效时已经被下一条指令覆盖的影子CCR误认为本条指令。ADC各相与孔径结束原始物理电流对应，事件CSV/指令配对见events.csv/deadline.json。事件保留尾部4000点，实际阈值和物理电流尾部8000点。\n\n');
 case 'timing_events'
  a=jsondecode(fileread(fullfile(fileparts(path),'timing.json')));
  fprintf(fid,'周期事件页相对时间0对应%.6fms，显示%.6f—%.6fms两周期；一网格脉冲用事件点显示，未拉宽脉冲。CNT、ADC事件、控制/PWM事件和写入/生效序号来自原始记录，序号用于配对指令。\n\n',a.plot_window_s(1)*1000,a.plot_window_s(1)*1000,a.plot_window_s(2)*1000);
  fprintf(fid,'以PWM谷底为0：触发%.6gμs；C/B/A采样孔径结束分别%.6g/%.6g/%.6gμs；JEOS及快环%.6gμs；CCR写入%.6gμs。双更新机会每%.6gμs一次，但新指令需先写入才能生效。\n\n',a.trigger_phase_s*1e6,a.sample_offsets_ABC_s(3)*1e6,a.sample_offsets_ABC_s(2)*1e6,a.sample_offsets_ABC_s(1)*1e6,a.jeos_phase_s*1e6,a.write_phase_s*1e6,a.update_opportunity_period_s*1e6);
  fprintf(fid,'电流任务周期%.6gμs、偏移%.6gμs；速度任务周期%.6gμs、偏移%.6gμs。执行相位与日志采样周期分开记录。计算%.6gμs，写入等待%.6gμs，JEOS至生效%.6gμs；不能把这些时间重复相加或统一叫一拍延迟。\n\n',a.current_period_s*1e6,a.current_offset_s*1e6,a.speed_period_s*1e6,a.speed_offset_s*1e6,a.compute_us,a.write_wait_us,a.jeos_to_apply_us);
  fprintf(fid,'采样电流页只显示事件模式：真实电流按事件网格记录，采样保持值为JEOS发布的ABC值。每相采样已与其各自孔径结束时的原始物理电流核对；异步三相样本之和不必为零。窗口有效标志只作诊断，本场景未屏蔽或保持无效样本。\n\n');
  fprintf(fid,'ADC/PWM事件保留尾部4000点，物理电流及实际生效阈值保留尾部8000点，并非完整高频启动档案。已核对%d次写入/生效配对及实际输出阈值；事件清单见events.csv，详细时间和误差见timing.json。触发相位和计算耗时尚未实测，模型不包含完整CPU并发调度与跨周期积压。\n\n',a.paired_command_count);
 case 'noise_filter'
  a=jsondecode(fileread(fullfile(fileparts(path),'analysis.json')));
  fprintf(fid,'已有滤波器位于abc采样后、Clarke/Park前，递推y[k]=(1−α)x[k]+αy[k−1]，零初态，α=exp(−2πfcTs)。噪声按50μs周期生成，种子为%d、%d、%d。\n\n',a.seed_ABC);
  fprintf(fid,'滤波观测页的“滤后分量”是对本组实际注入噪声应用同一离散滤波器的线性分解；不是另一次仿真，也不是对展示曲线作平滑。滤波确定性误差=H(本组真实电流)−本组真实电流，总测量误差是它与滤后噪声之和，已核对重构残差。因此总误差不直接叫噪声。该分解只隔离注入项的直接滤波贡献，噪声改变物理电流的闭环间接影响仍包含在本组真值中。\n\n');
  fprintf(fid,'幅相曲线由当前离散系数解析计算，不是实测。标称电频率%.6gHz处，幅值%.6gdB，相位%.6g°，对应相位延迟%.6gμs；此延迟不是额外独立加入的ADC或计算延迟。\n\n',a.nominal_electrical_frequency_Hz,a.nominal_gain_dB,a.nominal_phase_deg,a.nominal_phase_delay_us);
  fprintf(fid,'末20ms，滤波组注入噪声RMS为[%s]A，滤后噪声分量RMS为[%s]A；总测量误差RMS为[%s]A。这些是50μs记录的有限窗口统计，不预设严格稳态，也不作为全带宽纹波或THD。\n\n',sprintf('%.6g ',a.cases(3).noise_injected_rms_ABC_A),sprintf('%.6g ',a.cases(3).noise_component_rms_ABC_A),sprintf('%.6g ',a.cases(3).measurement_error_rms_ABC_A));
  for k=1:3
   fprintf(fid,'%s：真实id跟踪RMS %.6gA，真实iq跟踪RMS %.6gA，转矩标准差%.6gN·m。波形变平滑不等于真实闭环指标都改善。\n\n',r.cases(k).label,r.cases(k).metrics.id_true_tracking_rms_A,r.cases(k).metrics.iq_true_tracking_rms_A,r.cases(k).metrics.torque_std_Nm);
  end
 case 'low_speed_compensation'
  info=jsondecode(fileread(fullfile(fileparts(path),'alignment.json')));
  fprintf(fid,'补偿观测的相电压、dq电压和极性均来自已有补偿模块的诊断输出，按50μs控制周期记录。极性使用测量电流与既有滞环阈值，近零时保持上次极性。相电压修正由Vdc×tcomp/Ts×极性计算，再减三相均值并变换到dq，在最终限压前合入。补偿时间匹配物理死区只是演示设定，并不代表最优标定。\n\n');
  fprintf(fid,'A相过零图使用165—195°的原始角度电流。启动页的差值都相对零死区组，累计角度不折回±180°。各组载波相对于转子的相位仍可能不同，瞬时纹波差不直接等同于谐波畸变。\n\n');
  for k=1:3
   fprintf(fid,'%s：角周期%d，窗口%.6f—%.6fms，%d个原始样本；末20ms转矩标准差%.6fN·m，真实iq跟踪RMS %.6fA。\n\n', ...
    r.cases(k).label,info.cycle_index,info.cases(k).time_window_s(1)*1000,info.cases(k).time_window_s(2)*1000,info.cases(k).sample_count, ...
    r.cases(k).metrics.torque_std_Nm,r.cases(k).metrics.iq_true_tracking_rms_A);
  end
 case 'digital_filter'
  fprintf(fid,'机制图中滤波改变量=滤波后−滤波前，包含幅相变化，不能全部称作噪声。幅频/相频曲线由当前离散系数解析计算，并非实测。未注入采样噪声。本滤波器位于abc采样后、Clarke/Park前。\n\n');
 case 'angle_bias'
  fprintf(fid,'电角度显示包含0/360°正常环绕。角度误差为测量角−真实角的最短角差。dq真值使用真实转子坐标，反馈使用控制器角度。机械误差乘极对数得到电角误差。\n\n');
 case 'gate_deadtime'
  t=s.obs_dead_gates.Time;origin=max(t(1),t(end)-100e-6);
  fprintf(fid,'门极图相对时间0对应仿真时刻%.6fms。请求是调制输出，实际是死区处理后的门极；空白标志1表示上下管同时关闭。补偿关闭。参考步长1μs，实验步长62.5ns，桥路径也不同；电流差不能全部归因为死区，指标变小不表示死区改善性能。\n\n',origin*1000);
 case 'gate_deadtime_pair'
  info=jsondecode(fileread(fullfile(fileparts(path),'alignment.json')));t=s.obs_dead_gates.Time;origin=max(t(1),t(end)-100e-6);
  fprintf(fid,'电流图选定电角周期编号%d：零死区组%.6f—%.6fms，死区组%.6f—%.6fms；原始采样点数分别为%d、%d。\n\n', ...
   info.cycle_index,info.cases(1).time_window_s(1)*1000,info.cases(1).time_window_s(2)*1000, ...
   info.cases(2).time_window_s(1)*1000,info.cases(2).time_window_s(2)*1000,info.cases(1).sample_count,info.cases(2).sample_count);
  fprintf(fid,'机制页门极图相对时间0对应%.6fms。启动相位页的转速差、电角度差均为死区组−零死区组；累计电角度差不折回±180°。角度积分核对用50μs转速记录做梯形积分，允许积分离散误差。\n\n',origin*1000);
  fprintf(fid,'本组末端累计电角度差%.6f°；速度积分得到%.6f°；积分残差%.6f°。这表示启动累计的运动轨迹差，不能当成固定控制延迟。\n\n',info.startup.final_electrical_angle_difference_deg,info.startup.integrated_speed_difference_deg,info.startup.final_integration_residual_deg);
  fprintf(fid,'角度对齐用于区分累计转子位置差与电流相对转子的波形变化；两组仍各自闭环运行，并非强制同一速度轨迹。样本RMS仅统计选定角周期，不称为THD或严格稳态指标。详细桥近零带仍是数值近似。\n\n');
end
fprintf(fid,'数值与日志设置：%s\n\n',r.numerical.note);
fprintf(fid,'原始结果编号：`%s`。模型SHA256：`%s`。图片及摘要属于派生展示材料，完整原始结果包未修改。\n',r.id,r.model_sha256);
end
