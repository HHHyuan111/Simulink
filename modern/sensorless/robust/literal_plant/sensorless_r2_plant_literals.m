function backup=sensorless_r2_plant_literals(mdl,R_multiplier,L_multiplier)
% Same local motor coefficients, without adding ModelWorkspace bindings.
validateattributes(R_multiplier,{'double'},{'scalar','positive','finite'});validateattributes(L_multiplier,{'double'},{'scalar','positive','finite'});
targets=find_system(mdl,'LookUnderMasks','all','BlockType','Fcn','Name','did_dt');assert(isscalar(targets));root=get_param(targets{1},'Parent');ws=get_param(mdl,'ModelWorkspace');
names={'Rs','Ld','Lq'};nominal=zeros(1,3);for k=1:3,nominal(k)=getVariable(ws,names{k});end
actual=nominal.*[R_multiplier L_multiplier L_multiplier];literals=cell(1,3);
for k=1:3,literals{k}=['(' sprintf('%.17g',actual(k)) ')'];assert(str2double(literals{k}(2:end-1))==actual(k));end
backup=struct('root',root,'nominal',nominal,'actual',actual,'expressions',struct('path',{},'value',{}));updates={};
for block=find_system(root,'LookUnderMasks','all','BlockType','Fcn')'
 expression=get_param(block{1},'Expr');updated=expression;
 for k=1:3,updated=regexprep(updated,['\<' names{k} '\>'],literals{k});end
 if ~strcmp(expression,updated),backup.expressions(end+1)=struct('path',block{1},'value',expression);updates{end+1}=updated;end %#ok<AGROW>
end
assert(numel(updates)==4);constants=[getVariable(ws,'p') getVariable(ws,'phis') getVariable(ws,'J') getVariable(ws,'F')];
for sample=1:100
 u=[6*sin(sample);6*sin(sample+2*pi/3);6*sin(sample-2*pi/3);3*cos(sample*.31);5*sin(sample*.2);100*sin(sample*.1);mod(sample*.77,2*pi);.207];
 for k=1:4,assert(evaluate(backup.expressions(k).value,actual,constants,u)==evaluate(updates{k},actual,constants,u),'Literal substitution changed expression evaluation.');end
end
for k=1:4,set_param(backup.expressions(k).path,'Expr',updates{k});end
for k=1:3,assert(getVariable(ws,names{k})==nominal(k));end
backup.exact_evaluation_pairs=400;backup.literal_roundtrip_exact=true;
end
function value=evaluate(expression,values,constants,u)
Rs=values(1);Ld=values(2);Lq=values(3);p=constants(1);phis=constants(2);J=constants(3);F=constants(4); %#ok<NASGU>
value=eval(expression);
end
