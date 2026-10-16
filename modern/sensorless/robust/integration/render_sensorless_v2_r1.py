"""Scientific review plots from R1 archived CSVs, not simulated illustrations."""
import hashlib
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np


def main(folder):
    folder = Path(folder)
    provenance = json.loads((folder / 'export_provenance.json').read_text('utf-8-sig'))
    for entry in provenance['exports']:
        assert hashlib.sha256((folder / entry['path']).read_bytes()).hexdigest() == entry['sha256']
    plt.rcParams.update({'font.size': 10, 'axes.grid': True, 'grid.alpha': .22})
    fig, ax = plt.subplots(3, 1, figsize=(11, 9), constrained_layout=True, sharex=True)
    x = np.genfromtxt(folder / 'combined_control.csv', delimiter=',', names=True)
    for phase, color in zip('ABC', ['#1463b7', '#db6b22', '#458b40']):
        ax[0].plot(x['time_s']*1000, x[f'measured_{phase}_A'], color=color, alpha=.4, ls='--', lw=1)
        ax[0].plot(x['time_s']*1000, x[f'aligned_{phase}_A'], color=color, lw=1, label=f'{phase}: calibrated + aligned')
    ax[0].set_ylabel('Current [A]'); ax[0].legend(ncol=3, fontsize=8)
    ax[0].set_title('Local model, combined nonideal startup; engineering assumptions')
    ax[1].plot(x['time_s']*1000, x['path_unc_alpha_V'], label='alpha')
    ax[1].plot(x['time_s']*1000, x['path_unc_beta_V'], label='beta')
    ax[1].set_ylabel('Conditional path\nambiguity envelope [V]'); ax[1].legend()
    for index, case in enumerate(['rail', 'window', 'deadline']):
        a = np.genfromtxt(folder / f'{case}_control.csv', delimiter=',', names=True)
        good = (a['rail'] == 0) & (a['window_good'] > .5) & (a['timing_good'] > .5)
        ax[2].step(a['time_s']*1000, index*1.4 + good.astype(float), where='post', label=case)
    ax[2].set_yticks([.5, 1.9, 3.3], ['rail case', 'window case', 'deadline case'])
    ax[2].set_ylabel('Frame input good\n0 / 1 per row'); ax[2].set_xlabel('Time [ms]')
    fig.suptitle('R1 integration checks: 20 ms is not a steady accuracy test', fontsize=13)
    fig.savefig(folder / 'integration_review.png', dpi=160); plt.close(fig)

    x = np.genfromtxt(folder / 'combined_publication_excerpt.csv', delimiter=',', names=True)
    fig, ax = plt.subplots(2, 1, figsize=(11, 6), constrained_layout=True, sharex=True)
    ax[0].step(x['time_s']*1e6, x['sequence'], where='post', label='Published sequence')
    for jeos in [28.875, 78.875]:
        ax[0].axvline(jeos, color='#777', ls=':', lw=1)
        ax[0].axvline(jeos+3, color='#197d3d', ls='--', lw=1)
    ax[0].set_ylabel('Sequence'); ax[0].legend(loc='upper left')
    ax[0].set_title('Captured at JEOS (dotted); available after 3 us (dashed)')
    ax[1].plot(x['time_s']*1e6, x['age_s']*1e6, label='Published data age')
    ax[1].set_ylabel('Age [us]'); ax[1].set_xlabel('Native clock [us]'); ax[1].legend()
    fig.suptitle('Actual local-model archive; startup control permission stays OFF', fontsize=12)
    fig.savefig(folder / 'publication_review.png', dpi=160); plt.close(fig)

    x = np.genfromtxt(folder / 'component_recovery.csv', delimiter=',', names=True)
    fig, ax = plt.subplots(2, 1, figsize=(11, 6), constrained_layout=True, sharex=True)
    ax[0].step(x['time_s']*1000, x['input_good'], where='post', label='Input good')
    ax[0].step(x['time_s']*1000, x['quality_lock']+.04, where='post', label='Quality lock (+0.04 for visibility)')
    ax[0].step(x['time_s']*1000, x['permit_after_ready']-.04, where='post', label='Permit after ready (-0.04)')
    ax[0].set_ylabel('Boolean'); ax[0].legend(fontsize=8, ncol=3)
    ax[1].plot(x['time_s']*1000, x['history_count']); ax[1].set_ylabel('History [samples]'); ax[1].set_xlabel('Fixture time [ms]')
    fig.suptitle('Component fixture: a fault clears history; earliest relock after 599 good samples\nThis is not a physical-model recovery-performance claim', fontsize=11)
    fig.savefig(folder / 'recovery_component_review.png', dpi=160); plt.close(fig)
    result = {'source': provenance, 'renderer_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'figures': {name: hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in
                          ['integration_review.png','publication_review.png','recovery_component_review.png']}}
    (folder/'figure_provenance.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main(sys.argv[1])
