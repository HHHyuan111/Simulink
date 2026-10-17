"""Source-checked scientific comparison. Does not load or rerun Simulink."""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(folder):
    source = json.loads((folder / 'provenance.json').read_text('utf-8-sig'))
    for name, digest in source['files'].items():
        assert sha(folder / (name + '.csv')) == digest
    values = np.genfromtxt(folder / 'control.csv', delimiter=',', names=True)
    event = np.genfromtxt(folder / 'events.csv', delimiter=',', names=True)
    error = np.rad2deg(np.arctan2(np.sin(values['theta_est_rad'] - values['theta_true_rad']),
                                  np.cos(values['theta_est_rad'] - values['theta_true_rad'])))
    use = (values['time_s'] >= .5) & (values['time_s'] <= .8)
    assert np.count_nonzero(use) == 6000
    speed_error = values['speed_est_rpm'] - values['speed_true_rpm']
    metrics = {'angle_rms_deg': float(np.sqrt(np.mean(error[use] ** 2))),
               'angle_peak_deg': float(np.max(np.abs(error[use]))),
               'speed_rms_relative': float(np.sqrt(np.mean(speed_error[use] ** 2)) / 3000),
               'samples': 6000, 'includes_invalid_samples': True}
    original = json.loads((folder.parent / 'metrics.json').read_text('utf-8-sig'))['steady']
    assert abs(metrics['angle_rms_deg'] - original['angle_rms_deg']) < 1e-10
    assert abs(metrics['speed_rms_relative'] - original['speed_rms_error_relative']) < 1e-12
    return values, event, error, speed_error, source, metrics


def main(nominal, changed, destination):
    destination.mkdir(parents=True, exist_ok=True)
    fig, axes = plt.subplots(2, 2, figsize=(12, 7.8), layout='constrained')
    provenance = {'analysis_only': True, 'full_metrics_window_s': [.5, .8],
                  'renderer_sha256': sha(Path(__file__)), 'cases': []}
    for folder, label, color in [(nominal, 'Nominal plant', '#1f77b4'),
                                  (changed, 'Plant R x0.8, L x1.2', '#d95f02')]:
        v, e, angle, speed_error, source, metrics = load(folder)
        t = v['time_s']
        zoom = (t >= .5) & (t <= .55)
        axes[0, 0].plot(t, v['speed_true_rpm'], color=color, label=label)
        axes[0, 1].plot(t[zoom], angle[zoom], color=color, label=label)
        axes[1, 0].plot(t[zoom], speed_error[zoom], color=color, label=label)
        axes[1, 1].step(e['time_s'], e['permit'], where='post', color=color, label=label, alpha=.8)
        provenance['cases'].append({'label': label, 'csv_source': source, 'metrics': metrics})
    axes[0, 0].set(xlim=(0, .8), xlabel='Time [s]', ylabel='Plant speed [rpm]', title='Full physical acceleration')
    axes[0, 0].axvspan(.5, .8, alpha=.12, color='grey')
    axes[0, 1].set(xlim=(.5, .55), xlabel='Time [s]', ylabel='Electrical angle error [deg]', title='Steady angle: detail, no permission filter')
    axes[1, 0].set(xlim=(.5, .55), xlabel='Time [s]', ylabel='Estimated - plant speed [rpm]', title='Steady speed error: detail')
    axes[1, 1].set(xlim=(0, .12), ylim=(-.1, 1.2), xlabel='Time [s]', ylabel='Control permit', title='Native permission events: startup detail')
    for axis in axes.flat:
        axis.grid(alpha=.25)
        axis.legend(fontsize=9)
    normal, cold = [item['metrics'] for item in provenance['cases']]
    fig.suptitle('Fixed observer parameters under plant R/L mismatch\n'
                 f"Angle RMS: {normal['angle_rms_deg']:.3f} deg -> {cold['angle_rms_deg']:.3f} deg; "
                 f"speed RMS: {normal['speed_rms_relative'] * 100:.3f}% -> {cold['speed_rms_relative'] * 100:.3f}%\n"
                 'Metrics use all 6000 JEOS samples from 0.5-0.8 s; fixed engineering profile / noise seed')
    path = destination / 'cold_comparison.png'
    fig.savefig(path, dpi=160)
    plt.close(fig)
    provenance['figure_sha256'] = sha(path)
    (destination / 'cold_comparison_provenance.json').write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'figure': str(path), 'metrics': [normal, cold]}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('nominal', type=Path)
    parser.add_argument('changed', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    main(args.nominal, args.changed, args.destination)
