function p=pmsm_experiment_plan(id,value,duration)
% Resolve complete fixed comparisons before running or mutating any model.
if nargin<1,id='current_bias';end
c=pmsm_experiment_catalog;ix=find(strcmp({c.id},id));assert(isscalar(ix),'未知实验；请从pmsm_experiment_catalog选择。');s=c(ix);
if nargin<2||isempty(value),value=s.default_value;end
if nargin<3||isempty(duration),if strcmp(id,'speed_filter'),duration=.1;elseif ismember(id,{'timing_events','timing_deadline','sampling_window','encoder_angle','encoder_speed','speed_feedback'}),duration=.05;else,duration=.2;end,end
if ischar(value)||isstring(value)
 text=char(value);assert(~isempty(regexp(text,'^\s*\[?\s*[-+0-9.eE,;\s]+\]?\s*$','once')),'只填写数字或ABC数值向量，不填写表达式。');
 text=regexprep(text,'[\[\],;]',' ');value=str2double(regexp(strtrim(text),'\s+','split'));
end
validateattributes(value,{'double'},{'real','finite','vector','numel',s.size});value=value(:)';
assert(all(value>=s.minimum & value<=s.maximum),'因素大小超出当前场景允许范围。');
if s.integer,assert(all(value==round(value)),'当前场景参数必须为整数。');end
validateattributes(duration,{'double'},{'scalar','real','finite','>=',.05,'<=',1});
state=pmsm_reference('read');manifest=pmsm_reference('verify');dt=getValue(state,'dt');
if strcmp(id,'digital_filter'),assert(value<1/(2*dt),'滤波频率须小于控制采样频率的一半。');end
if ismember(id,{'gate_deadtime','gate_deadtime_pair','low_speed_compensation'})
 assert(abs(value/.0625-round(value/.0625))<1e-8,'门极死区须按0.0625μs步进设置。');
 assert(value*1e-6<getValue(state,'Ts')/4,'门极死区须小于PWM周期的四分之一。');
 assert(abs(getValue(state,'Ld')-getValue(state,'Lq'))<1e-12,'当前详细桥要求Ld=Lq。');
end
assert(abs(duration/dt-round(duration/dt))<1e-8,'实验时长必须为控制周期的整数倍。');
p=struct('schema',1,'scenario',s,'value',value(:)','duration_s',duration,'statistics_window_s',[duration-.02 duration], ...
 'plot_window_s',[duration-.01 duration],'baseline_manifest',manifest,'baseline_state',state,'cases',struct('id',{},'label',{},'changes',{},'configuration',{}));
p.logging_overrides=struct('signal',{'obs_adc_timing','obs_pwm_timing','obs_dead_gates','obs_dead_requested','obs_dead_bridge'}, ...
 'parameter','MaxDataPoints','value','4000');
p.numerical=struct('reference_fixed_step_s',1e-6,'factor_fixed_step_s',1e-6, ...
 'note','两组共同截取高频诊断尾部4000点；控制记录及1μs电流记录完整保留。');
if strcmp(id,'gate_deadtime')
 p.numerical.factor_fixed_step_s=62.5e-9;
 p.numerical.note=[p.numerical.note ' 门极死区启用详细桥与细网格；因素差值含数值/桥路径变化，不作纯死区归因。'];
end
if strcmp(id,'noise_filter')
 assert(value(2)<1/(2*dt),'滤波频率须小于控制采样频率的一半。');
 labels={'参考','噪声','滤波'};ids={'reference','factor','filtered'};
 for k=1:3
  config=state.configuration;noiseState='off';filterState='off';
  if k>=2,noiseState='on';end
  if k==3,filterState='on';end
  keys={'noise_rms','filter_hz','noise_on','filter_on'};
  values={mat2str(value(1),17),mat2str(value(2),17),noiseState,filterState};
  changes=struct('section',{},'parameter',{},'value',{});
  for j=1:numel(keys)
   ix=strcmp({config.rows.section},s.section)&strcmp({config.rows.key},keys{j});assert(sum(ix)==1);
   config.rows(ix).value=values{j};changes(end+1)=struct('section',s.section,'parameter',keys{j},'value',values{j});
  end
  active=pmsm_check_switches(config);assert(numel(active)==k-1);
  p.cases(k)=struct('id',ids{k},'label',labels{k},'changes',changes,'configuration',config);
 end
 p.numerical.note='三组共同使用理想桥、1μs固定步长、原3000rpm及负载；控制记录50μs，物理电流记录1μs；相同初态、PI与固定随机种子。';
 p.comparison_contract=struct('kind','same_noise_three_cases','noise_rms_A',value(1),'filter_hz',value(2), ...
  'noise_seed',str2double(config.rows(strcmp({config.rows.key},'noise_seed')).value), ...
  'control_period_s',dt,'fixed_step_s',1e-6,'adjacent_changes',{{'noise_on','filter_on'}}, ...
  'filter','已有abc采样后一阶数字低通；零滤波初态；其余附加因素关闭。', ...
  'analysis','线性叠加分解滤后噪声与滤波确定性误差；总测量误差不等同于噪声。');
 return
