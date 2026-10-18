"""Show the complete archived reset transient; never rerun or tune the model."""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main(folder):
    record = json.loads((folder / 'record.json').read_text('utf-8-sig'))
    metrics = json.loads((folder / 'metrics.json').read_text('utf-8-sig'))
    review = folder / 'review'
    source = json.loads((review / 'provenance.json').read_text('utf-8-sig'))
    assert record['case_id'] == 'reset_one' and record['status'] == 'passed'
    assert metrics['all_passed'] and record['reference_restored']
    assert source['source_raw_sha256'] == record['raw_sha256'] == sha(folder / 'signals.mat')
    for name, digest in source['files'].items():
        assert sha(review / (name + '.csv')) == digest
    control = np.genfromtxt(review / 'control.csv', delimiter=',', names=True)
    events = np.genfromtxt(review / 'events.csv', delimiter=',', names=True)
    counters = np.loadtxt(review / 'counters.csv', delimiter=',')
    t = control['time_s']
    angle = np.degrees(np.angle(np.exp(1j * (control['theta_est_rad'] - control['theta_true_rad']))))
    assert len(t) == 16000 and counters[-1, 11] == 12800001
    assert counters[-1, 1] == 0 and counters[-1, 4] == 0 and counters[-1, 6] == 0
    onset = metrics['fault_onset_s']
    recovery = metrics['recovery_completion_s']
    transient = (t >= onset) & (t <= recovery)
    report = {'analysis_only': True, 'simulation_reexecuted': False,
              'raw_source_sha256': record['raw_sha256'], 'metrics_sha256': sha(folder / 'metrics.json'),
              'renderer_sha256': sha(Path(__file__)), 'csv_sha256': source['files'],
              'native_false_valid_longest_s': float(counters[-1, 1]),
              'recovery_delay_s': metrics['recovery_delay_s'],
              'raw_transient_angle_peak_deg': float(np.max(np.abs(angle[transient]))),
              'raw_transient_speed_min_rpm': float(np.min(control['speed_est_rpm'][transient])),
              'raw_transient_speed_max_rpm': float(np.max(control['speed_est_rpm'][transient])),
              'plot_scope': 'All JEOS points in the displayed transient; native permit step uses every recorded transition. No smoothing, interpolation, clipping or data deletion.'}
    fig, axes = plt.subplots(4, 1, figsize=(12, 10), layout='constrained', sharex=True)
    axes[0].plot(t, angle, label='Raw electrical angle error')
    axes[0].axhline(8, color='grey', ls=':')
    axes[0].axhline(-8, color='grey', ls=':', label='Existing +/-8deg reference')
    axes[0].set_ylabel('Angle error [deg]')
    axes[1].plot(t, control['speed_true_rpm'], label='Plant speed')
    axes[1].plot(t, control['speed_est_rpm'], label='Raw estimated speed', alpha=.8)
    axes[1].set_ylabel('Mechanical speed [rpm]')
    axes[2].plot(t, control['emf_magnitude_V'], label='Estimated EMF')
    axes[2].axhline(2, color='grey', ls=':', label='Existing2V turn-on threshold')
    axes[2].set_ylabel('EMF magnitude [V]')
    axes[3].step(t, control['quality_valid'], where='post', label='JEOS history quality')
    axes[3].step(t, control['packet_valid'], where='post', label='JEOS packet qualification', alpha=.7)
    axes[3].step(events['time_s'], events['permit'], where='post', label='Native control permit', lw=1.3)
    axes[3].set(ylabel='Qualification / permit', xlabel='Physical time [s]', ylim=(-.1, 1.2))
    visible = (t >= .59) & (t <= .72)
    for axis, values in zip(axes[:3], (angle, control['speed_est_rpm'], control['emf_magnitude_V'])):
        lo, hi = float(np.min(values[visible])), float(np.max(values[visible]))
        margin = max((hi - lo) * .1, 1)
        axis.set_ylim(lo - margin, hi + margin)
    for axis in axes:
        axis.axvline(onset, color='red', ls=':', label='Reset reference')
        axis.axvspan(recovery, recovery + .02, color='green', alpha=.12, label='Verified20ms native good hold')
        axis.set_xlim(.59, .72)
        axis.grid(alpha=.25)
        axis.legend(loc='upper right', fontsize=7)
    fig.suptitle('Full nonideal model: single software reset at0.600028875s\n'
                 f"Recovery {1000 * metrics['recovery_delay_s']:.1f}ms; native false-valid duration0; raw transient retained")
    figure = review / 'reset_diagnosis.png'
    fig.savefig(figure, dpi=150)
    plt.close(fig)
    report['figure_sha256'] = sha(figure)
    (review / 'reset_diagnosis.json').write_bytes((json.dumps(report, indent=2) + '\n').encode('utf-8'))
    print(json.dumps(report))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('folder', type=Path)
    main(parser.parse_args().folder)
