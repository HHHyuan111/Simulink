function record=run_deadtime_demo(deadUs,rpm,loadNm,stopTime,options)
% Reproduce the three-way lesson without saving over the user's model.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
if nargin<1,deadUs=2;end
if nargin<2,rpm=600;end
if nargin<3,loadNm=.207;end
if nargin<4,stopTime=max(.08,.025+24/rpm);end
if nargin<5,options=struct;end
assert(isstruct(options)&&isscalar(options));assert(all(ismember(fieldnames(options),{'comp_us','hysteresis_A'})),'可选参数仅支持comp_us与hysteresis_A');
mdl='PMSM_FOC_R2026a';if ~bdIsLoaded(mdl),load_system(fullfile(root,[mdl '.slx']));end
mask=Simulink.Mask.get([mdl '/功率设置']);assert(~isempty(mask.getParameter('gate_on')),'Open the stage4 model first.');
if ~isfield(options,'comp_us'),options.comp_us=deadUs;end
if ~isfield(options,'hysteresis_A'),options.hysteresis_A=str2double(get_param([mdl '/功率设置'],'hysteresis_A'));end
validateattributes([options.comp_us options.hysteresis_A],{'double'},{'real','finite','nonnegative','vector','numel',2});
options.rpm=rpm;options.load_Nm=loadNm;
settings=teach_settings(mdl);mw=get_param(mdl,'ModelWorkspace');initial=struct;
for item=whos(mw)',initial.(item.name)=getVariable(mw,item.name);end
connection=Simulink.data.connect(get_param(mdl,'FileName'));wasDirty=hasUnsavedChanges(connection);
guard=onCleanup(@()restore(mw,initial,wasDirty));
work=fullfile(root,'.build','deadtime_demo');if ~isfolder(work),mkdir(work);end
record=struct('model_sha256',teach_hash(get_param(mdl,'FileName')),'pi_retuned',false,'workspace',initial,'cases',struct, ...
 'dead_us',deadUs,'rpm',rpm,'load_Nm',loadNm,'stop_time_s',stopTime,'used_options',options,'role','teaching, not measured board');
for row={'ideal',0,'off';'dead',deadUs,'off';'comp',deadUs,'on'}'
 fprintf('DEADTIME_DEMO %s\n',row{1});o=run_deadtime_case(mdl,row{2},row{3},stopTime,1,options);
 for key=o.who',value=o.get(key{1});if isa(value,'timeseries'),assert(all(isfinite(value.Data),'all')&&all(isfinite(value.Time)),'Nonfinite log %s',key{1});end,end
 record.cases.(row{1})=deadtime_metrics(o);save(fullfile(work,[row{1} '.mat']),'o','-v7.3');clear o;
end
restore(mw,initial,wasDirty);assert(isequaln(settings,teach_settings(mdl)));clear guard;
report=fullfile(folder,'report_demo');plot_deadtime_report(work,report,deadUs,rpm,loadNm,options);plot_three_phase_lesson(work,report,deadUs,rpm,loadNm,options);teach_writejson(fullfile(report,'record.json'),record);
fprintf('DEADTIME_DEMO_READY %s\n',fullfile(folder,'report_demo'));
end
function restore(mw,initial,wasDirty)
if ~wasDirty,reload(mw);return;end
for key=fieldnames(initial)',if ~isequaln(getVariable(mw,key{1}),initial.(key{1})),assignin(mw,key{1},initial.(key{1}));end,end
end
