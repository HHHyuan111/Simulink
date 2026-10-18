"""Plot actual missing-frame publications and permission without resimulation."""
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
    review = folder / 'fault_review'
    source = json.loads((review / 'provenance.json').read_text('utf-8-sig'))
    record = json.loads((folder / 'record.json').read_text('utf-8-sig'))
    metrics = json.loads((folder / 'metrics.json').read_text('utf-8-sig'))
    assert record['status'] == 'passed' and record['case_id'] == 'missing_five' and metrics['all_passed']
    assert source['source_raw_sha256'] == record['raw_sha256'] == sha(folder / 'signals.mat')
    for name, digest in source['files'].items():
        assert sha(review / (name + '.csv')) == digest
    c = np.genfromtxt(review / 'control.csv', delimiter=',', names=True)
    p = np.genfromtxt(review / 'publications.csv', delimiter=',', names=True)
    e = np.genfromtxt(review / 'events.csv', delimiter=',', names=True)
    count = np.loadtxt(review / 'counters.csv', delimiter=',')
    assert len(c) == 16000 and len(p) == 15995 and np.count_nonzero(c['missing']) == 5
    assert count[-1, 11] == 12800001 and count[-1, 1] == 0 and count[-1, 4] == 0
    onset = metrics['fault_onset_s']
    recovery = metrics['recovery_completion_s']
    angle = np.degrees(np.angle(np.exp(1j * (c['theta_est_rad'] - c['theta_true_rad']))))
    fig, axes = plt.subplots(4, 1, figsize=(12, 10), layout='constrained')
    axes[0].plot(c['time_s'], angle, label='Raw electrical angle error')
    axes[0].set_ylabel('Angle error [deg]')
    axes[1].plot(c['time_s'], c['speed_true_rpm'], label='Plant speed')
    axes[1].plot(c['time_s'], c['speed_est_rpm'], label='Raw estimated speed', alpha=.8)
    axes[1].set_ylabel('Mechanical speed [rpm]')
    axes[2].step(c['time_s'], c['history_valid'], where='post', label='JEOS history quality')
    axes[2].step(c['time_s'], c['packet_valid'], where='post', label='JEOS packet qualification', alpha=.7)
    axes[2].step(e['time_s'], e['permit'], where='post', label='Native control permit', lw=1.3)
    axes[2].set(ylabel='Qualification / permit', ylim=(-.1, 1.2), xlabel='Physical time [s]')
    visible = (c['time_s'] >= .59) & (c['time_s'] <= .66)
    for axis, values in zip(axes[:2], (angle, np.r_[c['speed_est_rpm'][visible], c['speed_true_rpm'][visible]])):
        values = values[visible] if len(values) == len(c) else values
        lo, hi = float(np.min(values)), float(np.max(values))
        margin = max(.1 * (hi - lo), .02 if axis == axes[0] else .1)
        axis.set_ylim(lo - margin, hi + margin)
    for axis in axes[:3]:
        axis.axvline(onset, color='red', ls=':', label='First missing reference')
        axis.axvspan(recovery, recovery + .02, color='green', alpha=.12, label='Verified20ms native good hold')
        axis.set_xlim(.59, .66)
    axes[3].scatter((p['time_s'] - onset) * 1e6, np.ones(len(p)), s=18, label='Actual publication completion')
    dropped = c['time_s'][c['missing'] > .5]
    axes[3].scatter((dropped - onset) * 1e6, np.zeros(5), marker='x', s=45, color='red', label='Missing JEOS reference; no completion')
    axes[3].step((e['time_s'] - onset) * 1e6, e['permit'], where='post', label='Native permit', alpha=.6)
    axes[3].set(xlim=(-100, 400), ylim=(-.15, 1.3), xlabel='Time from first missing reference [us]', ylabel='Publication / permit')
    for axis in axes:
        axis.grid(alpha=.25)
        axis.legend(loc='upper right', fontsize=7)
    fig.suptitle('Full nonideal model: exactly five unavailable ADC frames\n'
                 f"15995 actual publications; recovery {1000 * metrics['recovery_delay_s']:.1f}ms; native false-valid duration0")
    figure = review / 'missing_diagnosis.png'
    fig.savefig(figure, dpi=150)
    plt.close(fig)
    result = {'analysis_only': True, 'simulation_reexecuted': False, 'source_raw_sha256': record['raw_sha256'],
              'renderer_sha256': sha(Path(__file__)), 'metrics_sha256': sha(folder / 'metrics.json'),
              'figure_sha256': sha(figure), 'csv_sha256': source['files'], 'actual_publications': len(p),
              'missing_reference_count': len(dropped), 'recovery_delay_s': metrics['recovery_delay_s'],
              'plot_scope': 'Raw JEOS points and recorded native transitions; display lines only, no data resampling/smoothing or numerical alteration.'}
    (review / 'missing_diagnosis.json').write_bytes((json.dumps(result, indent=2) + '\n').encode('utf-8'))
    print(json.dumps(result))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('folder', type=Path)
    main(parser.parse_args().folder)