end
if strcmp(id,'speed_filter')
 assert(all(value(1:2)==round(value(1:2))),'计数和窗口必须为整数。');assert(value(3)<1/(2*dt),'速度滤波频率须小于读取频率的一半。');
 p=pmsm_experiment_plan('speed_feedback',[value(1:2) 4*value(2)],duration);p.scenario=s;p.value=value;
 p.cases=p.cases([2 2]);p.cases(1).id='reference';p.cases(1).label='无滤波';p.cases(2).id='factor';p.cases(2).label='加滤波';
 p.encoder_configurations=p.encoder_configurations([2 2]);p.feedback_configurations=p.feedback_configurations([2 2]);
 p.filter_configurations=repmat(struct('filter_on','off','cutoff_hz',num2str(value(3),17)),1,2);p.filter_configurations(2).filter_on='on';
 p.comparison_contract.kind='speed_filter_pair';p.comparison_contract.feedback_on=[true true];p.comparison_contract.window_choice=[2 2];
 p.comparison_contract.speed_filter='firmware_first_order';p.comparison_contract.filter_on=[false true];p.comparison_contract.cutoff_hz=value(3);
 p.comparison_contract.filter_a=1/(1+2*pi*value(3)*dt);p.comparison_contract.filter_b=1-p.comparison_contract.filter_a;
 p.comparison_contract.filter_update_s=dt;p.comparison_contract.filter_initial_state=0;
 p.comparison_contract.filter_source='AxDr_L control_filter.c: a=fs/(fs+2*pi*fc), b=1-a, y=b*x+a*y_prev；ctrl_fb_update每快环调用';
 p.comparison_contract.filter_invalid_policy='输入及发布零，内部状态仍按零输入递推；未模拟固件缺样保持与完整启动/故障状态机';
 p.comparison_contract.scope='两组同一机械计数、窗口、真实时序、PI、初态、角度和工况，只切换速度滤波；各自闭环轨迹可改变，非位级等价。';
 p.numerical.note='两组同一真实时序、62.5ns网格和JEOS计数读取；指定窗口计数测速接速度PI，仅滤波开关不同。滤波20kHz，原速度保持/PI10kHz，零初态，角度沿用原路径；控制记录完整，高频诊断尾部4000点。不保存SLX。';return
end
if strcmp(id,'speed_feedback')
 p=pmsm_experiment_plan('encoder_speed',value,duration);p.scenario=s;
 one=p.cases;cfg=p.encoder_configurations;p.cases=repmat(one,1,3);p.encoder_configurations=repmat(cfg,1,3);
 ids={'reference','factor','long'};labels={'原速度','窗口测速','长窗测速'};
 p.feedback_configurations=repmat(struct('feedback_on','off','window_choice','2'),1,3);
 for k=1:3,p.cases(k).id=ids{k};p.cases(k).label=labels{k};end
 p.feedback_configurations(2).feedback_on='on';p.feedback_configurations(3).feedback_on='on';p.feedback_configurations(3).window_choice='3';
 p.comparison_contract.kind='speed_feedback_three_cases';
 p.comparison_contract.feedback_on=[false true true];p.comparison_contract.window_choice=[2 2 3];
 p.comparison_contract.speed_filter='off';p.comparison_contract.angle_feedback='原角度';
 p.comparison_contract.initialization='计数反馈在完整历史前使用零并标无效，不回填真值；有效性仅观测，尚无启动门控或故障状态机';
 p.comparison_contract.scope='相同真实时序、原PI、角度、初态与工况，仅改变速度来源及选用窗口；各组物理轨迹独立变化，无速度滤波。';
 p.numerical.note=[p.numerical.note ' 本场景计数测速接原速度任务保持之前，三组独立闭环；实际PI输入另行记录。'];return
