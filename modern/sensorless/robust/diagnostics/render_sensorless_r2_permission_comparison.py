"""Plot archived pre/post packet quality without filtering bad samples."""
from pathlib import Path
import hashlib,json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

BASE=Path(__file__).resolve().parents[2]
OLD=BASE/'runs/N3R2_stopped_init_v3_20261017_105619_277b3c70-cdf0-4542-b35d-d320753c4b82/diagnostic_combined_3000_attempt_1/review'
NEW=BASE/'runs/N3R2_packet_phase_guard_v4_20261017_112427_9e735b46-7a5c-4647-9ded-1039e323d9ef/diagnostic_combined_3000_attempt_1/review'
DEST=BASE/'milestones/N3R2/followup_20261017'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 a=np.genfromtxt(OLD/'control.csv',delimiter=',',names=True);b=np.genfromtxt(NEW/'control.csv',delimiter=',',names=True)
 for key in ['time_s','theta_est_rad','theta_true_rad','speed_est_rpm']:assert np.array_equal(a[key],b[key])
 error=np.rad2deg(np.arctan2(np.sin(a['theta_est_rad']-a['theta_true_rad']),np.cos(a['theta_est_rad']-a['theta_true_rad'])))
 e=np.genfromtxt(OLD/'events.csv',delimiter=',',names=True);f=np.genfromtxt(NEW/'events.csv',delimiter=',',names=True)
 fig,axes=plt.subplots(2,1,figsize=(11,6),layout='constrained',sharex=True)
 axes[0].plot(a['time_s'],abs(error),label='Actual PLL angle error (same pre/post)')
 axes[0].plot(b['time_s'],abs(np.rad2deg(b['packet_phase_error_rad'])),label='PLL-to-EMF phase separation',alpha=.7)
 axes[0].axhline(8,color='red',ls='--',label='Existing 8 deg acceptance limit');axes[0].axhline(5,color='green',ls=':',label='5 deg packet phase gate')
 axes[0].set_ylabel('Electrical angle [deg]');axes[0].set_ylim(0,10);axes[0].legend(loc='lower left',fontsize=9)
 axes[1].step(e['time_s'],e['permit'],where='post',label='Prior permit');axes[1].step(f['time_s'],f['permit'],where='post',label='Guarded permit')
 axes[1].fill_between(e['time_s'],0,e['false_valid'],step='post',color='red',alpha=.2,label='Prior false-valid interval: 19.42 ms')
 axes[1].set_ylabel('Permission');axes[1].set_ylim(-.1,1.25);axes[1].legend(loc='lower right',fontsize=9);axes[1].set_xlabel('Time [s]')
 for ax in axes:ax.set_xlim(.045,.115);ax.grid(alpha=.25)
 fig.suptitle('3000 rpm startup: qualify packet availability; preserve estimator trajectories')
 DEST.mkdir(parents=True,exist_ok=True);fig.savefig(DEST/'permission_comparison.png',dpi=160);plt.close(fig)
 provenance={'renderer_sha256':sha(Path(__file__)),'original_control_csv_sha256':sha(OLD/'control.csv'),'guard_control_csv_sha256':sha(NEW/'control.csv'),
 'original_events_csv_sha256':sha(OLD/'events.csv'),'guard_events_csv_sha256':sha(NEW/'events.csv'),'no_samples_discarded':True,
 'display_window_s':[.045,.115],'full_run_evaluation_window_s':[0,.8],'figure_sha256':sha(DEST/'permission_comparison.png')}
 (DEST/'permission_comparison_provenance.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
 print('R2_PERMISSION_COMPARISON_RENDERED')
if __name__=='__main__':main()
