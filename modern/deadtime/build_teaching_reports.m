function build_teaching_reports
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';load_system(fullfile(root,'.build','deadtime_stage',[mdl '.slx']));g=onCleanup(@()close_system(mdl,0));
before=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');code=mw.MATLABCode;
for row={600,.207,.08,'report_teaching';300,.08,.14,'report_low_speed'}'
 r=run_deadtime_demo(2,row{1},row{2},row{3});
 r.compensation_improved_THD=r.cases.comp.low_order_THD_percent<r.cases.dead.low_order_THD_percent;
 assert(isequaln(before,teach_snapshot(mdl))&&strcmp(code,mw.MATLABCode),'Demo altered model configuration.');
 copyfile(fullfile(folder,'report_demo'),fullfile(folder,row{4}));
 teach_writejson(fullfile(folder,row{4},'record.json'),r);
 fprintf('TEACHING_REPORT_PASS %s THD %.6f %.6f %.6f\n',row{4},r.cases.ideal.low_order_THD_percent,r.cases.dead.low_order_THD_percent,r.cases.comp.low_order_THD_percent);
end
fprintf('TEACHING_REPORTS_ALL_PASS\n');
end