end
if strcmp(id,'encoder_speed')
 assert(value(3)>value(2),'长窗口必须大于指定窗口。');assert(duration<=.1,'测速首批观测限制为50—100ms。');
 p=pmsm_experiment_plan('encoder_angle',[value(1) 2 0],duration);p.scenario=s;p.value=value;p.cases=p.cases(1);p.cases.label='同一轨迹';p.encoder_configurations=p.encoder_configurations(1);
 p.speed_configuration=struct('speed_on','on','window_ticks',num2str(value(2),17),'long_ticks',num2str(value(3),17));
 base=p.comparison_contract;p.comparison_contract=struct('kind','same_run_three_speed_windows_shadow', ...
  'counts_per_mechanical_turn',value(1),'window_ticks',[1 value(2:3)],'read_period_s',dt,'read_offset_s',base.read_offset_s, ...
  'speed_period_s',getValue(state,'teaching_Ts_speed'),'event_step_s',base.event_step_s, ...
  'rpm_per_count_step',60./(value(1)*dt*[1 value(2:3)]),'firmware_commit',base.firmware_commit, ...
  'firmware_window_ticks',2,'firmware_history_depth',8,'source','control_cycle_step在有效位置拍按foc_fs喂入speed_est_step；速度PI与测量宏不是该喂入频率', ...
  'initialization','本观测要求W+1个读取端点，前W个标无效并输出0；固件ready计数为W且历史初值0，不宣称启动逐位等价', ...
  'scope','同一物理轨迹的三路机械计数窗口差分，仅观测；不接速度PI、不加速度滤波、不模拟丢帧。8拍及更长为教学扩展，不能直接套用固件8槽历史缓存。');
 p.numerical.note=[p.numerical.note ' 一次仿真并行三路测速；角度仍走理想路径，编码器仅提供观测计数；机械速度单位rpm，不乘极对数。'];
 return
end
if strcmp(id,'encoder_angle')
 assert(value(1)==round(value(1))&&value(2)==round(value(2)),'计数与延迟拍数必须为整数。');
 assert(duration<=.1,'编码器首批实验每组限制为50—100ms。');
 h=62.5e-9;adc=getValue(state,'timing_adc_cfg');jeos=24.375e-6+3*adc(8);
 p.numerical.reference_fixed_step_s=h;p.numerical.factor_fixed_step_s=h;
 p.numerical.note='三组同一真实时序、62.5ns网格、JEOS角度读取；速度反馈沿用原路径。原模型临时接入可展开的编码器模块，结束恢复连接，不保存SLX。';
 p.encoder_configurations=repmat(struct('encoder_on','off','counts',num2str(value(1),17), ...
  'sensor_dir','-1','direction','-1','zero_deg',num2str(value(3),17),'delay_on','off','delay_cycles',num2str(value(2),17)),1,3);
 p.encoder_configurations(2).encoder_on='on';p.encoder_configurations(3).encoder_on='on';p.encoder_configurations(3).delay_on='on';
 p.comparison_contract=struct('kind','mechanical_count_angle_three_cases','counts_per_mechanical_turn',value(1), ...
  'pole_pairs',getValue(state,'p'),'sensor_direction',-1,'software_direction',-1,'electrical_zero_deg',value(3), ...
  'delay_cycles',value(2),'delay_s',value(2)*dt,'read_period_s',dt,'read_offset_s',jeos,'event_step_s',h, ...
  'quantization_rule','raw=mod(floor(sensor_dir*theta_m*N/(2*pi)),N); corrected=mod(direction*raw,N)', ...
  'initial_delayed_packet',[0 0 0 0],'speed_feedback','沿用原速度路径；尚未使用计数测速', ...
  'firmware_commit','48d6e86814ac6657b1313b4c92ef24c88f492e07', ...
  'parameter_sources','10000计数及方向−1来自固件配置；零位默认手动对齐为0；两拍延迟为教学值，非实测', ...
  'scope','机械计数与同步读取的功能模型；不含ABZ边沿、输入滤波、Z相、自动对齐及位级等价。');
 labels={'理想角度','计数角度','计数加延迟'};ids={'reference','factor','delayed'};
 for k=1:3
  config=state.configuration;changes=struct('section',{},'parameter',{},'value',{});
  keys={'real_on','trigger_us','sync_us','compute_us','update_mode'};vals={'on','24.375','0','5','峰谷双更新（RCR=0）'};
  for j=1:numel(keys)
   ix=strcmp({config.rows.section},'时序设置')&strcmp({config.rows.key},keys{j});assert(sum(ix)==1);
   config.rows(ix).value=vals{j};changes(end+1)=struct('section','时序设置','parameter',keys{j},'value',vals{j});
  end
  assert(isequal(pmsm_check_switches(config),{'时序设置.real_on'}));
  p.cases(k)=struct('id',ids{k},'label',labels{k},'changes',changes,'configuration',config);
 end
 return
