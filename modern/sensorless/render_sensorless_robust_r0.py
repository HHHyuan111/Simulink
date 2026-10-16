"""Scientific R0 component figures from full archived CSVs; no model access."""
from pathlib import Path
import hashlib
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
OUT = HERE/'milestones/N3R0'
BLUE, GRAY, RED = '#0072bd', '#808080', '#d62629'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    provenance = json.loads((OUT/'figure_provenance.json').read_text(encoding='utf-8-sig'))
    for source in provenance['csv_sources']:
        assert sha(OUT/source['path']) == source['sha256']
    d = np.genfromtxt(OUT/'deadtime_edges.csv', delimiter=',', names=True, encoding='utf-8-sig')
    plt.rcParams.update({'font.size': 10, 'lines.linewidth': 1.2})
    fig, axes = plt.subplots(3, 1, figsize=(11, 7), sharex=True)
    for ax, requested in zip(axes, (.4375, .5, .51)):
        x = d[np.isclose(d['requested_deadtime_us'], requested, atol=1e-12)]
        ax.step(x['time_us'], x['request_AH'], where='post', color=GRAY, linestyle='--', label='Requested upper gate')
        ax.step(x['time_us'], x['gate_AH'], where='post', color=BLUE, label='Estimated gate')
        ax.step(x['time_us'], x['oracle_AH'], where='post', color=RED, linestyle=':', label='Independent edge oracle')
        ax.set_ylabel('Gate 0/1'); ax.set_ylim(-.1, 1.3)
        ax.set_title(f'Requested deadtime {requested:g} us; effective {x["effective_deadtime_us"][0]:g} us')
        ax.grid(True, alpha=.2); ax.legend(loc='upper right', ncol=3, fontsize=8)
    axes[-1].set_xlabel('Time (us)'); axes[-1].set_xlim(0, 8)
    fig.suptitle('R0 component: short pulses suppressed; rising edges rounded up to 62.5 ns grid')
    fig.tight_layout(rect=(0, 0, 1, .95)); fig.savefig(OUT/'deadtime_edges.png', dpi=150); plt.close(fig)

    d = np.genfromtxt(OUT/'event_schedule.csv', delimiter=',', names=True, encoding='utf-8-sig')
    fig, axes = plt.subplots(2, 1, figsize=(12, 8), gridspec_kw={'height_ratios': [1, 2.3]})
    ax = axes[0]
    labels = ['C aperture end', 'B aperture end', 'A aperture end', 'JEOS / reference', 'Observer available', 'CCR write', 'PWM applies']
    nominal = d[(d['cycle'] == 0) & (d['update_mode'] == 0) & (d['release_jitter_us'] == 0) & (d['interference_us'] == 0) & (d['guard_us'] == 2)]
    assert len(nominal) == 1
    times = [float(nominal[0][key])*1e6 for key in ('adc_C_s', 'adc_B_s', 'adc_A_s', 'reference_s', 'observer_available_s', 'ccr_write_s', 'actual_pwm_apply_s')]
    colors = [GRAY, GRAY, GRAY, GRAY, BLUE, BLUE, RED]
    for row, (label, t, color) in enumerate(zip(labels, times, colors)):
        ax.scatter(t, row, color=color, s=25); ax.annotate(f'{t:g} us', (t, row), xytext=(5, 0), textcoords='offset points', va='center', fontsize=8)
    ax.set_yticks(range(len(labels)), labels); ax.invert_yaxis(); ax.set_xlim(23, 56)
    ax.set_title('Nominal engineering allocation: observer 3 us + FOC 5 us; not measured WCET')
    ax.grid(True, axis='x', alpha=.2); ax.set_xlabel('Time in PWM cycle (us)')
    ax = axes[1]
    extras = [0, 10, 11.125, 13.125, 50]
    for row, extra in enumerate(extras):
        keep = (d['cycle'] == 0) & (d['update_mode'] == 0) & (d['release_jitter_us'] == 0) & np.isclose(d['guard_us'], 2) & np.isclose(d['interference_us'], extra)
        x = d[keep]; assert len(x) == 1
        x = x[0]; begin, ready, write, apply = [float(x[k])*1e6 for k in ('task_release_s', 'observer_available_s', 'ccr_write_s', 'actual_pwm_apply_s')]
        ax.broken_barh([(begin, ready-begin)], (row-.25, .5), facecolors=BLUE)
        ax.broken_barh([(ready, write-ready)], (row-.25, .5), facecolors=GRAY)
        good = bool(x['timing_valid']); color = BLUE if good else RED
        ax.scatter(write, row, marker='|', color=color, s=180)
        ax.scatter(apply, row, marker='D', color=color, s=35)
        ax.annotate(f'write={write:g}, apply={apply:g}, admit={good}', (max(write, apply)+1, row), va='center', fontsize=8, color=color)
    for t in (25, 50, 75, 100):
        ax.axvline(t, color=GRAY, linewidth=.8, linestyle=':')
    ax.axvline(48, color=RED, linewidth=.9, linestyle='--', label='Admission deadline: 50 - 2 us guard')
    ax.set_yticks(range(len(extras)), [f'Extra interference {t:g} us' for t in extras]); ax.invert_yaxis()
    ax.set_xlim(24, 158); ax.set_xlabel('Time in initial PWM cycle (us)')
    ax.set_title('Equal-time UEV wins; missed deadline revokes permission even when next UEV is available')
    ax.grid(True, axis='y', alpha=.15); ax.legend(loc='lower right', fontsize=8)
    fig.suptitle('R0 timing core: separate sample, publication and actuation times; no PMSM simulation')
    fig.tight_layout(rect=(0, 0, 1, .95)); fig.savefig(OUT/'event_schedule.png', dpi=150); plt.close(fig)

    provenance['renderer_sha256'] = sha(Path(__file__))
    provenance['renderer'] = f'matplotlib {matplotlib.__version__}, numpy {np.__version__}'
    (OUT/'figure_provenance.json').write_text(json.dumps(provenance, indent=2), encoding='utf-8')
    manifest = {'schema': 1, 'node': 'N3R0', 'files': [
        {'path': p.name, 'sha256': sha(p)} for p in sorted(OUT.iterdir()) if p.is_file() and p.name != 'artifact_manifest.json']}
    (OUT/'artifact_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
