"""Plot verified, full-control-rate CSV exports without MATLAB graphics."""
from pathlib import Path
import hashlib
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
OUT = HERE / 'milestones' / 'N2'
GRAY, BLUE, RED = '#808080', '#0072bd', '#d62629'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def finish(fig, title, path):
    fig.suptitle(title, fontsize=14)
    for ax in fig.axes:
        ax.grid(True, alpha=.22)
        ax.set_xlabel('Time (ms)')
    fig.tight_layout(rect=(0, 0, 1, .96))
    fig.savefig(path, dpi=150, facecolor='white')
    plt.close(fig)


def main():
    provenance = json.loads((OUT / 'figure_provenance.json').read_text(encoding='utf-8-sig'))
    plt.rcParams.update({'font.size': 10, 'lines.linewidth': 1.25})
    for row in provenance['sources']:
        case = row['case_id']
        path = OUT / f'{case}_plot_data.csv'
        assert sha(path) == row['csv_sha256']
        if case == 'reference_disabled':
            continue
        d = np.genfromtxt(path, delimiter=',', names=True, encoding='utf-8-sig')
        t = d['time_s'] * 1000
        fig, ax = plt.subplots(2, 2, figsize=(12, 7.2))
        ax[0, 0].plot(t, np.rad2deg(d['truth_theta_rad']), '--', color=GRAY, label='Truth (evaluation)')
        ax[0, 0].plot(t, np.rad2deg(d['theta_rad']), color=BLUE, label='SMO + PLL')
        ax[0, 0].set_ylabel('Electrical angle (deg)'); ax[0, 0].legend()
        ax[0, 1].plot(t, d['truth_speed_rpm'], '--', color=GRAY, label='Truth (evaluation)')
        ax[0, 1].plot(t, d['speed_rpm'], color=BLUE, label='SMO + PLL')
        ax[0, 1].set_ylabel('Speed (rpm)'); ax[0, 1].legend()
        ax[1, 0].plot(t, np.rad2deg(d['angle_error_rad']), color=RED)
        ax[1, 0].set_ylabel('Wrapped angle error (deg)')
        for key, color in [('valid', BLUE), ('state', GRAY), ('saturated', RED)]:
            ax[1, 1].step(t, d[key], where='post', color=color, label=key)
        ax[1, 1].legend(); ax[1, 1].set_ylabel('Observer status')
        finish(fig, f'{case} | N2 integration, N3 accuracy pending', OUT / f'{case}_overview.png')
        fig, ax = plt.subplots(3, 2, figsize=(12, 9.2))
        for column, suffix in enumerate(('alpha', 'beta')):
            a = ax[0, column]
            a.plot(t, d[f'current_{suffix}_A'], '--', color=GRAY, label='Measured')
            a.plot(t, d[f'estimated_{suffix}_A'], color=BLUE, label='Estimated')
            a.set_ylabel(f'{suffix} current (A)'); a.legend()
        ax[1, 0].plot(t, d['emf_alpha_V'], color=BLUE, label='alpha')
        ax[1, 0].plot(t, d['emf_beta_V'], color=RED, label='beta')
        ax[1, 0].set_ylabel('EMF (V)'); ax[1, 0].legend()
        ax[1, 1].plot(t, d['pll_error'], color=RED); ax[1, 1].set_ylabel('PLL phase detector')
        ax[2, 0].plot(t, d['pll_integral_rad_s'], color=BLUE); ax[2, 0].set_ylabel('PLL integral (rad/s)')
        ax[2, 1].plot(t, np.rad2deg(d['phase_correction_rad']), color=BLUE)
        ax[2, 1].set_ylabel('Phase correction (deg)')
        finish(fig, f'{case} | archived observer internals', OUT / f'{case}_internal.png')
    provenance['renderer_sha256'] = sha(Path(__file__))
    provenance['renderer'] = f'matplotlib {matplotlib.__version__}, numpy {np.__version__}'
    (OUT / 'figure_provenance.json').write_text(json.dumps(provenance, indent=2), encoding='utf-8')
    manifest = {'schema': 1, 'node': 'N2', 'files': [
        {'path': p.name, 'sha256': sha(p)} for p in sorted(OUT.iterdir())
        if p.is_file() and p.name != 'artifact_manifest.json']}
    (OUT / 'artifact_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