end
if strcmp(id,'sampling_window')
 assert(duration<=.1,'窗口实验全程记录事件网格物理电流与门极，当前限制每组0.05—0.1秒。');
 assert(all(abs(value/.0625-round(value/.0625))<1e-8),'触发相位和稳定等待须按0.0625μs步进设置。');
 adc=getValue(state,'timing_adc_cfg');adc=adc(:)';h=62.5e-9;jeos=value(1)*1e-6+3*adc(8);
 assert(jeos+5e-6<dt,'整组采样和5μs计算须在当前PWM周期内结束。');
 % Full JEOS snapshots establish the history of every held sample. Full
 % physical current and requested gates verify every aperture independently.
 p.logging_overrides(end+1)=struct('signal','obs_adc_timing','parameter','SampleTime','value','timing_control_sample');
 p.logging_overrides(end+1)=struct('signal','obs_adc_timing','parameter','MaxDataPoints','value','inf');
 for name={'obs_current_fast','obs_dead_requested','obs_dead_gates','log_Tcm_applied'}
  cap='8000';if ismember(name{1},{'obs_current_fast','obs_dead_requested'}),cap='inf';end
  p.logging_overrides(end+1)=struct('signal',name{1},'parameter','SampleTime','value','timing_h');
  p.logging_overrides(end+1)=struct('signal',name{1},'parameter','MaxDataPoints','value',cap);
 end
 p.numerical.reference_fixed_step_s=h;p.numerical.factor_fixed_step_s=h;
 p.numerical.note='三组同一真实时序、62.5ns网格和峰谷双更新；ADC诊断全程按JEOS快照（不是全速事件记录），物理电流/请求门极按事件网格全程记录，实际门极/生效阈值保留尾部8000点，PWM诊断尾部4000点；默认每组50ms启动。';
 p.comparison_contract=struct('kind','same_timing_window_three_cases','trigger_phase_s',value(1)*1e-6, ...
  'settle_s',value(2)*1e-6,'compute_us',5,'trigger_sync_s',0,'aperture_s',adc(7),'rank_s',adc(8), ...
  'pwm_period_s',dt,'speed_period_s',getValue(state,'teaching_Ts_speed'),'event_step_s',h,'jeos_phase_s',jeos, ...
  'update_mode','峰谷双更新（RCR=0）','initial_gate_history',[0 1 0 1 0 1], ...
  'gate_history_ticks',1,'initial_held_value_A',[0 0 0],'parameters_measured',false, ...
  'scope','沿用请求门极的一网格历史检查完整孔径；本场景门极死区关闭。置零/保持仅为教学策略，未实现电流重构及主动保护。');
 ids={'reference','factor','held'};labels={'窗口关闭','无效置零','保持样本'};
 for k=1:3
  config=state.configuration;changes=struct('section',{},'parameter',{},'value',{});win='off';hold='off';
  if k>=2,win='on';end;if k==3,hold='on';end
  keys={'real_on','trigger_us','sync_us','compute_us','settle_us','update_mode','window_on','invalid_hold_on'};
  values={'on',mat2str(value(1),17),'0','5',mat2str(value(2),17),'峰谷双更新（RCR=0）',win,hold};
  for j=1:numel(keys)
   ix=strcmp({config.rows.section},s.section)&strcmp({config.rows.key},keys{j});assert(sum(ix)==1);
   config.rows(ix).value=values{j};changes(end+1)=struct('section',s.section,'parameter',keys{j},'value',values{j});
  end
  assert(numel(pmsm_check_switches(config))==k);
  p.cases(k)=struct('id',ids{k},'label',labels{k},'changes',changes,'configuration',config);
 end
 return
