function v=sensorless_r2_fault_program(testcase)
v=zeros(1,22);
if strcmp(testcase.id,'missing_five'),v(1)=1;v(2:3)=testcase.missing_reference_interval_s;
elseif strcmp(testcase.id,'reset_one'),v(1)=2;v(4)=testcase.reset_reference_s;v(5)=v(4)+50e-6;
elseif strcmp(testcase.id,'deadline_jitter')
 v(1)=3;items=testcase.schedule;if ~iscell(items),items=num2cell(items);end
 assert(numel(items)<=5);v(6)=numel(items);
 for k=1:numel(items),e=items{k};v(8+3*(k-1):10+3*(k-1))=[e.time_s e.release_jitter_s e.interference_s];end
end
assert(all(isfinite(v))&&all(v>=0));h=62.5e-9;
assert(all(abs(v(2:end)/h-round(v(2:end)/h))<1e-7));
if v(1)==1,assert(abs(v(3)-v(2)-5*50e-6)<1e-12);end
if v(1)==3
 table=reshape(v(8:22),3,5)';assert(all(diff(table(1:v(6),1))>0));assert(all(table(1:v(6),2)+table(1:v(6),3)+8e-6<50e-6));
end
end
