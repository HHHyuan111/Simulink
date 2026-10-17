"""Independent CSV metrics and scientific plots; never runs/changes the model."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(folder):
    source = json.loads((folder/'provenance.json').read_text(encoding='utf-8-sig'))
    for name, value in source['files'].items():
        assert digest(folder/(name+'.csv')) == value
    c = np.genfromtxt(folder/'control.csv', delimiter=',', names=True)
    e = np.genfromtxt(folder/'events.csv', delimiter=',', names=True)
    counters = np.loadtxt(folder/'counters.csv', delimiter=',')
    t = c['time_s']
    angle = np.rad2deg(np.arctan2(np.sin(c['theta_est_rad']-c['theta_true_rad']), np.cos(c['theta_est_rad']-c['theta_true_rad'])))
    emf_angle = np.rad2deg(np.arctan2(np.sin(c['theta_emf_corrected_rad']-c['theta_true_rad']), np.cos(c['theta_emf_corrected_rad']-c['theta_true_rad'])))
    speed_error = c['speed_est_rpm']-c['speed_true_rpm']
    use = (t >= .5) & (t <= .8)
    assert np.count_nonzero(use) == 6000
    native_angle = np.rad2deg(np.arctan2(np.sin(e['theta_now_rad']-e['theta_true_rad']), np.cos(e['theta_now_rad']-e['theta_true_rad'])))
    native_speed = np.abs(e['speed_raw_rpm']-e['speed_true_rpm'])/np.maximum(np.abs(e['speed_true_rpm']), 1)
    bad = (e['permit'] > .5) & ((np.abs(native_angle) > 8) | (native_speed > .03))
    assert np.array_equal(bad, e['false_valid'] > .5)
    ticks = np.rint(e['time_s']/62.5e-9).astype(np.int64)
    lengths = np.diff(ticks)
    boundaries = np.diff(np.pad(bad[:-1].astype(int), (1, 1)))
    starts = np.flatnonzero(boundaries == 1);stops = np.flatnonzero(boundaries == -1)
    prefix = np.concatenate(([0], np.cumsum(lengths)))
    runs = prefix[stops]-prefix[starts]
    longest = int(np.max(runs)) if len(runs) else 0
    assert longest == round(counters[-1, 1]/62.5e-9)
    result = {'scope': 'independent fixed-window CSV diagnosis, not full R2 acceptance',
              'all_invalid_samples_included': True, 'steady_samples': int(use.sum()),
              'angle_rms_deg': float(np.sqrt(np.mean(angle[use]**2))),
              'angle_peak_deg': float(np.max(np.abs(angle[use]))),
              'emf_angle_rms_deg': float(np.sqrt(np.mean(emf_angle[use]**2))),
              'speed_mean_error_relative': float(abs(np.mean(speed_error[use]))/3000),
              'speed_rms_error_relative': float(np.sqrt(np.mean(speed_error[use]**2))/3000),
              'true_speed_mean_rpm': float(np.mean(c['speed_true_rpm'][use])),
              'permit_fraction': float(np.mean(c['permit_at_available'][use])),
              'false_valid_longest_s': longest*62.5e-9,
              'false_valid_total_s': int(np.sum(lengths[bad[:-1]]))*62.5e-9,
              'first_permit_s': float(e['time_s'][np.flatnonzero(e['permit']>.5)[0]]) if np.any(e['permit']>.5) else None,
              'false_valid_runs': [{'start_s': float(e['time_s'][i]), 'end_s': float(e['time_s'][j]), 'duration_s': int(n)*62.5e-9}
                                   for i,j,n in zip(starts,stops,runs)],
              'raw_source_sha256': source['source_raw_sha256'], 'export_csv_sha256': source['files'],
              'renderer_sha256': digest(Path(__file__))}
    result['packet_phase_guard_used'] = 'packet_valid' in c.dtype.names
    if result['packet_phase_guard_used']:
        permitted = c['permit_at_available'] > .5
        result['emf_angle_peak_during_permission_deg'] = float(np.max(np.abs(emf_angle[permitted]))) if np.any(permitted) else None
        result['packet_phase_peak_during_permission_deg'] = float(np.max(np.abs(np.rad2deg(c['packet_phase_error_rad'][permitted])))) if np.any(permitted) else None
        assert not np.any(permitted & (np.abs(c['packet_phase_error_rad']) > np.deg2rad(5)+1e-12))
    (folder/'independent_metrics.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    fig,axes=plt.subplots(3,2,figsize=(13,9),layout='constrained')
    ax=axes.flat[0];ax.plot(t,c['speed_true_rpm'],label='Plant');ax.plot(t,c['speed_est_rpm'],label='Estimate',alpha=.75);ax.set_ylabel('Mechanical speed [rpm]');ax.legend()
    ax=axes.flat[1];ax.plot(t,angle,label='PLL');ax.plot(t,emf_angle,label='Corrected EMF',alpha=.7);ax.axhline(8,color='k',ls='--',lw=.7);ax.axhline(-8,color='k',ls='--',lw=.7);ax.set_ylabel('Wrapped electrical angle error [deg]');ax.legend()
    ax=axes.flat[2];ax.step(e['time_s'],e['permit'],where='post',label='Permit');ax.step(e['time_s'],bad.astype(int),where='post',label='False valid');ax.set_ylim(-.1,1.2);ax.set_ylabel('Native state');ax.legend()
    ax=axes.flat[3];ax.plot(t,speed_error/3000*100);ax.axhline(2,color='k',ls='--',lw=.7);ax.axhline(-2,color='k',ls='--',lw=.7);ax.set_ylabel('Speed error / 3000 rpm [%]')
    ax=axes.flat[4];ax.plot(t,c['emf_magnitude_V']);ax.set_ylabel('Extracted EMF magnitude [V]')
    ax=axes.flat[5];ax.plot(t,c['pll_error']);ax.set_ylabel('Normalized PLL innovation')
    for ax in axes.flat:
        ax.axvspan(.5,.8,color='grey',alpha=.12);ax.set_xlim(0,.8);ax.set_xlabel('Time [s]');ax.grid(alpha=.25)
    title = 'R1 estimates + instantaneous packet phase guard' if result['packet_phase_guard_used'] else 'Accepted R1 estimates and packet quality'
    fig.suptitle(title+' — combined engineering nonidealities\nAll JEOS samples and native state events retained; grey: fixed evaluation window')
    fig.savefig(folder/'diagnosis.png',dpi=160);plt.close(fig)
    print(json.dumps({k:v for k,v in result.items() if k not in ('false_valid_runs','export_csv_sha256')},indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('folder',type=Path);main(parser.parse_args().folder)
