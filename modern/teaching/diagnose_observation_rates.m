function diagnose_observation_rates
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';work=fullfile(root,'.build','observation_stage');
sources={fullfile(root,[mdl '.slx']),fullfile(work,'candidate',[mdl '.slx'])};results=cell(1,2);
for k=1:2
 load_system(sources{k});set_param(mdl,'SimulationCommand','update');feval(mdl,[],[],[],'compile');
 paths=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block');r=struct('sid',{},'path',{},'rate',{});
 for j=1:numel(paths)
  r(end+1)=struct('sid',Simulink.ID.getSID(paths{j}),'path',paths{j},'rate',{get_param(paths{j},'CompiledSampleTime')}); %#ok<AGROW>
 end
 feval(mdl,[],[],[],'term');results{k}=r;close_system(mdl,0);
end
teach_writejson(fullfile(work,'rates.json'),results);
end
