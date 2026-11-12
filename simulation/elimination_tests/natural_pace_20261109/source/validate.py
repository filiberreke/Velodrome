"""Regression, held-out races, external-frame invariance and per-lap speeds."""
import csv,json,statistics,copy,hashlib,struct,math
from collections import defaultdict
from experiments import ROOT,load
import baseline_logged
from elimination_v2 import simulate,feasible_power,power_to_speed,swept_laterally_clear,lane_metric,cycle_urgency,can_leave_corridor
from lane_sim import phys,road
from metrics import Recorder

def csvwrite(name,rows):
    with (ROOT/'results'/name).open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

def digest_callback():
    digest=hashlib.sha256()
    def observe(seed,t,h,rs,active,*args):
        digest.update(struct.pack('<I',len(active)))
        for i in active:
            r=rs[i];digest.update(struct.pack('<idddi',i,r['d'],r['v'],r['w'],r['lane']))
    return observe,digest

def tests():
    checks=[]
    r=dict(cp=265.,pmax=1000.,w=20000.,wmax=24000.,fatigue=0.)
    old=copy.deepcopy(r);new=copy.deepcopy(r)
    old_p=phys(old,400.,.2)
    p=feasible_power(400.,10.,.31,10.,.2);new_p=phys(new,p,.2)
    assert abs(p-road(10.,.31)/.975)<1e-9
    assert old['w']<r['w'] and new['w']>=r['w']
    v=10+(new_p*.975/10-.5*1.2*.334*100*.31-.004*80*9.81)/80*.2
    assert abs(v-10)<1e-9
    checks.append(dict(test='traffic_power_does_not_burn_reserve_against_equal_speed_leader',passed=True,old_power=old_p,new_power=new_p,old_wprime=old['w'],new_wprime=new['w']))
    assert swept_laterally_clear(0,1,1,2)
    assert swept_laterally_clear(1,0,2,2)
    assert not swept_laterally_clear(0,1,1,0)
    assert not swept_laterally_clear(0,1,1,1)
    checks.append(dict(test='parallel_away_merge_and_swap_trajectories',passed=True))
    assert can_leave_corridor(3.2,0.)
    assert can_leave_corridor(2.,0.)
    assert can_leave_corridor(-3.2,0.)
    assert not can_leave_corridor(3.2,-8.)
    assert not can_leave_corridor(1.9,0.)
    checks.append(dict(test='safe_existing_3_2m_wheel_can_be_left_new_merge_still_guarded',passed=True))
    for lead_lane in (0,5,11):
        for follow_lane in (0,5,11):
            reference_v=11.
            leader_v=reference_v*lane_metric(lead_lane)
            desired=leader_v*lane_metric(follow_lane)/lane_metric(lead_lane)
            assert abs(desired/lane_metric(follow_lane)-reference_v)<1e-12
    checks.append(dict(test='wheel_velocity_uses_common_reference_metric_9_cases',passed=True))
    assert cycle_urgency(499.)>.99 and cycle_urgency(500.)==0.
    assert cycle_urgency(199.)==0. and cycle_urgency(249.)>0. and cycle_urgency(300.)==1.
    assert cycle_urgency(999.)>.99 and cycle_urgency(1000.)==0.
    checks.append(dict(test='urgency_resets_at_leader_elimination_boundary',passed=True))
    for v in (5.,10.,14.):
        desired=v+.5;aero=.6;h=.05
        p=power_to_speed(v,desired,aero)
        actual=v+(p*.975/max(v,2.5)-.5*1.2*.334*v*v*aero-.004*80*9.81)/80*h
        assert abs(actual-(v+.5/1.25*h))<1e-12
    checks.append(dict(test='velocity_feedback_matches_physics_3_cases',passed=True))
    observations=[]
    def natural_head(seed,t,h,rs,active,before,info,drafts,powers,final,line):
        i=active[0];x=info[i]
        if 14<t<35 and x['urgency']==0. and x['wheel']<0:
            assert abs(x['raw_request']-rs[i]['cp']*.92)<1e-7
            if before[i]['v']<11.:
                observations.append(dict(time=t,speed=before[i]['v'],power=x['raw_request'],cp=rs[i]['cp']))
    simulate(17,observe=natural_head)
    assert observations
    checks.append(dict(test='uncontested_head_uses_cruise_power_below_legacy_minimum_speed',passed=True,example=observations[0]))
    return checks

