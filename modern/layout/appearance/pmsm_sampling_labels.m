function config=pmsm_sampling_labels(config)
% Correct UI wording without changing the sealed numerical configuration API.
ix=find(strcmp({config.rows.section},'采样设置')&strcmp({config.rows.key},'adc_span'));
assert(isscalar(ix));config.rows(ix).label='ADC双极量程 ± [A]';config.rows(ix).unit='A，单侧幅值';
config.rows(ix).measurement='当前模型范围[-adc_span, adc_span-ΔI]，ΔI=2*adc_span/2^adc_bits；82.5表示±82.5A，全跨度165A。当前数值未作实板校准。';
if strcmp(config.rows(ix).status,'未实测'),config.rows(ix).source='当前模型等效量程；实板量程待标定';end
end
