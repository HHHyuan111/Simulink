function [fig,view]=open_pmsm_current_frequency_time(folder,frequency)
% Verified d-axis archive, presented by the shared native time viewer.
if nargin<1,folder=[];end
if nargin<2,frequency=1250;end
pack=pmsm_current_frequency_time_data(folder);
[fig,view]=pmsm_frequency_time_view(pack,frequency,@()open_pmsm_current_frequency(pack.folder));
end
