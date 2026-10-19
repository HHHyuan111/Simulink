function report=assess_sensorless_r2_short_windows(folder)
% Read existing completed traces only. No model load, compile or simulation.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(base,fullfile(modern,'teaching'));assert(~isfolder(folder));mkdir(folder);
plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));criteria=plan.precision;
ids={'diagnostic_combined_3000','combined_2000','combined_1000'};
report=struct('analysis_only',true,'simulation_started',false,'not_new_acceptance',true,...
 'source_sha256',teach_hash([mfilename('fullpath') '.m']),'pole_pairs',5,'cases',struct([]));caseResults=cell(1,numel(ids));
for n=1:numel(ids)
 p=fullfile(base,'milestones/N3R2/followup_20261017',['v4_' ids{n} '_record.json']);
 r=jsondecode(fileread(p));raw=fullfile(r.folder,'signals.mat');assert(strcmp(teach_hash(raw),r.raw_sha256));
 s=load(raw,'obs_sless_v2_theta','obs_sless_v2_truth_theta','obs_sless_v2_speed',...
  'obs_sless_v2_truth_speed','obs_sless_v2_publication','obs_sless_r2_native_events');
 t=s.obs_sless_v2_theta.Time;theta=teach_values(s.obs_sless_v2_theta);truth=teach_values(s.obs_sless_v2_truth_theta);
 speed=teach_values(s.obs_sless_v2_speed);actual=teach_values(s.obs_sless_v2_truth_speed);
 angle=atan2(sin(theta-truth),cos(theta-truth))*180/pi;error=speed-actual;
 events=teach_values(s.obs_sless_r2_native_events);pt=s.obs_sless_v2_publication.Time;
 [found,index]=ismember(round(pt/62.5e-9),round(events(:,1)/62.5e-9));assert(all(found));permit=events(index,3)>.5;
 target=abs(r.effective_case.speed_rpm);windowLength=22/(target*5/60);windowResults={};
 for finish=[.15 .2 .25 .3 .35 .4 .45]
  begin=finish-windowLength;if begin<0,continue;end
  use=t>=begin-1e-12&t<=finish+1e-12;x=t(use);y=actual(use);a=angle(use);e=error(use);
  slope=sum((x-mean(x)).*(y-mean(y)))/sum((x-mean(x)).^2);unwrapped=unwrap(truth(use));cycles=abs(unwrapped(end)-unwrapped(1))/(2*pi);
  w=struct('window_s',[begin finish],'electrical_cycles',cycles,'angle_rms_deg',sqrt(mean(a.^2)),...
   'angle_peak_deg',max(abs(a)),'speed_mean_relative',abs(mean(e))/target,...
   'speed_rms_relative',sqrt(mean(e.^2))/target,'plant_mean_relative',abs(mean(y)-r.effective_case.speed_rpm)/target,...
   'plant_slope_rpm_s',slope,'permit_fraction',mean(permit(use)));
  w.all_passed=cycles>=criteria.minimum_electrical_cycles&&w.angle_rms_deg<=criteria.angle_rms_deg_max&&...
   w.angle_peak_deg<=criteria.angle_peak_deg_max&&w.speed_mean_relative<=criteria.speed_mean_relative_max&&...
   w.speed_rms_relative<=criteria.speed_rms_relative_max&&w.plant_mean_relative<=criteria.plant_mean_target_relative_max&&...
   abs(slope)<=criteria.plant_speed_slope_rpm_s_max&&w.permit_fraction>=criteria.permit_fraction_min;
  windowResults{end+1}=w; %#ok<AGROW>
 end
 windows=[windowResults{:}];
 first=find([windows.all_passed],1);earliest=NaN;if ~isempty(first),earliest=windows(first).window_s(2);end
 caseResults{n}=struct('id',ids{n},'target_rpm',r.effective_case.speed_rpm,...
  'raw_sha256',r.raw_sha256,'record_sha256',teach_hash(p),'earliest_assessed_passing_end_s',earliest,'windows',windows);
end
report.cases=[caseResults{:}];
teach_writejson(fullfile(folder,'report.json'),report);fprintf('READ_ONLY_SHORT_WINDOW_ANALYSIS_COMPLETE\n');
end