end
if strcmp(id,'timing_deadline')
 adc=getValue(state,'timing_adc_cfg');adc=adc(:)';h=62.5e-9;
 assert(all(abs(value/.0625-round(value/.0625))<1e-8),'计算耗时须按0.0625μs步进设置。');
 trigger=10e-6;sync=0;jeos=trigger+3*adc(8);
 assert(all(jeos+value*1e-6<dt));p.plot_window_s=[duration-2*dt duration];
 for name={'obs_current_fast','log_Tcm_applied'}
  p.logging_overrides(end+1)=struct('signal',name{1},'parameter','SampleTime','value','timing_h');
  p.logging_overrides(end+1)=struct('signal',name{1},'parameter','MaxDataPoints','value','8000');
 end
 p.numerical.reference_fixed_step_s=h;p.numerical.factor_fixed_step_s=h;
 p.numerical.note='三组同一真实事件模型、62.5ns步长、10μs教学触发相位和峰谷双更新；仅compute_us不同。事件尾部4000点，物理电流/实际生效指令尾部8000点，控制日志完整保留。';
 p.comparison_contract=struct('kind','same_event_architecture_deadline_three_cases','compute_us',value, ...
  'trigger_phase_s',trigger,'trigger_sync_s',sync,'aperture_s',adc(7),'rank_s',adc(8), ...
  'pwm_period_s',dt,'speed_period_s',getValue(state,'teaching_Ts_speed'),'event_step_s',h, ...
  'jeos_phase_s',jeos,'update_mode','峰谷双更新（RCR=0）','boundary_phase_s',dt/2, ...
  'trigger_phase_measured',false,'compute_time_measured',false, ...
  'scope','同架构受控计算耗时对照；UEV先处理、CCR后写入为已有模型同拍约定，不代表实板零裕量保证。');
 ids={'reference','factor','late'};labels={'赶上','同边界','错过'};
 for k=1:3
  config=state.configuration;changes=struct('section',{},'parameter',{},'value',{});
  keys={'real_on','trigger_us','sync_us','update_mode','compute_us'};
  values={'on','10','0','峰谷双更新（RCR=0）',mat2str(value(k),17)};
  for j=1:numel(keys)
   ix=strcmp({config.rows.section},s.section)&strcmp({config.rows.key},keys{j});assert(sum(ix)==1);
   config.rows(ix).value=values{j};changes(end+1)=struct('section',s.section,'parameter',keys{j},'value',values{j});
  end
  assert(isequal(pmsm_check_switches(config),{'时序设置.real_on'}));
  p.cases(k)=struct('id',ids{k},'label',labels{k},'changes',changes,'configuration',config);
 end
 return
end
if strcmp(id,'timing_events')
 adc=getValue(state,'timing_adc_cfg');adc=adc(:)';h=62.5e-9;
 assert(abs(value/.0625-round(value/.0625))<1e-8,'计算耗时须按0.0625μs步进设置。');
 trigger=str2double(state.configuration.rows(strcmp({state.configuration.rows.key},'trigger_us')).value)*1e-6;
 sync=str2double(state.configuration.rows(strcmp({state.configuration.rows.key},'sync_us')).value)*1e-6;
 jeos=trigger+sync+3*adc(8);assert(jeos+value*1e-6<dt,'采样与计算须在当前PWM周期内完成。');
 p.plot_window_s=[duration-2*dt duration];
 % Explicitly record the source-grid truth and applied command near the end.
 for name={'obs_current_fast','log_Tcm_applied'}
  p.logging_overrides(end+1)=struct('signal',name{1},'parameter','SampleTime','value','timing_h');
  p.logging_overrides(end+1)=struct('signal',name{1},'parameter','MaxDataPoints','value','8000');
 end
 p.numerical.factor_fixed_step_s=h;
 p.numerical.note='参考1μs，事件模式62.5ns；ADC/PWM事件尾部4000点，物理电流与生效指令按各自求解网格保留尾部8000点；控制记录保留全程，各组时间轴分别使用。';
 p.comparison_contract=struct('kind','event_observation_not_pure_delay','compute_us',value, ...
  'trigger_phase_s',trigger,'trigger_sync_s',sync,'aperture_s',adc(7),'rank_s',adc(8), ...
  'pwm_period_s',dt,'speed_period_s',getValue(state,'teaching_Ts_speed'),'event_step_s',h, ...
  'jeos_phase_s',jeos,'ccr_write_phase_s',jeos+value*1e-6, ...
  'update_mode',state.configuration.rows(strcmp({state.configuration.rows.key},'update_mode')).value, ...
  'trigger_phase_measured',false,'compute_time_measured',false, ...
  'scope','记录已有真实时序；模式切换还含数值网格、载波方向、顺序采样、任务相位和CCR更新，不据此归因纯延迟或优化性能。');
