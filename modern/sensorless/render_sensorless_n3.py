"""Plot full-rate N3 CSV exports; acceptance uses the archived MAT/JSON data."""
from pathlib import Path
import hashlib
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
OUT = HERE / 'milestones' / 'N3'
GRAY, BLUE, RED = '#808080', '#0072bd', '#d62629'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    provenance = json.loads((OUT / 'figure_provenance.json').read_text(encoding='utf-8-sig'))
    replay_path = OUT/'replay_validation.json'
    replay = json.loads(replay_path.read_text(encoding='utf-8-sig')) if replay_path.exists() else None
    replay_cases = {r['case_id']: r for r in replay['cases']} if replay else {}
    plt.rcParams.update({'font.size': 10, 'lines.linewidth': 1.15})
    clocks = []
    for source in provenance['sources']:
        case = source['case_id']
        path = OUT / f'{case}_plot_data.csv'
        assert sha(path) == source['csv_sha256']
        d = np.genfromtxt(path, delimiter=',', names=True, encoding='utf-8-sig')
        metrics = json.loads((OUT / f'{case}_metrics.json').read_text(encoding='utf-8-sig'))
        t = d['time_s']
        record = json.loads((OUT/f'{case}_record.json').read_text(encoding='utf-8-sig'))
        rate = record['control_sample']; period, offset = (rate[0], rate[1]) if isinstance(rate, list) else (rate, 0)
        h = record['timing_h']; tick = np.rint((t-offset)/h).astype(np.int64)
        expected_count = int(np.floor((record['effective_case']['duration_s']-offset)/period+1e-9))+1
        spacing_error = float(np.max(np.abs(np.diff(t)-period)))
        passed = spacing_error <= 1e-12 and abs(t[0]-offset) <= 1e-12 and np.all(tick % round(period/h) == 0) and len(t) == expected_count
        clocks.append({'case_id': case, 'samples': len(t), 'period_s': period, 'offset_s': offset,
                       'native_grid_s': h, 'maximum_spacing_error_s': spacing_error, 'passed': bool(passed)})
        assert passed, f'Control clock audit failed: {case}'
        fig, axes = plt.subplots(2, 2, figsize=(12, 7.2))
        a = axes[0, 0]
        a.plot(t, d['truth_speed_rpm'], '--', color=GRAY, label='Truth (evaluation)')
        a.plot(t, d['speed_rpm'], color=BLUE, label='SMO + PLL')
        a.set_ylabel('Speed (rpm)'); a.legend()
        a = axes[0, 1]
        a.plot(t, np.rad2deg(d['angle_error_rad']), color=RED)
        a.axhline(8, color=GRAY, linestyle=':', linewidth=.7)
        a.axhline(-8, color=GRAY, linestyle=':', linewidth=.7)
        a.set_ylabel('Wrapped angle error (deg)')
        a = axes[1, 0]
        for field, color in [('valid', BLUE), ('state', GRAY), ('saturated', RED)]:
            a.step(t, d[field], where='post', color=color, label=field)
        a.set_ylabel('Observer status'); a.legend()
        a = axes[1, 1]
        if case in ('missing_5_samples', 'observer_reset'):
            for field, color in [('sample_valid', BLUE), ('reset', RED)]:
                a.step(t, d[field], where='post', color=color, label=field)
            a.set_xlim(.5998, .6005); a.set_ylabel('Injected flags'); a.legend()
        else:
            mag = np.hypot(d['emf_alpha_V'], d['emf_beta_V'])
            a.plot(t, mag, color=BLUE, label='Estimated EMF magnitude')
            a.axhline(2, color=GRAY, linestyle='--', label='EMF on: 2 V')
            a.axhline(1.5, color=RED, linestyle=':', label='EMF off: 1.5 V')
            a.set_ylabel('EMF magnitude (V)'); a.legend()
        for a in axes.ravel():
            a.grid(True, alpha=.22); a.set_xlabel('Time (s)')
        kind = 'base acceptance' if metrics['precision_required'] or metrics['dynamic_required'] else 'boundary: precision diagnostic'
        state = replay_cases.get(case)
        replay_label = ('identical' if state['passed'] else 'INCOMPLETE / failed') if state else 'pending audit'
        fig.suptitle(f'{case} | {kind}\nformal checks={metrics["passed"]} | replay={replay_label}', fontsize=12)
        fig.tight_layout(rect=(0, 0, 1, .95))
        fig.savefig(OUT / f'{case}.png', dpi=150, facecolor='white'); plt.close(fig)
    base = []
    for case in ('steady_1000', 'steady_2000', 'steady_3000'):
        m = json.loads((OUT / f'{case}_metrics.json').read_text(encoding='utf-8-sig'))
        w = m['windows']; w = w[0] if isinstance(w, list) else w
        base.append(w)
    fig, ax = plt.subplots(1, 3, figsize=(12, 3.8))
    labels = ['1000', '2000', '3000']
    values = [[w['angle_rms_deg'] for w in base], [100*w['speed_error_rms_relative'] for w in base], [100*w['valid_fraction'] for w in base]]
    for a, data, limit, title in zip(ax, values, (3, 2, 99), ('Angle RMS (deg)', 'Speed error RMS (%)', 'Valid fraction (%)')):
        a.bar(labels, data, color=BLUE); a.axhline(limit, color=RED, linestyle='--', label=f'v1 limit: {limit}')
        a.set_title(title); a.set_xlabel('Target speed (rpm)'); a.grid(True, axis='y', alpha=.22); a.legend()
        for j, v in enumerate(data):
            a.annotate(f'{v:.4g}', (j, v), xytext=(0, 3), textcoords='offset points', ha='center')
    ax[2].set_ylim(0, 110)
    node_state = f' | full replay {replay["completed_replay_cases"]}/16: incomplete' if replay and not replay['all_passed'] else ''
    fig.suptitle('N3 steady windows: 0.5-0.8 s, all samples including invalid'+node_state, fontsize=11)
    fig.tight_layout(rect=(0, 0, 1, .92)); fig.savefig(OUT/'steady_summary.png', dpi=150); plt.close(fig)
    fig, ax = plt.subplots(2, 3, figsize=(12, 6), sharex=True)
    for column, case in enumerate(('steady_1000', 'steady_2000', 'steady_3000')):
        d = np.genfromtxt(OUT/f'{case}_plot_data.csv', delimiter=',', names=True, encoding='utf-8-sig')
        keep = (d['time_s'] >= .5) & (d['time_s'] <= .8)
        ax[0, column].plot(d['time_s'][keep], np.rad2deg(d['angle_error_rad'][keep]), color=RED)
        ax[1, column].plot(d['time_s'][keep], (d['speed_rpm']-d['truth_speed_rpm'])[keep], color=BLUE)
        ax[0, column].set_title(f'{labels[column]} rpm')
        ax[0, column].set_ylabel('Angle error (deg)'); ax[1, column].set_ylabel('Speed error (rpm)')
        ax[1, column].set_xlabel('Time (s)')
    for a in ax.ravel():
        a.grid(True, alpha=.22)
    fig.suptitle('Full declared steady windows; matched ideal model, not hardware accuracy')
    fig.tight_layout(rect=(0, 0, 1, .94)); fig.savefig(OUT/'steady_error_detail.png', dpi=150); plt.close(fig)
    provenance['renderer_sha256'] = sha(Path(__file__))
    provenance['renderer'] = f'matplotlib {matplotlib.__version__}, numpy {np.__version__}'
    (OUT/'figure_provenance.json').write_text(json.dumps(provenance, indent=2), encoding='utf-8')
    (OUT/'control_clock_audit.json').write_text(json.dumps({'schema': 1, 'cases': clocks, 'all_passed': len(clocks) == 16 and all(c['passed'] for c in clocks)}, indent=2), encoding='utf-8')
    manifest = {'schema': 1, 'node': 'N3', 'files': [
        {'path': p.name, 'sha256': sha(p), 'committed': not p.name.endswith('_plot_data.csv')} for p in sorted(OUT.iterdir())
        if p.is_file() and p.name != 'artifact_manifest.json']}
    (OUT/'artifact_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
