function fig=repeat_pmsm_speed_step
here=fileparts(mfilename('fullpath'));root=fileparts(here);folder=fullfile(root,'.build');if ~isfolder(folder),mkdir(folder);end
uuid=char(java.util.UUID.randomUUID);log=fullfile(folder,['speed_step_' uuid '.log']);
args=java.util.ArrayList;args.add(fullfile(matlabroot,'bin','matlab.exe'));args.add('-batch');
args.add(sprintf('addpath(''%s'');run_pmsm_speed_step;',strrep(here,'''','''''')));
builder=java.lang.ProcessBuilder(args);builder.redirectErrorStream(true);builder.redirectOutput(java.io.File(log));
process=builder.start;fprintf('速度阶跃：独立固定参考实验，当前模型不变。日志：%s\n',log);
while process.isAlive,pause(.5);drawnow;end
assert(process.exitValue==0,'实验失败，日志：%s',log);fig=open_pmsm_speed_step;
end
