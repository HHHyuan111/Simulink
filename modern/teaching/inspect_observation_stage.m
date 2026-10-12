function inspect_observation_stage
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
work=fullfile(root,'.build','observation_stage');if ~isfolder(work),mkdir(work);end
source=fullfile(root,[mdl '.slx']);assert(strcmp(teach_hash(source),'88f7d9b63986307df6dad91373373b8fe2107cfde5414aea55637b9909006611'));
copyfile(source,fullfile(work,'before.slx'));
load_system(source);guard=onCleanup(@()close_system(mdl,0));
before=teach_snapshot(mdl);teach_writejson(fullfile(work,'snapshot.json'),before);
mw=get_param(mdl,'ModelWorkspace');fid=fopen(fullfile(work,'workspace.m'),'w','n','UTF-8');fprintf(fid,'%s',mw.MATLABCode);fclose(fid);
in=Simulink.SimulationInput(mdl);in=setModelParameter(in,'StopTime','0.12');baseline=sim(in);
save(fullfile(work,'before.mat'),'before','baseline','-v7');
fprintf('OBSERVATION_INVENTORY_PASS blocks=%d\n',numel(before.blocks));
end
