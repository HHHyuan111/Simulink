function report=probe_sensorless_r2_runtime_oracle(folder)
% Exact integer/byte checks without model loading or Simulink API calls.
assert(~isfile(fullfile(folder,'matlab_result.json')));
oracle=jsondecode(fileread(fullfile(folder,'oracle.json')));[~,~,endian]=computer;assert(endian=='L');
report=struct('kind','model_independent_matlab_control','phase','start','all_passed',false,...
 'process_id',matlabProcessID,'matlab_version',version,'simulation_starts',0,'cycles',0,...
 'native_retries',0,'private_preferences',prefdir,'oracle_sha256',oracle.sha256);
source=[mfilename('fullpath') '.m'];copyfile(source,fullfile(folder,'matlab_probe_source.m.txt'));
fid=fopen(source,'rb');assert(fid>=0);data=fread(fid,Inf,'*uint8');fclose(fid);report.source_sha256=digest(data);
teachless_write(fullfile(folder,'matlab_result.json'),report);
seed=(0:oracle.count-1)';timer=tic;lastProgress=0;bytes=uint8([]);
try
 while (toc(timer)<60||report.cycles<4)&&report.cycles<100000
  x=seed;
  for k=1:oracle.steps,x=mod(1664525*x+1013904223,4294967296);end
  bytes=typecast(uint32(x),'uint8');actual=digest(bytes);report.cycles=report.cycles+1;
  assert(strcmp(actual,oracle.sha256),'R2:RuntimeByteMismatch','Exact byte digest differs at cycle%d.',report.cycles);
  report.last_good_cycle=report.cycles;
  if toc(timer)-lastProgress>=5
   report.elapsed_s=toc(timer);report.phase='running';teachless_write(fullfile(folder,'matlab_progress.json'),report);lastProgress=report.elapsed_s;
  end
 end
 report.elapsed_s=toc(timer);report.actual_sha256=digest(bytes);report.all_passed=report.elapsed_s>=60&&report.cycles>=4&&strcmp(report.actual_sha256,oracle.sha256);
 report.phase='completed';write_vector(folder,bytes);teachless_write(fullfile(folder,'matlab_result.json'),report);
catch err
 report.elapsed_s=toc(timer);report.phase='failed';report.error_identifier=err.identifier;report.failed_cycle=report.cycles;
 write_vector(folder,bytes);teachless_write(fullfile(folder,'matlab_result.json'),report);rethrow(err);
end
end
function value=digest(data)
md=java.security.MessageDigest.getInstance('SHA-256');md.update(data);value=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
function write_vector(folder,bytes)
fid=fopen(fullfile(folder,'matlab_vector.bin'),'wb');assert(fid>=0);guard=onCleanup(@()fclose(fid));assert(fwrite(fid,bytes,'uint8')==numel(bytes));
end
function teachless_write(path,value)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);guard=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