def main():
    checks=tests();rows=[];lap_rows=[];rider_rows=[];diag={};matrix=[]
    baseline=baseline_logged.load();bare=load('v1')
    seeds=list(range(17,77))
    for seed in seeds:
        for label,fn in (('baseline',baseline),('v2',simulate)):
            trace=ROOT/f'results/trace_{label}_seed{seed}.csv.gz' if seed in (17,24) else None
            rec=Recorder(trace_path=trace)
            result=fn(seed,observe=rec)
            if label=='baseline':assert result==bare(seed)
            assert result['finished'] and result['blocked']==0,(seed,label,result)
            summary=rec.finish();diag[f'{label}_{seed}']=summary
            r=dict(result,variant=label,frame_dt=.2,mean_ai_span_m=summary['mean_ai_span_m'],max_span_m=summary['max_span_m'],max_ai_span_m=summary['max_ai_span_m'])
            rows.append(r);matrix.append(r.copy())
            lap_rows.extend(dict(r,variant=label) for r in rec.laps)
            rider_rows.extend(dict(r,variant=label) for r in rec.rider_laps)
            print(seed,label,result['span_m'],round(summary['max_span_m'],2),flush=True)
        # The outer frame can be larger or smaller without changing any state.
        # These are independently scheduled runs, not reused rows.
        hashes=[];reference=None
        for frame in ((.1,.2,.4,.13) if seed in (17,23,24,31,41,42,52,53,64,65,76) else ()):
            observe,digest=digest_callback()
            r=simulate(seed,dt=frame,observe=observe)
            if reference is None:reference=r
            assert r==reference,(seed,frame,r,reference)
            hashes.append(digest.hexdigest())
            if frame!=.2:
                matrix.append(dict(r,variant='v2',frame_dt=frame,mean_ai_span_m='',max_span_m='',max_ai_span_m=''))
        if hashes:assert len(set(hashes))==1,(seed,hashes)
        for frame in (.1,.4):
            r=bare(seed,dt=frame)
            assert r['finished'] and r['blocked']==0
            matrix.append(dict(r,variant='baseline',frame_dt=frame,mean_ai_span_m='',max_span_m='',max_ai_span_m=''))
    checks.append(dict(test='11_seeds_full_state_equal_across_4_frame_intervals',passed=True,frames=[.1,.2,.4,.13],seeds=[17,23,24,31,41,42,52,53,64,65,76]))
    checks.append(dict(test='120_detailed_races_completed_zero_corrections_legal_following_distance',passed=True,source_sha256=hashlib.sha256((ROOT/'source/elimination_v2.py').read_bytes()).hexdigest()))
    csvwrite('before_after.csv',rows);csvwrite('frame_sensitivity.csv',matrix)
    csvwrite('lap_speeds.csv',lap_rows);csvwrite('rider_lap_speeds.csv',rider_rows)
    # Compare matched odd/even cycles after the standing start and the injected
    # attack (laps 1-4), and exclude the final two laps. Keep ALL laps in CSV.
    lookup={(r['variant'],r['seed'],r['lap']):r for r in lap_rows}
    pairs=[]
    for label in ('baseline','v2'):
        for seed in seeds:
            for odd in range(1,29,2):
                a=lookup[label,seed,odd];b=lookup[label,seed,odd+1]
                pairs.append(dict(variant=label,seed=seed,cycle=(odd+1)//2,recovery_lap=odd,elimination_lap=odd+1,
                    recovery_kmh=a['field_mean_kmh'],elimination_kmh=b['field_mean_kmh'],difference_kmh=b['field_mean_kmh']-a['field_mean_kmh'],
                    ordinary_cycle=odd>=5))
    csvwrite('lap_pairs.csv',pairs)
    ordinary=[r['difference_kmh'] for r in pairs if r['variant']=='v2' and r['ordinary_cycle']]
    checks.append(dict(test='natural_pace_elimination_laps_faster_on_average',passed=statistics.mean(ordinary)>0,mean_difference_kmh=statistics.mean(ordinary)))
    aggregates=[]
    for label in ('baseline','v2'):
        for lap in range(1,31):
            rr=[r for r in lap_rows if r['variant']==label and r['lap']==lap]
            aggregates.append(dict(variant=label,lap=lap,type=rr[0]['type'],races=len(rr),field_mean_kmh=statistics.mean(r['field_mean_kmh'] for r in rr),
                ai_mean_kmh=statistics.mean(r['ai_mean_kmh'] for r in rr),leader_reference_kmh=statistics.mean(r['leader_reference_kmh'] for r in rr)))
    csvwrite('lap_speed_summary.csv',aggregates)
    (ROOT/'results/diagnostics.json').write_text(json.dumps(diag,indent=2),encoding='utf-8')
    (ROOT/'results/tests.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
    print('ALL CHECKS PASSED',flush=True)

if __name__=='__main__':main()
