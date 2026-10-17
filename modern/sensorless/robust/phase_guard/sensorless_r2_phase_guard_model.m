function record=sensorless_r2_phase_guard_model(mdl)
% Add local packet qualification. Original R1 observer states are unchanged.
here=fileparts(mfilename('fullpath'));root=[mdl '/无感观测'];p=[root '/有效判断'];
spec=jsondecode(fileread(fullfile(fileparts(fileparts(here)),'contracts/nonideal_r2_phase_guard_design.json')));
assert(spec.design.phase_limit_electrical_deg==5&&spec.design.engineering_emf_angle_allowance_deg==3);
mask=Simulink.Mask.get(root);mask.addParameter('Name','packet_phase_limit_deg','Prompt','发布瞬时相位门槛 [电角度°]',...
 'Type','edit','Value','5','Enabled','off','Tunable','off');
path=[p '/瞬时相位许可'];add_block('simulink/User-Defined Functions/MATLAB Function',path,'Position',[920 100 1100 430]);
rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',path);chart.Script=fileread(fullfile(here,'blocks/sless_r2_phase_guard_block.m'));
chart.ChartUpdate='DISCRETE';chart.SampleTime='timing_control_sample';chart.VectorOutputs1D=false;
dimensions={'theta','1';'vector','[2 1]';'quality','1';'sample_valid','1';'reset','1';'cfg','[1 18]';'packet_valid','1';'diagnostic','[8 1]'};
for k=1:size(dimensions,1)
 data=chart.find('-isa','Stateflow.Data','Name',dimensions{k,1});data.Props.Array.Size=dimensions{k,2};data.DataType='double';
 if ismember(dimensions{k,1},{'quality','sample_valid','reset','packet_valid'}),data.DataType='boolean';end
end
tags={'SLessV2_theta','SLessV2_vector','SLessV2_valid','SLessV2_sample_valid','SLessV2_reset','SLessV2_cfg'};
for k=1:numel(tags)
 name=['相位许可来源' num2str(k)];add_block('simulink/Signal Routing/From',[p '/' name],...
  'Position',[690 80+60*k 875 105+60*k],'GotoTag',tags{k});add_line(p,[name '/1'],['瞬时相位许可/' num2str(k)],'autorouting','on');
end
output_tags={'SLessV2_packet_valid','SLessV2_phase_guard'};
for k=1:2
 name=['相位许可发布' num2str(k)];add_block('simulink/Signal Routing/Goto',[p '/' name],...
  'Position',[1160 150+90*k 1390 175+90*k],'GotoTag',output_tags{k},'TagVisibility','scoped');
 add_line(p,['瞬时相位许可/' num2str(k)],[name '/1'],'autorouting','on');
 add_block('simulink/Signal Routing/Goto Tag Visibility',[root '/可见域_' output_tags{k}],...
  'Position',[25+300*(k-1) 1170 300+300*(k-1) 1195],'GotoTag',output_tags{k},'ShowName','off');
end
set_param([root '/发布许可/观测锁定'],'GotoTag','SLessV2_packet_valid');
observe=[root '/观测'];add_block('simulink/Signal Routing/From',[observe '/瞬时相位诊断'],...
 'Position',[1900 1320 2110 1345],'GotoTag','SLessV2_phase_guard');
add_block('simulink/Sinks/To Workspace',[observe '/记录_瞬时相位许可'],...
 'Position',[2180 1315 2440 1350],'VariableName','obs_sless_r2_phase_guard','SaveFormat','Timeseries',...
 'SampleTime','timing_control_sample','MaxDataPoints','inf');add_line(observe,'瞬时相位诊断/1','记录_瞬时相位许可/1','autorouting','on');
record=struct('kind','instantaneous_packet_phase_qualification','phase_limit_deg',5,'emf_allowance_assumed_deg',3,...
 'existing_quality_retained',true,'estimator_states_unchanged',true,'truth_input',false,'additional_scoped_tags',2);
end
