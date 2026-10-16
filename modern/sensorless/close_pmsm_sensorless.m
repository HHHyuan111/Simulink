function close_pmsm_sensorless
% Remove only this observer layer; do not save or close the user's model.
mdl='PMSM_FOC_R2026a';
if pmsm_sensorless_model('installed',mdl),pmsm_sensorless_model('remove',mdl);end
end
