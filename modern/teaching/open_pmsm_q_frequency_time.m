function [fig,view]=open_pmsm_q_frequency_time(folder,frequency,kind)
if nargin<1,folder=[];end
if nargin<2,frequency=1250;end
if nargin<3,kind='current';end
assert(ismember(kind,{'current','mechanics'}));pack=pmsm_q_frequency_time_data(folder);
pack.title='q轴电流环时域响应';pack.mechanical_view=strcmp(kind,'mechanics');
if pack.mechanical_view,pack.title='q轴锁轴观测';end
[fig,view]=pmsm_frequency_time_view(pack,frequency,@()open_pmsm_q_frequency(pack.folder));
end
