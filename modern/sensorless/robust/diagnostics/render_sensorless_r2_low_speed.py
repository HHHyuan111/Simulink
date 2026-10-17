"""Read-only low-speed permission diagnosis; no estimator tuning or resimulation."""
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


def main(folder):
    source = json.loads((folder / 'provenance.json').read_text('utf-8-sig'))
    for name, digest in source['files'].items():
        assert sha(folder / (name + '.csv')) == digest
    c = np.genfromtxt(folder / 'control.csv', delimiter=',', names=True)
    e = np.genfromtxt(folder / 'events.csv', delimiter=',', names=True)
    counters = np.loadtxt(folder / 'counters.csv', delimiter=',')
    assert abs(counters[-1, 0] - .9) < 1e-12
    low = (e['permit'] > .5) & (np.abs(e['speed_true_rpm']) <= 250)
    times = e['time_s'][low]
    report = {'analysis_only': True, 'raw_source_sha256': source['source_raw_sha256'],
              'csv_sha256': source['files'], 'renderer_sha256': sha(Path(__file__)),
              'low_speed_permit_native_points': int(counters[-1, 5]),
              'low_speed_permission_criterion_passed': bool(counters[-1, 5] == 0),
              'first_logged_low_permission_s': float(times[0]) if len(times) else None,
              'last_logged_low_permission_s': float(times[-1]) if len(times) else None,
              'logged_low_permission_rows': len(times),
              'event_scope': 'All permit/false-valid/flag transitions plus50us heartbeats; low-speed crossings alone do not trigger an event. Native counter is authoritative; plotted event endpoints are sampled.',
              'false_valid_longest_s': float(counters[-1, 1]),
              'low_speed_accuracy_claimed': False}
    fig, axes = plt.subplots(4, 1, figsize=(12, 10), layout='constrained', sharex=True)
    t = c['time_s']
    axes[0].plot(t, c['speed_true_rpm'], label='Plant speed')
    axes[0].plot(t, c['speed_est_rpm'], alpha=.75, label='Raw estimate')
    axes[0].axhspan(-250, 250, color='grey', alpha=.15, label='Required deny region')
    axes[0].set_ylabel('Mechanical speed [rpm]')
    axes[1].step(e['time_s'], e['permit'], where='post', label='Control permit')
    axes[1].step(e['time_s'], e['false_valid'], where='post', label='False valid', alpha=.7)
    if len(times):
        axes[1].scatter(times, np.ones(len(times)), s=2, color='red', label='Logged permit with |plant rpm| <=250')
    axes[1].set(ylabel='Native event state', ylim=(-.1, 1.2))
    axes[2].plot(t, c['emf_magnitude_V'], label='Extracted EMF')
    axes[2].axhline(2, color='green', ls='--', label='Existing turn-on2V')
    axes[2].axhline(1.5, color='orange', ls=':', label='Existing turn-off1.5V')
    axes[2].set_ylabel('EMF magnitude [V]')
    axes[3].step(t, c['quality_valid'], where='post', label='Historical quality')
    if 'packet_valid' in c.dtype.names:
        axes[3].step(t, c['packet_valid'], where='post', label='Packet phase-qualified', alpha=.7)
    axes[3].set(ylabel='JEOS qualification', ylim=(-.1, 1.2), xlabel='Time [s]')
    for axis in axes:
        for event, label in [(.3, 'Request200rpm'), (.6, 'Request0rpm')]:
            axis.axvline(event, color='grey', ls=':', lw=.8)
        axis.set_xlim(0, .9)
        axis.grid(alpha=.25)
        axis.legend(loc='upper right', fontsize=8)
    fig.suptitle('Low-speed boundary and stop: preserve raw estimates; evaluate actual speed\n'
                 f"Native permitted points at |plant rpm| <=250: {report['low_speed_permit_native_points']}; no low-speed accuracy claim")
    figure = folder / 'low_speed_diagnosis.png'
    fig.savefig(figure, dpi=160)
    plt.close(fig)
    report['figure_sha256'] = sha(figure)
    (folder / 'low_speed_diagnosis.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('folder', type=Path)
    main(parser.parse_args().folder)
