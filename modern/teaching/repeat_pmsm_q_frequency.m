function fig=repeat_pmsm_q_frequency
% Argument-list process launch: no shell interpolation or live-model mutation.
here=fileparts(mfilename('fullpath'));root=fileparts(here);folder=fullfile(root,'.build');if ~isfolder(folder),mkdir(folder);end
uuid=char(java.util.UUID.randomUUID);log=fullfile(folder,['q_frequency_' uuid '.log']);
args=java.util.ArrayList;args.add(fullfile(matlabroot,'bin','matlab.exe'));args.add('-batch');
args.add(sprintf('addpath(''%s'');run_pmsm_q_frequency;',strrep(here,'''','''''')));
builder=java.lang.ProcessBuilder(args);builder.redirectErrorStream(true);builder.redirectOutput(java.io.File(log));
process=builder.start;fprintf('q轴锁轴固定参考实验：独立进程运行，当前模型不变。日志：%s\n',log);
while process.isAlive,pause(.5);drawnow;end
assert(process.exitValue==0,'频响实验失败；原始日志保留在%s',log);
fig=open_pmsm_q_frequency;
end