end
base=state.configuration;variant=base;
for pair={s.switch,'on';s.parameter,mat2str(value(:)',17)}'
 ix=find(strcmp({variant.rows.section},s.section)&strcmp({variant.rows.key},pair{1}));assert(isscalar(ix));variant.rows(ix).value=pair{2};
end
pmsm_check_switches(base);active=pmsm_check_switches(variant);assert(isequal(active,{[s.section '.' s.switch]}),'固定单因素场景只能开启一个开关。');
changes=struct('section',{s.section,s.section},'parameter',{s.switch,s.parameter},'value',{'on',mat2str(value(:)',17)});
p.cases(1)=struct('id','reference','label','固定参考','changes',changes([]),'configuration',base);
p.cases(2)=struct('id','factor','label',s.name,'changes',changes,'configuration',variant);
if strcmp(id,'timing_events')
 reference=base;ix=strcmp({reference.rows.key},'compute_us');reference.rows(ix).value=mat2str(value,17);
 p.cases(1).configuration=reference;p.cases(1).changes=changes(2);p.cases(1).label='简化模式';p.cases(2).label='事件模式';
end
if ismember(id,{'gate_deadtime_pair','low_speed_compensation'})
 zero=variant;ix=strcmp({zero.rows.section},s.section)&strcmp({zero.rows.key},s.parameter);zero.rows(ix).value='0';
 zeroChanges=changes;zeroChanges(2).value='0';
 p.cases(1)=struct('id','reference','label','零死区','changes',zeroChanges,'configuration',zero);
 p.cases(2).label='死区';
 assert(isequal(pmsm_check_switches(zero),pmsm_check_switches(variant)));
 p.numerical.reference_fixed_step_s=62.5e-9;p.numerical.factor_fixed_step_s=62.5e-9;
 p.numerical.note='两组均启用同一详细桥与62.5ns步长，仅门极死区大小不同；高频门极保留尾部4000点；真实电流与角度完整按1μs记录。';
 p.logging_overrides(end+1)=struct('signal','log_theta_true','parameter','SampleTime','value','T');
 p.comparison_contract=struct('kind','same_bridge_same_grid','reference_deadtime_us',0,'factor_deadtime_us',value, ...
  'bridge','详细续流桥','fixed_step_s',62.5e-9,'alignment','真实转子电角度；同一完整电角周期；原始1μs样本不平滑、不重采样', ...
  'startup','同一零初态启动；累计角度差单独展示，保持两组各自闭环轨迹。');
end
if strcmp(id,'low_speed_compensation')
 p.common_variables=struct('name','n','value',600);
 p.cases(3)=p.cases(2);p.cases(3).id='compensated';p.cases(3).label='补偿';
 for k=1:3
  c=p.cases(k).configuration;
  for setting={'n','600';'comp_us',mat2str(value,17);'comp_on','off'}'
   key=setting{1};v=setting{2};if strcmp(key,'comp_on'),if k==3,v='on';else,v='off';end,end
   ix=strcmp({c.rows.key},key);assert(sum(ix)==1);c.rows(ix).value=v;
  end
  pmsm_check_switches(c);p.cases(k).configuration=c;
  p.cases(k).changes(end+1)=struct('section','功率设置','parameter','comp_us','value',mat2str(value,17));
  compState='off';if k==3,compState='on';end
  p.cases(k).changes(end+1)=struct('section','功率设置','parameter','comp_on','value',compState);
 end
 p.logging_overrides(end+1)=struct('signal','obs_dead_comp','parameter','MaxDataPoints','value','inf');
 p.numerical.note='三组均启用同一详细桥与62.5ns步长、600rpm和相同原负载；仅死区与已有补偿策略不同；真实电流/角度按1μs完整记录，补偿诊断按控制周期记录。';
 p.comparison_contract.kind='same_bridge_grid_low_speed_three_cases';p.comparison_contract.rpm=600;
 p.comparison_contract.compensation_deadtime_us=value;p.comparison_contract.compensation='已有测量电流极性滞环前馈；算法与PI不变。';
end
end

function value=getValue(s,name)
ix=find(strcmp({s.workspace_values.name},name));assert(isscalar(ix));value=s.workspace_values(ix).value;
end
