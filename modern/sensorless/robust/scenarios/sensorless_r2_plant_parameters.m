function backup=sensorless_r2_plant_parameters(mdl,R_multiplier,L_multiplier)
% Local motor aliases only. Shared nominal motor/PI/observer values stay put.
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
validateattributes(R_multiplier,{'double'},{'scalar','real','finite','positive'});validateattributes(L_multiplier,{'double'},{'scalar','real','finite','positive'});
targets=find_system(mdl,'LookUnderMasks','all','BlockType','Fcn','Name','did_dt');assert(isscalar(targets));
root=get_param(targets{1},'Parent');ws=get_param(mdl,'ModelWorkspace');
backup=struct('root',root,'expressions',struct('path',{},'value',{}),'workspace',struct('name',{},'value',{}));
entries=whos(ws);for k=1:numel(entries),backup.workspace(k)=struct('name',entries(k).name,'value',getVariable(ws,entries(k).name));end
names={'Rs','Ld','Lq'};nominal=zeros(1,3);multipliers=[R_multiplier L_multiplier L_multiplier];updates={};
blocks=find_system(root,'LookUnderMasks','all','BlockType','Fcn');
for k=1:numel(blocks)
 expression=get_param(blocks{k},'Expr');updated=expression;
 for j=1:3,updated=regexprep(updated,['\<' names{j} '\>'],['R2plant_' names{j}]);end
 if ~strcmp(expression,updated)
  backup.expressions(end+1)=struct('path',blocks{k},'value',expression); %#ok<AGROW>
  updates{end+1}=updated; %#ok<AGROW>
 end
end
assert(numel(backup.expressions)==4,'Unexpected motor expressions; do not adapt unknown plant.');
for k=1:3,nominal(k)=getVariable(ws,names{k});assert(~hasVariable(ws,['R2plant_' names{k}]));end
for k=1:3,assignin(ws,['R2plant_' names{k}],nominal(k)*multipliers(k));end
for k=1:numel(updates),set_param(backup.expressions(k).path,'Expr',updates{k});end
for k=1:3,assert(isequaln(getVariable(ws,names{k}),nominal(k)));end
blocks=find_system(mdl,'LookUnderMasks','all','BlockType','Fcn');
for k=1:numel(blocks)
 if ~startsWith(blocks{k},[root '/']),assert(~contains(get_param(blocks{k},'Expr'),'R2plant_'));end
end
end
