"""Visualize control-rate core diagnostics, never whole-model acceptance."""
from pathlib import Path
import argparse
import hashlib
import json
import h5py
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main(folder):
    original = json.loads((folder / 'report.json').read_text('utf-8-sig'))
    assert original['baseline_exact'] and original['numeric_elements'] == 496000
    review = folder / 'review'
    review.mkdir(exist_ok=True)
    report = {'analysis_only': True, 'component_only': True, 'R2_case_status_changed': False,
              'whole_model_fault_acceptance': False, 'native_permission_tested': False,
              'original_report_sha256': sha(folder / 'report.json'),
              'renderer_sha256': sha(Path(__file__)), 'cases': {}}
    fig, axes = plt.subplots(4, 2, figsize=(14, 10), layout='constrained', sharex=True)
    for column, name in enumerate(('missing_five', 'reset_one')):
        archive = folder / (name + '_core.mat')
        with h5py.File(archive) as f:
            t = f['t'][()].ravel()
            result = {key: value[()].T for key, value in f['result'].items()}
            truth_theta = f['mutated/truth_theta'][()].ravel()
            truth_speed = f['mutated/truth_speed'][()].ravel()
        assert len(t) == 16000
        angle = np.degrees(np.angle(np.exp(1j * (result['theta'].ravel() - truth_theta))))
        relative = np.abs(result['speed'].ravel() - truth_speed) / np.maximum(np.abs(truth_speed), 1)
        packet = result['phase_guard'][:, 7] > .5
        good = packet & (np.abs(angle) <= 8) & (relative <= .03)
        diagnostic = original['core_faults'][name]
        healthy = diagnostic['healthy_reference_s']
        onset = diagnostic['fault_reference_s']
        run = 0
        start = None
        for k in np.flatnonzero(t >= healthy - 1e-12):
            run = run + 1 if good[k] else 0
            if run == 400:
                start = float(t[k - run + 1])
                break
        report['cases'][name] = {'source_mat_sha256': sha(archive),
            'first_packet_requalified_reference_s': diagnostic['first_requalified_reference_s'],
            'first_20ms_good_start_reference_s': start,
            'core_recovery_delay_s': None if start is None else start - healthy,
            'qualification_is_not_native_control_permission': True,
            'qualified_JEOS_error_exceeds_reference_count': int(np.count_nonzero(packet & ~good)),
            'native_20ms_hold_tested': False}
        axes[0, column].plot(t, angle, label='Raw angle error')
        axes[0, column].axhline(8, ls=':', color='grey')
        axes[0, column].axhline(-8, ls=':', color='grey')
        visible = (t >= .59) & (t <= .76)
        angle_extent = max(10, float(np.max(np.abs(angle[visible]))) * 1.1)
        axes[0, column].set(ylabel='Electrical angle error [deg]', title=name,
                            ylim=(-angle_extent, angle_extent))
        axes[1, column].plot(t, truth_speed, label='Recorded plant speed')
        axes[1, column].plot(t, result['speed'].ravel(), label='Core raw estimate', alpha=.8)
        axes[1, column].set_ylabel('Mechanical speed [rpm]')
        axes[2, column].step(t, result['valid'].ravel(), where='post', label='History quality')
        axes[2, column].step(t, packet, where='post', label='Packet qualification', alpha=.8)
        axes[2, column].set(ylabel='Core qualification', ylim=(-.1, 1.2))
        axes[3, column].plot(t, result['emf_magnitude'].ravel(), label='Extracted EMF')
        axes[3, column].axhline(2, ls=':', color='grey', label='Existing2V threshold')
        axes[3, column].set(ylabel='EMF magnitude [V]', xlabel='Physical reference time [s]')
        for axis in axes[:, column]:
            axis.axvline(onset, color='red', ls=':', label='Fault reference')
            if start is not None:
                axis.axvline(start, color='green', ls='--', label='20ms JEOS good run begins')
            axis.set_xlim(.59, .76)
            axis.grid(alpha=.25)
            axis.legend(fontsize=7, loc='best')
    fig.suptitle('Core isolation using frozen recorded current and interval voltage\n'
                 'Control-rate diagnostic only; frontend recoupling, native packet queue and PWM are excluded')
    figure = review / 'core_fault_diagnosis.png'
    fig.savefig(figure, dpi=150)
    plt.close(fig)
    report['figure_sha256'] = sha(figure)
    (review / 'core_fault_diagnosis.json').write_bytes((json.dumps(report, indent=2) + '\n').encode('utf-8'))
    print(json.dumps(report))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('folder', type=Path)
    main(parser.parse_args().folder)
