#!/usr/bin/env python3
"""Experimental peloton AI testbed, separate from Godot; seeded, reproducible.
Power and speed are stylized; results diagnose model behavior, not real race outcomes.
"""
import argparse, csv, json, math, random, statistics
from collections import Counter
from energy_core import Phys, PARS, pcurve

DT = 2.0
AXLE_HALF = 0.55  # meters from rider reference center to each wheel axle
MIN_WHEEL_CLEARANCE = 0.30
WHEEL_OFFSET = 2 * AXLE_HALF
LAP = 250.0
# Physics, indoor still air. Effective rider+bicycle mass, rolling resistance,
# drivetrain efficiency; 267 W at 11 m/s corresponds to CdA 0.3343 m2 at rho 1.2.
MASS_KG = 80.0
GRAVITY = 9.81
CRR = 0.004
DRIVETRAIN_EFF = 0.975
RHO = 1.20
CDA = 2*267/(RHO*11**3)
AERO_COEFF = 0.5*RHO*CDA

def road_power(speed, aero_factor):
    return AERO_COEFF*aero_factor*speed**3 + CRR*MASS_KG*GRAVITY*speed

def integrate_speed(v, crank_power, aero_factor, dt):
    # Integrate m*v*dv/dt = P_wheel - P_drag - P_rolling
    # in 0.25 s steps for stable kinetic energy updates at high speed.
    drive=max(0., crank_power)*DRIVETRAIN_EFF
    for _ in range(int(round(dt/0.25))):
        drag=AERO_COEFF*aero_factor*v**3
        rolling=CRR*MASS_KG*GRAVITY*v
        v=math.sqrt(max(0., v*v + (2*0.25/MASS_KG)*(drive-drag-rolling)))
    return v

LANES = (1.18, 2.38, 3.58, 4.78, 5.98, 7.18)

def draft_speed_factor(v):
    return .65 + .35*clamp((v*3.6-20.)/30.,0.,1.)

PROFILES = {'tt': (310.,800.), 'sprinter': (245.,1350.), 'attacker': (275.,1050.)}

def clamp(v, a, b): return max(a, min(b, v))

# Simplified 250 m velodrome. These illustrative geometries are NOT measured
# from the actual Godot track: 2 straights, 2 bends, 0.5 m rise/m in bends.
def bank_height(reference_distance, lane):
    phase=reference_distance % LAP
    in_bend=(phase < 62.5 or 125.0 <= phase < 187.5)
    return max(0., lane) * (.50 if in_bend else .07)

def lane_distance_multiplier(reference_distance, lane):
    phase=reference_distance % LAP
    in_bend=(phase < 62.5 or 125.0 <= phase < 187.5)
    return 1.+max(0., lane)*.012 if in_bend else 1.


class Rider:
    def __init__(self, ident, role, rng):
        self.id=ident; self.role=role; self.break_start=-1.; self.break_seconds=0.; self.break_pull_seconds=0.; self.chase_seconds=0.; self.solo_seconds=0.; self.counterattack_count=0; self.group_join_count=0; self.break_group_id=-1; self.break_group_size=0; self.break_gap=0.; self.break_partners=set(); self.break_turns=0; self.break_refusals=0; self.break_draft_seconds=0.; self.break_target_lead=False
        self.phys=Phys(role, form=rng.uniform(.95,1.05), fatigue_coeff=.10)
        self.aero=self.phys.cp
        self.peak=self.phys.pmax
        self.store_max=self.phys.wmax
        self.store=self.phys.w
        self.recovery=rng.uniform(.92,1.08)
        self.aggression=rng.betavariate(2,4) + (0.22 if role=='attacker' else 0)
        self.patience=rng.uniform(.7,1.4)
        self.cooperation=rng.uniform(.35,.95) if role!='sprinter' else rng.uniform(.2,.7)
        self.d=rng.uniform(-9.,0.); self.v=0.;self.mode='draft';self.until=0.;self.cooldown=rng.uniform(50,120)
        self.lane_target=self.lane if hasattr(self,"lane") else 0.;self.lane_lock_until=0.;self.lane_switches=0;self.lane_rejects=0;self.last_lane_choice=None;self.pull_exit_until=0.;self.lane_change_s=0.;self.bank_up_j=0.;self.bank_down_j=0.;self.pull_exit_count=0;self.lane_occupation=[0.]*6;self.overlap_time_s=0.;self.no_draft_overlap_s=0.;self.wheel_clearance_bins=[0.]*6;self.gap_bins=[0.]*6;self.close_draft_s=0.;self.draft_elapsed_s=0.;self.aero_saved_integral=0.;self.aero_baseline_integral=0.;self.aero_savings_power_integral=0.;self.draft_deep_s=0.;self.lane=rng.choice(LANES);self.lane_target=self.lane;self.wheel_follow_s=0.;self.wheel_gap_loss_s=0.;self.wheel_accel_j=0.;self.wheel_targets=0;self.wheel_good_s=0.;self.final_position_seconds=0.;self.final_pos_kj=0.;self.final_mode_seconds=0.;self.sprint_started=False;self.sprint_start_m=None;self.wheel_wait=0.;self.wheel_requests=0;self.wheel_refusals=0;self.wheel_handoffs=0;self.last_attack=-9999.;self.attack_start=None;self.attack_max_gap=0.;self.attack_energy_start=0.;self.attack_checks=0;self.attacks=0;self.lead_s=0.;self.draft_s=0.;self.power_sum=0.;self.peak_drain=0.;self.dropped_s=0.;self.dropped_events=0;self.max_deficit=0.;self.drop_streak=0.;self.dropped_now=False;self.finished_at=None;self.last_d=self.d;self.lap_credits=0;self.lap_draft_s=0.;self.lap_join_time=None;self.shelter_wheel_id=None;self.shelter_wheel_changes=0

    def step_power(self, want, dt):
        # Fresh power-duration cap is used when initiating a tactical effort.
        # Thereafter W' in joules and slow fatigue constrain actual power.
        if self.mode=='attack':
            want=min(want, pcurve(18.,self.phys.cp,self.phys.wmax,self.phys.pmax))
        elif self.mode in ('pull','break_pull','chase'):
            want=min(want, pcurve(25.,self.phys.cp,self.phys.wmax,self.phys.pmax))
        elif self.mode in ('draft','solo_tt','break_draft'):
            want=min(want, pcurve(12.,self.phys.cp,self.phys.wmax,self.phys.pmax))
        actual=self.phys.step(want,dt)
        self.store=self.phys.w
        self.peak_drain=self.phys.work_above
        if self.finished_at is None:
            self.power_sum+=actual*dt
            self.above_cp_s=getattr(self,'above_cp_s',0.)+(dt if actual>self.phys.cp else 0.)
        return actual

def run(seed=1, count=12, laps=25, player_w=305, race_mode="scratch", variant="A", sprint_switch=False, final750=False, no_speed_cap=False, breakaway_v=False, chase_scale=1.0, break_follow=True, lap_probe=None, real_laps=False, sprinter_wheel_economy=True, points_experiment=None):
    rng=random.Random(seed)
    lap_events=[]
    assert race_mode in ("scratch","points")
    assert variant in ("A","B","C","D","E","F","G","H","I","J","K","L")
    riders=[Rider(i,('tt','sprinter','attacker')[(i-1)%3],rng) for i in range(1,count+1 if points_experiment is not None else count)]
    player_d=-2.; player_v=0.; player_finished_at=None; t=0.; n_steps=0
    attack_events=[]; overlap_attacks=0; no_attack_sprints=0;attack_ends=[]
    break_events=[]; counter_events=[]; break_age_samples=[]; break_group_sums=[]; solo_leads=0; group_leads=0; turn_states={}; rotations=0; refusals=0; completed_pulls=[]; next_group_id=0; break_history=[]; break_snapshots=[]
    spread_samples=[]; pack_spread_samples=[]; tight_samples=[]; draft_samples=[];gap_samples=[]; player_ahead_s=0.;caught=0; had_ahead=False
    leaders=[]; recent_attacks=[]; laps_checked=set(); attack_per_window=Counter(); prev_player_ahead=False
    last_sprint_index=-1; sprint_events=[]
    dropout_events=[]; sample_count=0; dropped_samples=0; any_dropped_ids=set(); rider_positions=[]; finish_line=laps*LAP
    experiment = None
    if points_experiment is not None:
        from intermediate_sprint import Experiment
        assert race_mode == 'points'
        experiment = Experiment(riders, laps, points_experiment)
        player_d=-1e12; player_w=0.
    points_score=experiment.points if experiment else {r.id:0 for r in riders}
    sprint_awards=[]
    next_sprint_lap=5
    last_points_leader=0
    max_time=laps*LAP/7.0+300
    checkpoints={}
    finish_groups=[]
    aerodynamic_samples=[]; wheel_target_events=0; wheel_follow_samples=0
    detail_trace=[]
    pace_trace=[]
    soft_pace_until=0.; soft_pace_cooldown=0.; soft_pace_events=0
    soft_pace_seconds=0.; soft_pace_start_lap=[]
    slow_leader_id=None
    idle_front_since={}; idle_pull_offs=0; idle_seconds=0.; idle_front_power_samples=[]
    pace_power_sums={r.id:0. for r in riders}
    pace_power_counts={r.id:0 for r in riders}

    while t < max_time and any(r.finished_at is None for r in riders):
        if experiment:
            before={r.id:(r.d,r.store,r.phys.fatigue) for r in riders}
            experiment.begin_step(riders)
        n_steps+=1
        if n_steps%5==0:
            active=[r for r in riders if r.finished_at is None]
            if active:
                mid_pos=statistics.median(r.d for r in active)
                group=[r for r in active if abs(r.d-mid_pos)<15]
                if len(group)<2:group=active
                pace_trace.append((statistics.median(r.v for r in group)*3.6, max(r.d for r in active)/LAP, statistics.mean(x.v for x in group)*3.6))
        sample_count+=1
        pel_dist=[r.d for r in riders]
        mid=statistics.median(pel_dist)
        lead=max(pel_dist)
        spread=max(pel_dist)-min(pel_dist)
        spread_samples.append(spread)
        pack=[r for r in riders if abs(r.d-mid)<=12]
        pack_spread_samples.append(max((r.d for r in pack),default=mid)-min((r.d for r in pack),default=mid))
        tight_samples.append(sum(any(r is not s and abs(r.d-s.d)<6 for s in riders) for r in riders)/len(riders))
        current_leader=max(riders,key=lambda r:r.d)
        leaders.append(current_leader.id)
        final_stage=final750 and race_mode=="scratch" and 0 < finish_line-mid <=750
        # Determine when a compact bunch has no urgent incentive to pull.
        # This is not a global speed cap: a reluctant front rider lowers their OWN power.
        main_cluster=[r for r in riders if r.finished_at is None and abs(r.d-mid)<12]
        front_pack=max(main_cluster,key=lambda x:x.d) if main_cluster else current_leader
        threatening_break=any(r.d>mid+16 and r.mode in ('attack','solo_tt','break_pull','break_draft') for r in riders)
        late_race=clamp(mid/finish_line,0.,1.)
        tiredness=statistics.mean(1.-r.store/max(r.store_max,1.) for r in main_cluster) if main_cluster else .5
        if t>=soft_pace_until and t>soft_pace_cooldown and not threatening_break and len(main_cluster)>=3 and (finish_line-mid)>650:
            # Willingness to ride declines with race age and depletion.
            probability=DT*(.0025+.007*late_race+.006*tiredness)
            if rng.random()<probability:
                slow_leader_id=front_pack.id
                soft_pace_until=t+rng.uniform(24.,58.)
                soft_pace_cooldown=soft_pace_until+rng.uniform(35.,90.)
                soft_pace_events+=1
                soft_pace_start_lap.append(int(mid/LAP)+1)
        if threatening_break:
            soft_pace_until=t
        soft_pace_active=t<soft_pace_until
        if soft_pace_active:soft_pace_seconds+=DT
        # P: sustained low incentive when there is no escape and no sprint positioning.
        # Riders are individually reluctant, without imposing a global speed cap.
        no_attack=not any(r.mode in ('attack','solo_tt','chase','break_pull','break_draft') for r in riders if r.finished_at is None)
        idle_peloton=(race_mode=='scratch' and finish_line-mid>2*LAP and no_attack
                       and player_d-mid<14 and len(main_cluster)>=3)
        if idle_peloton: idle_seconds+=DT
        # Track front riders individually, pull off after about ten seconds.
        front_ids={r.id for r in main_cluster if r.d >= front_pack.d-1.5} if idle_peloton else set()
        for _r in riders:
            if _r.id not in front_ids: idle_front_since.pop(_r.id,None)
            elif _r.id not in idle_front_since: idle_front_since[_r.id]=t
        gap=player_d-mid
        gap_samples.append(gap)
        is_ahead=gap>12
        if is_ahead: player_ahead_s+=DT
        if had_ahead and gap<=5: caught+=1;had_ahead=False
        if is_ahead: had_ahead=True
        race_lap=int(max(0,mid)//LAP)
        post_sprint=(race_mode=="points" and race_lap in (5,10,15,20,30,35,40,45)) and 0<(mid%LAP)<170
        pre_sprint=(race_mode=="points" and ((race_lap+1)%5)==0) and (mid%LAP)>135
        if experiment:
            pre_sprint=bool(experiment.next_lap and 0<experiment.next_lap*LAP-experiment.head<LAP)
            post_sprint=bool(experiment.sprints and 0<t-experiment.sprints[-1]['time_s']<16)
        if post_sprint and last_sprint_index!=race_lap:
            sprint_events.append(race_lap);last_sprint_index=race_lap
        # Detect small breakaway groups by spatial proximity to the leading
        # bunch. Breakaway status is persistent and not tied to the initial sprint timer.
        ordered=sorted((x for x in riders if x.finished_at is None),key=lambda x:x.d,reverse=True)
        clusters=[]
        for x in ordered:
            if not clusters or clusters[-1][-1].d-x.d>(13.0 if breakaway_v else 9.0):clusters.append([x])
            else:clusters[-1].append(x)
        main_cluster=max(clusters,key=lambda c:(len(c),-abs(statistics.mean(x.d for x in c)-mid))) if clusters else []
        main_front=max((x.d for x in main_cluster),default=mid)
        breaks=[c for c in clusters if c is not main_cluster and min(x.d for x in c)>main_front+(10 if breakaway_v else 8) and len(c)<=4 and not (real_laps and all(z.lap_credits>0 for z in c))]
        break_members={x.id:(i,c) for i,c in enumerate(breaks) for x in c}
        # Resolve breakaway groups, including riders who catch the original attacker.
        for i,c in enumerate(breaks):
            if len(c)>=2: group_leads+=1
            else:solo_leads+=1
            if len(c)>=2:break_group_sums.append(len(c))
            for x in c:
                if x.break_start<0:x.break_start=t;break_events.append({'seed':seed,'riders':count,'time_s':t,'type':'break_join','id':x.id,'group_size':len(c)})
                x.break_seconds+=DT
                x.break_group_id=i;x.break_group_size=len(c)
                if len(c)>=2:
                    for teammate in c:
                        if teammate is not x and teammate.id not in x.break_partners:
                            x.break_partners.add(teammate.id);x.group_join_count+=1
        # Stable escape-group identity and role-dependent pull rotations.
        # The selected puller does NOT have to already be physically in front:
        # his higher target power helps him pass the previous leader.
        group_leaders={}
        for c in breaks:
            if len(c)<2: continue
            key=tuple(sorted(x.id for x in c))
            state=turn_states.get(key)
            if breakaway_v and state is None:
                # Keep group identity while one rider briefly falls back or a chaser joins.
                eligible_history=[(k,v) for k,v in turn_states.items() if t-v['last_seen']<=12
                                  and len(set(k)&set(key))>=max(1,min(len(k),len(key))-1)]
                if eligible_history:
                    old_key,state=max(eligible_history,key=lambda kv:(len(set(kv[0])&set(key)),kv[1]['last_seen']))
                    turn_states.pop(old_key,None)
                    turn_states[key]=state
            eligible=[x for x in c if x.store/x.store_max>.25 and x.cooperation>.30]
            if not state:
                state={'leader':None,'until':t,'started':t,'last_seen':t,'turns':0,'uid':next_group_id,'born':t,'max_gap':0.,'members':set(),'rotations':0};next_group_id+=1
                turn_states[key]=state
            state['last_seen']=t
            state['members'].update(key)
            state['max_gap']=max(state['max_gap'],max(x.d for x in c)-main_front)
            if state['leader'] not in [x.id for x in eligible] or t>=state['until']:
                if state['leader'] is not None:
                    completed_pulls.append(t-state['started'])
                    rotations+=1;state['rotations']+=1
                previous=state['leader']
                # Prefer a different rider; reluctant sprinters can decline.
                candidates=sorted(eligible,key=lambda x:(x.id==previous, x.break_turns, -x.cooperation))
                chosen=None
                for x in candidates:
                    willingness=x.cooperation * (.60 if x.role=='sprinter' else 1.)
                    if rng.random()<willingness:
                        chosen=x;break
                    x.break_refusals+=1;refusals+=1
                if chosen is None and eligible:
                    chosen=max(eligible,key=lambda x:x.cooperation)
                state['leader']=chosen.id if chosen else None
                state['started']=t
                if chosen:
                    chosen.break_turns+=1
                    duration=rng.uniform(10,20) * (.60 if chosen.role=='sprinter' else 1.)
                    state['until']=t+duration
                else:state['until']=t+6
                state['turns']+=1
            group_leaders.update({x.id:state['leader'] for x in c})
        # Retire historical groups after a prolonged separation.
        if breakaway_v:
            for k,st in list(turn_states.items()):
                if t-st['last_seen']>14:
                    break_history.append({'group_id':st['uid'],'start_s':st['born'],'end_s':st['last_seen'],
                        'duration_s':st['last_seen']-st['born']+DT,'members':','.join(map(str,sorted(st['members']))),
                        'max_gap_m':round(st['max_gap'],1),'rotations':st['rotations'],'outcome':'dissolved_or_caught'})
                    del turn_states[k]
            if n_steps%3==0:
                for c in breaks:
                    break_snapshots.append({'time_s':t,'remaining_m':finish_line-max(x.d for x in riders),
                        'members':','.join(str(x.id) for x in c),'size':len(c),
                        'gap_m':round(min(x.d for x in c)-main_front,1)})
        else:
            turn_states={k:v for k,v in turn_states.items() if t-v['last_seen']<45}
        # After a demarrage: establish a durable solo or joint escape,
        # rather than falling immediately back into passive drafting.
        for r in riders:
            if r.finished_at is not None:continue
            detected=r.id in break_members
            if r.mode=='attack':
                since=t-r.attack_start
                r.attack_max_gap=max(r.attack_max_gap,r.d-mid)
                exhausted=r.store/r.store_max<.19
                capped=t>=r.until or since>18
                if since>=10 and (r.d-mid>10 or detected):
                    r.mode='solo_tt';r.break_start=t if r.break_start<0 else r.break_start
                    attack_ends.append({'seed':seed,'riders':count,'id':r.id,'role':r.role,'lap':int(max(0,r.d)//LAP)+1,'start_s':round(r.attack_start,1),'duration_s':round(since,1),'max_solo_gap_m':round(r.attack_max_gap,2),'energy_cost_pct':round(100*(r.attack_energy_start-r.store)/r.store_max,2),'reason':'established_escape'})
                elif exhausted or capped:
                    reason='reserve' if exhausted else 'countered'
                    attack_ends.append({'seed':seed,'riders':count,'id':r.id,'role':r.role,'lap':int(max(0,r.d)//LAP)+1,'start_s':round(r.attack_start,1),'duration_s':round(since,1),'max_solo_gap_m':round(r.attack_max_gap,2),'energy_cost_pct':round(100*(r.attack_energy_start-r.store)/r.store_max,2),'reason':reason})
                    r.mode='draft';r.cooldown=t+rng.uniform(25,65)
            if real_laps and r.lap_credits>0 and r.mode in ('solo_tt','break_pull','break_draft','chase'):
                r.mode='draft';r.cooldown=t+80
            if r.mode in ('solo_tt','break_pull','break_draft'):
                if not detected:
                    r.mode='draft';r.break_start=-1.;r.cooldown=t+rng.uniform(20,48)
                elif len(break_members[r.id][1])>=2:
                    c=break_members[r.id][1]
                    if group_leaders.get(r.id)==r.id:
                        r.mode='break_pull';r.break_pull_seconds+=DT
                    else:
                        r.mode='break_draft';r.break_draft_seconds+=DT
                else:r.mode='solo_tt';r.solo_seconds+=DT
            elif detected and r.mode=='draft' and (r.d-mid)>10:
                r.mode='break_draft' if len(break_members[r.id][1])>=2 else 'solo_tt'
                r.break_start=t if r.break_start<0 else r.break_start
        active_attackers=[r for r in riders if r.mode=='attack']
        # Chasers with enough reserve accelerate towards an identified break.
        break_front=max((c[0].d for c in breaks),default=-1e9)
        if break_front>main_front+12:
            candidates=[x for x in main_cluster if x.store/x.store_max>.38 and x.cooperation>.38 and x.mode=='draft']
            if candidates and rng.random()<.065*DT*chase_scale:
                ch=rng.choice(candidates)
                ch.mode='chase';ch.until=t+rng.uniform(10,26);ch.counterattack_count+=1
                counter_events.append({'seed':seed,'riders':count,'time_s':t,'chaser_id':ch.id,'gap_m':round(break_front-ch.d,1),'break_size':len(breaks[0])})
        for r in riders:
            if r.mode=='chase':
                r.chase_seconds+=DT
                if t>=r.until or r.store/r.store_max<.22 or r.id in break_members:
                    r.mode='draft';r.cooldown=t+rng.uniform(15,42)
        # Map each rider's nearest wheel; meaningful drafting only <7m.
        desired=[]
        for r in riders:
            # Circular track: a rider almost one lap in front may be physically
            # behind the bunch, even though unwrapped progress is greater.
            def physical_ahead_gap(s):
                g=s.d-r.d
                if real_laps and abs(g)>=LAP-32:
                    g=g-round(g/LAP)*LAP
                return g
            front_gap=min((physical_ahead_gap(s) for s in riders if s is not r and physical_ahead_gap(s)>0),default=1000.)
            draft=.25<front_gap<9.
            # Drag multiplier acts on aerodynamic power only, not rolling resistance.
            # For B/C lateral offset and overlapping wheels matter; compact multi-rider
            # groups provide an additional bounded shelter effect.
            if variant=='A':
                aero_factor=.82 if draft else 1.
            else:
                front=[x for x in riders if x is not r and (WHEEL_OFFSET if variant in ('H','I','J') else .15)<physical_ahead_gap(x)<9 and abs(x.lane-r.lane)<1.15]
                aero_factor=1.
                if front:
                    nearest=min(front,key=lambda x:x.d-r.d)
                    longitudinal=physical_ahead_gap(nearest)
                    lateral=abs(nearest.lane-r.lane)
                    distance_factor=max(0.,1.-(max(0.,longitudinal-WHEEL_OFFSET) if variant in ('H','I','J') else longitudinal)/10.)
                    lateral_factor=max(.18,1.-lateral/1.25)
                    benefit=(.62 if variant in ("E","G","H","I","J","K","L") else .48)*distance_factor*lateral_factor
                    nearby=sum(1 for x in riders if x is not r and 0<physical_ahead_gap(x)<15 and abs(x.lane-r.lane)<1.5)
                    benefit+=min(.12,.04*max(0,nearby-1))
                    aero_factor=max((.31 if variant in ("E","G","H","I","J","K","L") else .43),1.-benefit*draft_speed_factor(r.v))
                draft=aero_factor<.95
            if variant in ('I','J') and any(abs(x.d-r.d)<WHEEL_OFFSET and abs(x.lane-r.lane)<.70 for x in riders if x is not r):
                aero_factor=1.0
                draft=False
            aerodynamic_samples.append(aero_factor)
            if r.finished_at is None:
                if variant in ('H','I','J'):
                    overlap=any(abs(x.d-r.d)<WHEEL_OFFSET and abs(x.lane-r.lane)<.7 for x in riders if x is not r)
                    if overlap:r.overlap_time_s+=DT
                    if overlap and not draft:r.no_draft_overlap_s+=DT
                aligned_gaps=[physical_ahead_gap(x) for x in riders if x is not r and physical_ahead_gap(x)>0 and abs(x.lane-r.lane)<1.15]
                near=min(aligned_gaps,default=999.)
                if variant in ('H','I','J'):
                    near=max(-10.,near-WHEEL_OFFSET)
                    cb=next((i for i,b in enumerate((0.,.4,1.,2.,5.)) if near<b),5)
                    r.wheel_clearance_bins[cb]+=DT
                edges=(1.,2.,4.,7.,9.)
                bin_idx=next((i for i,b in enumerate(edges) if near<b),5)
                r.gap_bins[bin_idx]+=DT
                if near<2.:r.close_draft_s+=DT
                r.draft_elapsed_s+=DT
                r.aero_saved_integral+=(1-aero_factor)*DT
                # At current speed, compare aerodynamic demand vs no drafting.
                solo_aero_power=267*(r.v/11.)**3
                r.aero_baseline_integral+=solo_aero_power*DT
                r.aero_savings_power_integral+=solo_aero_power*(1-aero_factor)*DT
                if aero_factor<.70:r.draft_deep_s+=DT
            if draft and r.finished_at is None:r.draft_s+=DT
            # New attacks: hazard varies by profile + tactical opportunity and personal traits.
            # A global crowd response prevents synchronized independent attacks.
            energy_ratio=r.store/r.store_max
            recent=sum(1 for e in recent_attacks if t-e<45)
            solo_far_ahead=(r.d-mid)>20
            if r.mode=='draft' and t>r.cooldown and energy_ratio>.56 and not solo_far_ahead:
                base={'attacker':.031,'tt':.016,'sprinter':.004}[r.role]
                post_boost=2.5 if post_sprint else 1.
                mode_mult=1.35 if race_mode=='points' else .66
                # Laggards are more willing to gamble for sprint points.
                score_need=1.25 if race_mode=='points' and points_score[r.id]<max(points_score.values(),default=0) else 1.
                pre_penalty=.18 if pre_sprint else 1.
                busy_penalty=.40 if active_attackers else (.7 if recent else 1.)
                # Watch whether the bunch is moving as a group; penalize attacks from far behind.
                gap_penalty=.10 if r.d<mid-13 else 1.
                prob=clamp(base*DT*r.aggression*2.0*post_boost*pre_penalty*busy_penalty*gap_penalty*mode_mult*score_need,0,.2)
                if rng.random()<prob:
                    r.mode='attack';r.attack_start=t;r.attacks+=1
                    r.until=t+rng.uniform(18,47)*r.patience
                    r.last_attack=t;r.attack_max_gap=0.;r.attack_energy_start=r.store;r.cooldown=t+rng.uniform(25,75)
                    active_attackers.append(r)
                    recent_attacks.append(t)
                    attack_events.append({'seed':seed,'riders':count,'lap':int(max(r.d,0)//LAP)+1,'race_s':round(t,1),'id':r.id,'role':r.role,'post_sprint':bool(post_sprint),'reserve_pct':round(100*energy_ratio,1),'simultaneous':len(active_attackers)>1})
                    if len(active_attackers)>1:overlap_attacks+=1
            # Cooperation: a pursuer volunteers for a bounded shift. Others actively draft.
            needs_chase=(max(lead,player_d)-mid)>13
            if r.mode=='draft' and t>r.until and len(pack)>=3 and needs_chase and r in pack and r.cooperation>.4 and energy_ratio>.32:
                if rng.random()<.016*DT*r.cooperation/max(1,sum(1 for x in pack if x.mode=='pull')+1):
                    r.mode='pull';r.until=t+rng.uniform(12,24)
            if r.mode=='pull' and t>=r.until:
                r.mode='draft';r.cooldown=t+rng.uniform(25,65)
                if variant in ('K','L'):
                    r.pull_exit_until=t+8.;r.pull_exit_count+=1

            if r.mode=='solo_tt':
                # Sustainable solo based on CP with a small response to a closing gap.
                remaining=max(0.,finish_line-r.d)
                urgency=clamp((22.-(r.d-main_front))/30.,0.,1.)
                target=r.aero*(.98+.10*urgency)
            elif r.mode=='break_pull':
                # Stronger than sustainable solo, but bounded by W' and fatigue.
                # Shorter sprinter pulls compensate for their higher relative cost.
                target=r.aero*(1.17 if r.role=='sprinter' else 1.24) if breakaway_v else r.aero*(1.14 if r.role=='sprinter' else 1.19)
                r.lead_s+=DT
            elif r.mode=='break_draft':
                target=r.aero*(.77 if draft else 1.01) if breakaway_v else r.aero*(.73 if draft else .86)
                # W experiment: preserve a real escape partner's wheel using speed
                # and the physical road-load inversion (no teleport, no speed cap).
                if break_follow and r.id in break_members:
                    partners=break_members[r.id][1]
                    ahead=[x for x in partners if x is not r and .3 < x.d-r.d < 28]
                    if ahead:
                        wheel=min(ahead,key=lambda x:x.d-r.d)
                        gap=wheel.d-r.d
                        closing=clamp(.34*(gap-2.5),-1.0,1.8)
                        desired_v=max(5.5,wheel.v+closing)
                        required=road_power(desired_v,aero_factor)/DRIVETRAIN_EFF
                        # Keep physiological power bound; no boosted physical ability.
                        max_target=r.aero+min(150.,80.+100.*r.store/max(r.store_max,1.))
                        target=clamp(required,.65*r.aero,max_target)
            elif r.mode=='chase':
                target=r.aero*1.18
            elif r.mode=='attack':
                # Not always full max; tactical attack reserves some capacity.
                target=r.aero+.39*(r.peak-r.aero)
            elif r.mode=='pull':
                target=r.aero+.23*(r.peak-r.aero)
                r.lead_s+=DT
            elif variant=='C' and (finish_line-r.d)<550 and (finish_line-r.d)>0 and r.d>=mid-25:
                # Everyone can sprint. Timing preference is continuous and role-dependent,
                # dependent on position and remaining W' rather than hard-coded eligibility.
                remaining=finish_line-r.d
                preferred={'tt':410.,'attacker':260.,'sprinter':165.}[r.role]
                reserve=max(0.,r.store/r.store_max)
                if remaining<preferred*(.75+.40*reserve) and reserve>.08:
                    if not r.sprint_started:r.sprint_started=True;r.sprint_start_m=remaining
                    duration=max(5.,remaining/max(r.v,5))
                    target=pcurve(duration,r.phys.cp,r.phys.wmax,r.phys.pmax)*(.88+.10*reserve)
                else:
                    target=r.aero*(.76 if draft else .91)
            elif pre_sprint and not experiment and r.role=='sprinter' and energy_ratio>.30:
                target=r.aero+.37*(r.peak-r.aero)
            elif r.d<mid-15:
                target=r.aero+.15*(r.peak-r.aero)
            else:
                target=r.aero*(.76 if draft else .91)
            # Deliberate refusal to tow: most of the bunch stays on a wheel,
            # while the actual front riders reduce their effort below CP.
            if soft_pace_active and r.mode in ('draft','pull') and r.finished_at is None and abs(r.d-mid)<13:
                at_front=r.d>=front_pack.d-3.0
                if at_front:
                    r.mode='draft' if r.mode=='pull' else r.mode
                    target=min(target,r.aero*(.65+.11*rng.random()))
                else:
                    # Followers don't automatically jump into a pointless pull.
                    # Their wheels remain free to follow in normal dynamics.
                    target=min(target,r.aero*.77)
            # P: a rider without reason to tow gradually coasts down to <50% CP.
            # After ~10 seconds in front he moves up the track to find shelter.
            if idle_peloton and r.mode in ('draft','pull') and r in main_cluster:
                if r.mode=='pull':r.mode='draft'
                if r.id in front_ids:
                    elapsed=t-idle_front_since.get(r.id,t)
                    fraction=max(.43, .77-.085*elapsed)
                    target=min(target,r.aero*fraction)
                    idle_front_power_samples.append(fraction)
                    if elapsed>=10 and t>=r.pull_exit_until:
                        r.pull_exit_until=t+8.;r.pull_exit_count+=1
                        r.lane_target=LANES[-1];r.lane_lock_until=t+8.
                        idle_pull_offs+=1
                        idle_front_since[r.id]=t+8. # avoid repeated pull-offs
                else:
                    # A following rider does not independently accelerate past the leader.
                    target=min(target,r.aero*.62)
            if sprint_switch and not final750 and race_mode=='scratch' and 0<finish_line-r.d<340 and r.mode!='attack':
                remaining=finish_line-r.d
                rank=1+sum(x.d>r.d for x in riders)
                # Sprinters use an explosive, later effort; TT riders longer and more conservative.
                onset={'tt':185.,'attacker':185.,'sprinter':185.}[r.role]
                onset*=1.12 if rank>3 else 1.
                if remaining<onset and r.store/r.store_max>.07:
                    seconds=max(5.,remaining/max(r.v,5.))
                    watts=pcurve(seconds,r.phys.cp,r.phys.wmax,r.phys.pmax)*{'tt':.72,'attacker':.84,'sprinter':.98}[r.role]
                    budget=r.phys.cp+(.85*r.store/max(6.,seconds))
                    target=max(target,min(watts,budget))
                    r.sprint_started=True
                    if r.sprint_start_m is None:r.sprint_start_m=remaining
            # FINAL_750: all bunch riders prioritize a wheel and useful placing.
            # Only riders within 32 m of the median chase group participate;
            # a solo leader continues their own tactical escape.
            if final_stage and r.mode in ('draft','pull') and abs(r.d-mid)<32 and r.finished_at is None:
                r.final_mode_seconds+=DT
                remaining=max(0.,finish_line-r.d)
                rank=1+sum(x.d>r.d for x in riders if x.finished_at is None)
                reserve=r.store/max(1.,r.store_max)
                # During build-up use progressively higher power for a forward position.
                # This is a physical watt demand, not an imposed group speed.
                phase=clamp((750.-remaining)/520.,0.,1.)
                preferred_rank=3 if r.role=='sprinter' else (4 if r.role=='attacker' else 3)
                lag=max(0,rank-preferred_rank)
                gap_from_front=max(0.,lead-r.d)
                desired_ratio=(.82+.19*phase+.018*min(5,lag)+.010*min(20.,gap_from_front))
                desired_ratio=min(desired_ratio,1.20 if reserve>.23 else 1.03)
                # While already on a useful wheel, save as much effort as possible.
                if rank<=preferred_rank and draft:desired_ratio-=.13
                # Prevent tactical coast if a gap opens late.
                if remaining<350 and gap_from_front>9:desired_ratio=max(desired_ratio,1.09)
                if remaining>100 and (not r.sprint_started):
                    positioning_target=r.aero*desired_ratio
                    if positioning_target>target:
                        r.final_position_seconds+=DT
                        r.final_pos_kj+=max(0.,positioning_target-r.aero)*DT/1000.
                    target=max(target,positioning_target)
                # Early lateral mobility for passing, without artificially moving forward.
                if lag>=2 and remaining>110 and t>=r.lane_lock_until and r.mode=='draft':
                    r.lane_target=LANES[-1] if r.lane_target<LANES[3] else LANES[0]
                    r.lane_lock_until=t+16
                # Personal sprint onset: distance, gap, energy, and sprint specialization.
                onset={'tt':235.,'attacker':200.,'sprinter':195.}[r.role]
                onset*=1.+.08*min(3,max(0,rank-3))
                if reserve<.16:onset*=.85
                if remaining<=onset and reserve>.055:
                    seconds=max(5.,remaining/max(r.v,5.))
                    watts=pcurve(seconds,r.phys.cp,r.phys.wmax,r.phys.pmax)*{'tt':.75,'attacker':.87,'sprinter':.99}[r.role]
                    budget=r.phys.cp+.88*r.store/max(6.,seconds)
                    target=max(target,min(watts,budget))
                    r.sprint_started=True
                    if r.sprint_start_m is None:r.sprint_start_m=remaining
            # Tactical scratch finish: all roles may contest the win. Choose onset by
            # remaining distance, actual rank and reserve, rather than role eligibility.
            if variant in ('I','J') and race_mode=='scratch' and 0 < finish_line-r.d < 560 and r.mode != 'attack':
                remaining=finish_line-r.d
                rank=1+sum(x.d>r.d for x in riders)
                reserve=r.store/max(1.,r.store_max)
                start=({'tt':380.,'attacker':265.,'sprinter':185.} if variant=='I' else {'tt':285.,'attacker':210.,'sprinter':145.})[r.role]
                # Start slightly earlier if falling behind the winning group.
                start*=1.0+(.12 if rank>3 else 0.)
                if remaining<=start and reserve>.07:
                    if not r.sprint_started:r.sprint_started=True;r.sprint_start_m=remaining
                    seconds=max(5.,remaining/max(r.v,5.))
                    intended=pcurve(seconds,r.phys.cp,r.phys.wmax,r.phys.pmax)*( (.95 if r.role=='sprinter' else .90) if variant=='I' else {'tt':.72,'attacker':.83,'sprinter':.98}[r.role])
                    if variant=='J':
                        budget=r.phys.cp + .90*r.store/max(6.,seconds)
                        intended=min(intended,budget)
                    target=max(target,intended)
                        # Active wheel following, without collisions or compulsory steering.
            # Choose a viable wheel ahead; match its speed while recovering from small gaps.
            # A few seconds above CP may be worthwhile to obtain subsequent drag savings.
            if variant in ('D','E','F','G','K','L','H','I','J') and r.mode=='draft' and not ((variant in ('I','J') or sprint_switch or final750) and r.sprint_started) and finish_line-r.d>0:
                candidates=[x for x in riders if x is not r and (WHEEL_OFFSET+MIN_WHEEL_CLEARANCE if variant in ('H','I','J') else .35) < physical_ahead_gap(x) < 21 and x.finished_at is None]
                if candidates:
                    # Prefer nearby, roughly aligned wheels; soft lane tracking (not collision).
                    if sprinter_wheel_economy and variant=='L' and r.role=='sprinter':
                        # Shelter first: prefer a genuinely aligned wheel and don't
                        # swap between neighboring targets every two seconds.
                        # Keeping a wheel never overrides the geometric conflict guard.
                        previous=next((x for x in candidates if x.id==r.shelter_wheel_id),None)
                        if previous is not None and 1.4 < physical_ahead_gap(previous) < 8.0 and abs(previous.lane-r.lane)<.95:
                            wheel=previous
                        else:
                            sheltered=[x for x in candidates if physical_ahead_gap(x)<8.5 and abs(x.lane-r.lane)<1.15]
                            pool=sheltered if sheltered else candidates
                            wheel=min(pool,key=lambda x:
                                abs(physical_ahead_gap(x)-2.5)+2.0*abs(x.lane-r.lane)
                                +(0. if x.id==r.shelter_wheel_id else .9))
                        if r.shelter_wheel_id is not None and r.shelter_wheel_id!=wheel.id:
                            r.shelter_wheel_changes+=1
                        r.shelter_wheel_id=wheel.id
                    else:
                        wheel=min(candidates,key=lambda x:abs((physical_ahead_gap(x))-(WHEEL_OFFSET+0.65 if variant in ('H','I','J') else (1.35 if variant in ("F","G","K","L") else 2.2)))+1.6*abs(x.lane-r.lane))
                    gap_to_wheel=physical_ahead_gap(wheel)
                    r.wheel_targets+=1;wheel_target_events+=1
                    if gap_to_wheel<4.0:r.wheel_good_s+=DT
                    if gap_to_wheel>7:r.wheel_gap_loss_s+=DT
                    # Keep a small positive closing speed for transient gaps.
                    if sprinter_wheel_economy and variant=='L' and r.role=='sprinter':
                        # Avoid costly repeated surges for a 1-3 m correction.
                        # A gap must actually open before asking for a catch-up.
                        reserve_frac=r.store/max(1.,r.store_max)
                        closing=clamp(.18*(gap_to_wheel-2.7),-.8,1.2)
                        if gap_to_wheel>5.5:
                            closing=clamp(.34*(gap_to_wheel-1.8),0.,2.0 if reserve_frac>.30 else 1.5)
                    else:
                        closing=clamp((.27 if variant in ('H','I','J') else (.34 if variant in ("F","G","K","L") else .23))*(gap_to_wheel-(WHEEL_OFFSET+0.65 if variant in ('H','I','J') else (1.35 if variant in ("F","G","K","L") else 2.2))),-1.5,2.0)
                    wanted_speed=max(5.5,wheel.v+closing) if no_speed_cap else clamp(wheel.v+closing,5.5,16.)
                    # Invert the same stylized road-load law used below. If unable
                    # to generate required watts, a gap opens naturally.
                    required=road_power(wanted_speed,aero_factor)/DRIVETRAIN_EFF if no_speed_cap else 33+267*aero_factor*(wanted_speed/11.)**3
                    # Avoid exhausting the entire W' simply to sit on a wheel.
                    reserve_frac=r.store/max(1.,r.store_max)
                    if sprinter_wheel_economy and variant=='L' and r.role=='sprinter':
                        # Above-CP expenditure is a limited resource: use a smaller
                        # budget to bridge tiny gaps, retaining the normal CP/W' physics.
                        # Only conserve aggressively once close enough to shelter.
                        # Catch-up watts remain available for genuinely growing gaps.
                        if gap_to_wheel<=4.0:
                            overhead=60. if reserve_frac>.28 else (25. if reserve_frac>.13 else 0.)
                        elif gap_to_wheel<=6.0:
                            overhead=115. if reserve_frac>.28 else (75. if reserve_frac>.13 else 20.)
                        else:
                            overhead=165. if reserve_frac>.28 else (90. if reserve_frac>.13 else 0.)
                        required=min(required,r.aero+overhead)
                    elif reserve_frac<.13:required=min(required,r.aero*.96)
                    elif reserve_frac<.28:required=min(required,r.aero+90)
                    else:required=min(required,r.aero+165)
                    if required>r.aero:r.wheel_accel_j+=(required-r.aero)*DT
                    target=required
                    if t<14.:
                        launch_weight=clamp((14.-t)/7.,0.,1.)*clamp((11.-r.v)/3.,0.,1.)
                        launch_watts=min(450., max(350.,r.aero*1.65))
                        steady=r.aero*(.76 if draft else .91)
                        target=max(target,steady+(launch_watts-steady)*launch_weight)
                    # Soft automatic lateral adaptation. No track resizing or collisions.
                    if variant not in ('K','L'):r.lane+=clamp(wheel.lane-r.lane,-.20,.20)
                    elif variant=='K':
                        # Choose adjacent track slot to avoid persistent overlapping.
                        # A gentle return from the higher line follows a short pull-off.
                        if t<r.pull_exit_until:r.lane_target=LANES[-1]
                        else:
                            options=LANES
                            r.lane_target=min(options,key=lambda z:1.5*abs(z-wheel.lane)+
                                3.0*sum(abs(x.d-r.d)<2.0 and abs(x.lane-z)<.44 for x in riders if x is not r))

                    else:
                        # L: shelter-first wheel alignment; avoid unnecessary
                        # move to an empty corridor when safely behind a wheel.
                        if t<r.pull_exit_until:
                            r.lane_target=LANES[-1]
                        else:
                            def conflict(z):
                                return sum(1 for x in riders if x is not r and abs(x.d-r.d)<1.45 and abs(x.lane-z)<.85)
                            min_align_gap=1.55 if sprinter_wheel_economy and r.role=='sprinter' else 2.1
                            if gap_to_wheel>min_align_gap and gap_to_wheel<21. and abs(r.lane_target-wheel.lane)>.4:
                                r.lane_target=min(LANES,key=lambda z:abs(z-wheel.lane))
                                r.lane_lock_until=t+1.
                            if conflict(r.lane_target):
                                best=min(LANES,key=lambda z:100*conflict(z)+2.4*abs(z-wheel.lane)+.35*abs(z-r.lane))
                                if not conflict(best) and best!=r.lane_target:
                                    r.lane_target=best
                                    r.lane_lock_until=t+1.

                    r.wheel_follow_s+=DT
                elif r.d < mid - 8 and r.store/r.store_max > .22:
                    # Soft limited chase if no immediately reachable wheel exists.
                    # Does not teleport rider or guarantee reconnection.
                    gap_to_pack=max(0., mid-r.d)
                    closing=clamp(.06*gap_to_pack,.35,1.05)
                    intended=clamp(statistics.median(x.v for x in riders)+closing,5.5,15.)
                    # No drafting discount without a nearby wheel.
                    catchup_cap=r.aero+135.
                    target=min(33+267*(intended/11.)**3,catchup_cap)
            # During collective reluctance, do not let wheel matching undo
            # the explicit decision not to accelerate for a pointless overtake.
            if idle_peloton and not final_stage and r in main_cluster and r.mode=='draft':
                if r.id in front_ids:
                    elapsed=max(0.,t-idle_front_since.get(r.id,t))
                    target=min(target,r.aero*max(.43,.77-.085*elapsed))
                else: target=min(target,r.aero*.62)
            # Match pace in the bunch; reduces unrealistic progressive stretching.
            if variant not in ('D','E','F','G','K','L','H','I','J') and r.mode=='draft' and abs(r.d-mid)<13:
                target += clamp((mid-r.d)*6,-65,65)
            if t<14. and r.mode=='draft':
                launch_weight=clamp((14.-t)/7.,0.,1.)*clamp((11.-r.v)/3.,0.,1.)
                launch_watts=min(450.,max(350.,r.aero*1.65))
                target=max(target, r.aero*(.76 if draft else .91)*(1.-launch_weight)+launch_watts*launch_weight)
            if experiment:
                target=experiment.demand(r,target,riders,t)
            power=r.step_power(target,DT)
            # Wheel shelter lets same speed at lower actual power; no artificial group speed bonus.
            # Dynamical target speed with inertia.
            v_target=11.0*((power/300./(.82 if draft else 1.))**(1/3)) if variant=='A' else 11.0*((max(power-33,1)/(267*aero_factor))**(1/3))
            desired.append((power,aero_factor) if no_speed_cap else clamp(v_target,5.5,16.))
        for r,tar in zip(riders,desired):
            if variant in ('K','L'):
                # Pull-off: go high, deliberately stop towing, rejoin after ~8s.
                if t<r.pull_exit_until:r.lane_target=LANES[-1]
                elif r.mode=='attack':r.lane_target=LANES[-1]
                elif r.mode=='pull':r.lane_target=LANES[0]
                elif variant=='K' and r.mode=='draft' and r.wheel_targets==0:r.lane_target=min((-.82,0.,.82),key=lambda z:sum(abs(x.d-r.d)<2 and abs(x.lane-z)<.90 for x in riders if x is not r))
                if variant=='L' and r.mode in ('attack','pull'):
                    r.lane_lock_until=t+35
                previous_lane=r.lane
                # Hard proximity conflict only; otherwise retain shelter.
                def hard_conflict(z):
                    return sum(1 for x in riders if x is not r and abs(x.d-r.d)<1.45 and abs(x.lane-z)<.85)
                if hard_conflict(r.lane_target):
                    target_wheel=r.lane_target
                    best=min(LANES,key=lambda z:100*hard_conflict(z)+2.4*abs(z-target_wheel)+.35*abs(z-r.lane))
                    if not hard_conflict(best):
                        r.lane_target=best
                        r.lane_lock_until=t+1.
                r.lane+=clamp(r.lane_target-r.lane,-.35,.35)
                if abs(r.lane-previous_lane)>.001:r.lane_change_s+=DT
                dh=bank_height(r.d,r.lane)-bank_height(r.d,previous_lane)
                if dh>0:r.bank_up_j+=80*9.81*dh
                else:r.bank_down_j+=80*9.81*(-dh)
                # Energy conservation on the slope, damped by subsequent drag.
                r.v=math.sqrt(max(0.,r.v**2-2*9.81*dh))
                idx=min(range(6),key=lambda j:abs(r.lane-LANES[j]))
                r.lane_occupation[idx]+=DT
            r.v=integrate_speed(r.v,tar[0],tar[1],DT) if no_speed_cap else r.v+(tar-r.v)*DT/7.
            r.d+=r.v*DT/(lane_distance_multiplier(r.d,r.lane) if variant in ('K','L') else 1.)
        if variant in ('I','J'):
            # A geometric lane/spacing constraint. Normally a follower cannot drift
            # through the wheel in front. Intentional attack/sprint: soft lateral pass.
            for behind in sorted(riders,key=lambda x:x.d,reverse=True):
                if behind.mode=='attack' or behind.sprint_started:
                    continue
                fronties=[x for x in riders if x is not behind and x.d>=behind.d and abs(x.lane-behind.lane)<.58]
                if fronties:
                    f=min(fronties,key=lambda x:x.d-behind.d)
                    if f.d-behind.d < WHEEL_OFFSET+MIN_WHEEL_CLEARANCE:
                        behind.d=min(behind.d,f.d-(WHEEL_OFFSET+MIN_WHEEL_CLEARANCE))
                        behind.v=min(behind.v,f.v)
            for a in riders:
                if not (a.mode=='attack' or a.sprint_started):continue
                for b in riders:
                    if a is b:continue
                    if abs(a.d-b.d)<WHEEL_OFFSET+MIN_WHEEL_CLEARANCE and abs(a.lane-b.lane)<.6:
                        a.lane=clamp(a.lane+(0.25 if a.lane<=b.lane else -0.25),-1.5,1.5)
                # Soft visual spacing: close aligned riders are moved to different lanes,
        # not stopped or collided. Intentional passing remains possible.
        if variant in ('H','I','J'):
            for i,a in enumerate(riders):
                if a.mode!='draft':continue
                for b in riders[i+1:]:
                    if b.mode!='draft':continue
                    if abs(a.d-b.d)<WHEEL_OFFSET+MIN_WHEEL_CLEARANCE and abs(a.lane-b.lane)<.55:
                        shift=.12 if a.lane<=b.lane else -.12
                        a.lane=clamp(a.lane-shift,-1.1,1.1)
                        b.lane=clamp(b.lane+shift,-1.1,1.1)
        if real_laps and race_mode=='scratch':
            active=[x for x in riders if x.finished_at is None]
            # Reference peloton = largest cluster of unlapped riders in absolute progress.
            ordinary=[x for x in active if x.lap_credits==0]
            ordered_base=sorted(ordinary,key=lambda x:x.d)
            comps=[]
            for x in ordered_base:
                if not comps or x.d-comps[-1][-1].d>12: comps.append([x])
                else: comps[-1].append(x)
            pel=max(comps,key=len) if comps else []
            if len(pel)>=3:
                tail=min(x.d for x in pel)
                middle=statistics.median(x.d for x in pel)
                for r in active:
                    if r in pel or r.lap_credits>0:continue
                    advantage=r.d-tail
                    # Rider comes around the 250m oval behind the back of the bunch.
                    # The contact zone is within 18m physically behind its tail.
                    if 232<=advantage<=250.5 and r.d-middle>=210:
                        physical_gap=LAP-advantage
                        r.lap_credits=1;r.lap_join_time=t+DT
                        r.mode='draft';r.cooldown=t+120.;r.until=t+120.
                        lap_events.append({'seed':seed,'time_s':round(t+DT,1),
                            'id':r.id,'role':r.role,'peloton_size':len(pel),
                            'advantage_to_tail_m':round(advantage,2),
                            'physical_gap_m':round(physical_gap,2),
                            'remaining_m':round(finish_line-r.d,1)})
        if real_laps:
            for r in riders:
                if r.lap_credits and r.finished_at is None:
                    # Check actually sheltered by a wheel one lap below own progress.
                    if any(.3<(x.d+LAP-r.d)<9 and abs(x.lane-r.lane)<1.15
                           for x in riders if x is not r and x.lap_credits==0):
                        r.lap_draft_s+=DT
        # Passive observation: does NOT modify speed, draft, lap count, or winner.
        if lap_probe is not None and race_mode == 'scratch':
            lap_probe.observe(t + DT, riders, seed)
        # Diagnostic at every 2-second step in the final 500 m.
        if max(x.d for x in riders)>=finish_line-750:
            lead_now=max(x.d for x in riders)
            ordered_now=sorted(riders,key=lambda x:x.d, reverse=True)
            for rank_now, rr in enumerate(ordered_now, 1):
                if rr.finished_at is None:
                    detail_trace.append({'seed':seed,'laps':laps,'count':count,'variant_test':('FINAL_750' if final750 else ('EQUAL_SPRINT' if sprint_switch else 'Q')),'time_s':round(t+DT,2),'id':rr.id,'role':rr.role,'rank':rank_now,'remaining_m':round(finish_line-rr.d,2),'gap_to_leader_m':round(lead_now-rr.d,2),'speed_kmh':round(rr.v*3.6,2),'power_w_step':round((rr.power_sum-getattr(rr,'prev_power_sum',0.))/DT,1),'w_pct':round(100*rr.store/rr.store_max,2),'mode':rr.mode,'sprint_started':rr.sprint_started,'final_mode_s':rr.final_mode_seconds})
        for rr in riders:rr.prev_power_sum=rr.power_sum
        # Race gap snapshots relative to the leader (by distance) at given intervals.
        leader_distance=max(x.d for x in riders)
        for remaining in (500,200,50):
            if remaining not in checkpoints and leader_distance>=finish_line-remaining:
                best=max(riders,key=lambda x:x.d)
                second=sorted(riders,key=lambda x:x.d,reverse=True)[1]
                checkpoints[remaining]=(best.role,round(best.d-second.d,2),len([x for x in riders if best.d-x.d<12]))
        # Intermediate sprints are awarded at a common race clock when median crosses
        # each 5-lap mark. Ranking uses the riders' position at that instant;
        # this is a proxy, not true line crossing interpolation.
        if not experiment and race_mode=='points' and next_sprint_lap<laps and statistics.median(r.d for r in riders)>=next_sprint_lap*LAP:
            order=sorted(riders,key=lambda x:x.d,reverse=True)
            for rank,bonus in enumerate((3,2,1)):
                points_score[order[rank].id]+=bonus
            sprint_awards.append({'lap':next_sprint_lap,'podium':[x.id for x in order[:3]]})
            next_sprint_lap+=5
        # Dropped = more than 20 m behind the median of the largest 12-m connected cluster
        # for at least 20 seconds. Requires sustained gap, not a momentary sprint split.
        sorted_group=sorted(riders,key=lambda x:x.d)
        components=[]; component=[sorted_group[0]]
        for x in sorted_group[1:]:
            if x.d-component[-1].d<=12:component.append(x)
            else:components.append(component);component=[x]
        components.append(component)
        main=max(components,key=lambda g:(len(g),-abs(statistics.mean(x.d for x in g)-mid)))
        tail=min(x.d for x in main)
        for r in riders:
            deficit=max(0.,tail-r.d) if r not in main else 0.
            r.max_deficit=max(r.max_deficit,deficit)
            if deficit>20.:r.drop_streak+=DT
            else:r.drop_streak=0.
            if r.drop_streak>=20:
                r.dropped_s+=DT
                dropped_samples+=1
                any_dropped_ids.add(r.id)
                if not r.dropped_now:
                    r.dropped_events+=1;r.dropped_now=True
                    dropout_events.append({'seed':seed,'riders':count,'id':r.id,'role':r.role,'race_s':round(t,1),'lap':int(max(0,r.d)//LAP)+1,'deficit_m':round(deficit,1),'recently_attacked':t-r.last_attack<180})
            elif deficit<=20:r.dropped_now=False
        if experiment:
            experiment.observe(t,DT,before,riders)
            if experiment.done:
                return experiment.result(seed,riders)
        for r in riders:
            if not experiment and r.finished_at is None and r.d>=finish_line:
                frac=clamp((finish_line-r.last_d)/max(.00001,r.d-r.last_d),0,1)
                r.finished_at=t+DT*frac
                r.finish_reserve_pct=100*r.store/r.store_max
                r.finish_fatigue_pct=100*r.phys.fatigue
            r.last_d=r.d
        # Player rides constant wattage; no virtual cooperative boost.
        player_v=integrate_speed(player_v,player_w,1.,DT)
        previous_player_d=player_d
        player_d+=player_v*DT
        if player_finished_at is None and player_d>=finish_line:
            player_finished_at=t+DT*clamp((finish_line-previous_player_d)/max(.00001,player_d-previous_player_d),0,1)
        t+=DT
        if len(recent_attacks)>100:recent_attacks=[a for a in recent_attacks if t-a<45]
    if experiment:
        raise RuntimeError('incomplete experiment')
    # Cluster finishers using time difference, not only winner profile.
    # A finish-position proxy (scratch), NOT a points-race winner.
    # Record everyone's interpolated finish timestamp; player is also included.
    finish_order=sorted(riders,key=lambda r:r.finished_at if r.finished_at is not None else float('inf'))
    winner=(min(finish_order,key=lambda r:(-r.lap_credits,r.finished_at if r.finished_at is not None else float("inf"))) if real_laps and race_mode=="scratch" else finish_order[0])
    # Athletes not finished within the time limit are placed by distance.
    if winner.finished_at is None:
        winner=max(riders,key=lambda x:x.d)
    if race_mode=='points':
        # Finish scoring: 6-4-2-1. Lap-taking bonuses NOT simulated, because
        # actual 250m lap gains require a spatial pack/overtake model.
        for rr,bonus in zip(finish_order,(6,4,2,1)):
            points_score[rr.id]+=bonus
        points_winner=min(riders,key=lambda rr:(-points_score[rr.id],rr.finished_at if rr.finished_at is not None else float('inf')))
    else:
        points_winner=winner
    if breakaway_v:
        for st in turn_states.values():
            break_history.append({'group_id':st['uid'],'start_s':st['born'],'end_s':st['last_seen'],
                'duration_s':st['last_seen']-st['born']+DT,'members':','.join(map(str,sorted(st['members']))),
                'max_gap_m':round(st['max_gap'],1),'rotations':st['rotations'],'outcome':'active_at_race_end'})
    rider_positions=[{'final_position_seconds':round(sum(x.final_position_seconds for x in riders),1),'final_pos_kj':round(sum(x.final_pos_kj for x in riders),2),'final_mode_seconds':round(sum(x.final_mode_seconds for x in riders),1),'variant':variant,'lane_switches':r.lane_switches,'lane_rejects':r.lane_rejects,'pull_exit_count':r.pull_exit_count,'bank_up_kj':round(r.bank_up_j/1000,2),'bank_down_kj':round(r.bank_down_j/1000,2),'lane_change_pct':round(100*r.lane_change_s/max(1.,r.finished_at or t),1),'lane_inner_pct':round(100*r.lane_occupation[0]/max(1.,r.finished_at or t),1),'lane_mid_pct':round(100*r.lane_occupation[1]/max(1.,r.finished_at or t),1),'lane_outer_pct':round(100*r.lane_occupation[2]/max(1.,r.finished_at or t),1),'sprint_start_m':round(r.sprint_start_m,1) if r.sprint_start_m is not None else '', 'seed':seed,'riders':count,'id':r.id,'role':r.role,'lap_credits':r.lap_credits,'lap_draft_s':round(r.lap_draft_s,1),'lap_join_time':r.lap_join_time or '', 'finish_s':round(r.finished_at,2) if r.finished_at is not None else '', 'dropped_s':round(r.dropped_s,1),'drop_events':r.dropped_events,'max_deficit_m':round(r.max_deficit,1),'attacks':r.attacks,'solo_seconds':r.solo_seconds,'break_draft_seconds':r.break_draft_seconds,'break_turns':r.break_turns,'break_refusals':r.break_refusals,'break_pull_seconds':r.break_pull_seconds,'chase_seconds':r.chase_seconds,'group_joins':r.group_join_count,'counterattacks':r.counterattack_count,'final_reserve_pct':round(getattr(r,'finish_reserve_pct',100*r.store/r.store_max),1),'points':points_score[r.id], 'mean_power_w':round(r.power_sum/max(r.finished_at or t,1),1),'pct_time_above_cp':round(100*getattr(r,'above_cp_s',0.)/max(r.finished_at or t,1),1),'mean_speed_kmh':round(3.6*finish_line/max(r.finished_at or t,1),2),'critical_power_w':round(r.phys.cp,1),'end_fatigue_pct':round(getattr(r,'finish_fatigue_pct',r.phys.fatigue*100),1),'gap_lt1_pct':round(100*r.gap_bins[0]/max(1,r.draft_elapsed_s),2),'gap_1_2_pct':round(100*r.gap_bins[1]/max(1,r.draft_elapsed_s),2),'gap_2_4_pct':round(100*r.gap_bins[2]/max(1,r.draft_elapsed_s),2),'gap_4_7_pct':round(100*r.gap_bins[3]/max(1,r.draft_elapsed_s),2),'gap_7_9_pct':round(100*r.gap_bins[4]/max(1,r.draft_elapsed_s),2),'gap_9plus_pct':round(100*r.gap_bins[5]/max(1,r.draft_elapsed_s),2),'draft_time_pct':round(100*r.draft_s/max(1,r.draft_elapsed_s),2),'mean_aero_drag_reduction_pct':round(100*r.aero_saved_integral/max(1,r.draft_elapsed_s),2),'speed_weighted_aero_drag_reduction_pct':round(100*r.aero_savings_power_integral/max(1,r.aero_baseline_integral),2),'saved_aero_w_mean':round(r.aero_savings_power_integral/max(1,r.draft_elapsed_s),2),'deep_draft_time_pct':round(100*r.draft_deep_s/max(1,r.draft_elapsed_s),2),'overlap_pct':round(100*r.overlap_time_s/max(1,r.draft_elapsed_s),2),'overlap_without_draft_pct':round(100*r.no_draft_overlap_s/max(1,r.draft_elapsed_s),2),**{'clearance_bin_'+str(i)+'_pct':round(100*v/max(1,r.draft_elapsed_s),2) for i,v in enumerate(r.wheel_clearance_bins)}} for r in riders]
    events_by_lap=Counter(e['lap'] for e in attack_events)
    # sprints without attack in first 170m after sprint
    post_laps=[l for l in (5,10,15,20,30,35,40,45) if l<laps]
    no_attack_sprints=sum(not any(e['post_sprint'] and e['lap']==lap+1 for e in attack_events) for lap in post_laps)
    lead_switches=sum(a!=b for a,b in zip(leaders,leaders[1:]))
    return ({'final_position_seconds':round(sum(x.final_position_seconds for x in riders),1),'final_pos_kj':round(sum(x.final_pos_kj for x in riders),2),'final_mode_seconds':round(sum(x.final_mode_seconds for x in riders),1),'variant':variant,'lane_switches':sum(r.lane_switches for r in riders),'pull_exits':sum(r.pull_exit_count for r in riders),'bank_up_kj':round(sum(r.bank_up_j for r in riders)/1000,2),'bank_down_kj':round(sum(r.bank_down_j for r in riders)/1000,2),'variant':variant,'aero_factor_mean':round(statistics.mean(aerodynamic_samples),3),'finish_group_2s':sum(x.finished_at is not None and winner.finished_at is not None and x.finished_at-winner.finished_at<2 for x in riders),'winning_gap_s':round((finish_order[1].finished_at-winner.finished_at),2) if len(finish_order)>1 and finish_order[1].finished_at is not None and winner.finished_at is not None else -1,'leader500_role':checkpoints.get(500,('',0,0))[0],'leader500_gap_m':checkpoints.get(500,('',0,0))[1],'leader500_group':checkpoints.get(500,('',0,0))[2],'leader200_gap_m':checkpoints.get(200,('',0,0))[1],'leader50_gap_m':checkpoints.get(50,('',0,0))[1],'race_mode':race_mode,'points_winner_id':points_winner.id,'points_winner_role':points_winner.role,'intermediate_sprints':len(sprint_awards),'seed':seed,'riders':count,'laps':laps,'attacks':len(attack_events),
        'unique_attackers':len(set(e['id'] for e in attack_events)),
        'post_sprint_attacks':sum(e['post_sprint'] for e in attack_events),
        'overlap_attacks':overlap_attacks,'multi_attack_laps':sum(v>=2 for v in events_by_lap.values()),
        'no_attack_sprints':no_attack_sprints,'sprint_opportunities':len(post_laps),
        'wheel_follow_pct':round(sum(r.wheel_follow_s for r in riders)/(len(riders)*t),3),'wheel_good_pct':round(sum(r.wheel_good_s for r in riders)/(len(riders)*t),3),'wheel_loss_pct':round(sum(r.wheel_gap_loss_s for r in riders)/(len(riders)*t),3),'wheel_accel_kj':round(sum(r.wheel_accel_j for r in riders)/1000,1),
        'mean_peloton_spread_m':round(statistics.mean(spread_samples),2),
        'mean_main_group_spread_m':round(statistics.mean(pack_spread_samples),2),
        'mean_share_near_wheel':round(statistics.mean(tight_samples),3),
        'mean_drafting_share':round(sum(r.draft_s for r in riders)/(len(riders)*t),3),
        'break_group_episodes':len(break_history),'break_groups_30s':sum(g['duration_s']>=30 for g in break_history),'break_groups_60s':sum(g['duration_s']>=60 for g in break_history),'break_rotations':rotations,'break_refusals':refusals,'mean_completed_pull_s':round(statistics.mean(completed_pulls),2) if completed_pulls else 0.,'total_break_draft_seconds':round(sum(x.break_draft_seconds for x in riders),1),'solo_break_samples':solo_leads,'group_break_samples':group_leads,'mean_break_group_size':round(statistics.mean(break_group_sums),2) if break_group_sums else 0.,'counterattacks':len(counter_events),'total_break_pull_seconds':round(sum(x.break_pull_seconds for x in riders),1),'total_solo_seconds':round(sum(x.solo_seconds for x in riders),1),'pace_kmh':round(statistics.mean(z[0] for z in pace_trace),2) if pace_trace else 0,'pace_below_35_pct':round(100*sum(z[0]<35 for z in pace_trace)/max(1,len(pace_trace)),1),'pace_below_40_pct':round(100*sum(z[0]<40 for z in pace_trace)/max(1,len(pace_trace)),1),'pace_above_47_pct':round(100*sum(z[0]>47 for z in pace_trace)/max(1,len(pace_trace)),1),'pace_std_kmh':round(statistics.pstdev(z[0] for z in pace_trace),2) if len(pace_trace)>1 else 0,'pace_range_kmh':round(max(z[0] for z in pace_trace)-min(z[0] for z in pace_trace),2) if pace_trace else 0,'idle_seconds':round(idle_seconds,1),'idle_pull_offs':idle_pull_offs,'idle_front_power_mean_cp':round(statistics.mean(idle_front_power_samples),3) if idle_front_power_samples else 0.,'soft_pace_events':soft_pace_events,'soft_pace_seconds':round(soft_pace_seconds,1),'soft_pace_last_half_events':sum(x>laps/2 for x in soft_pace_start_lap),'lead_switches':lead_switches,'pull_seconds':round(sum(r.lead_s for r in riders),1),
        'player_ahead_seconds':round(player_ahead_s,1),'player_recatches':caught,
        'player_final_gap_m':round(player_d-statistics.median(r.d for r in riders),2),
        'wheel_requests':sum(r.wheel_requests for r in riders),'wheel_handoffs':sum(r.wheel_handoffs for r in riders),'wheel_refusals':sum(r.wheel_refusals for r in riders),'mean_finish_w_pct':round(statistics.mean(r.store/r.store_max*100 for r in riders),1),'mean_finish_fatigue_pct':round(statistics.mean(r.phys.fatigue*100 for r in riders),1),'elapsed_s':round(t,1),'lap_gains':len(lap_events),'lap_gain_winner':int(winner.lap_credits>0),'lap_gain_events':lap_events,'finish_winner_id':winner.id,'finish_winner_role':winner.role,'overall_finish_winner_role':('player' if player_finished_at is not None and (winner.finished_at is None or player_finished_at<winner.finished_at) else winner.role),'unique_dropped':len(any_dropped_ids),'drop_events':len(dropout_events),'attacker_dropped':sum(r.role=='attacker' and r.dropped_events>0 for r in riders),'dropped_after_attack':sum(e['recently_attacked'] for e in dropout_events),'drop_rider_seconds':round(sum(r.dropped_s for r in riders),1),'short_attacks':sum(e['duration_s']<=30 for e in attack_ends),'countered_attacks':sum(e['reason']=='countered' for e in attack_ends),'long_attacks':sum(e['duration_s']>=45 for e in attack_ends),'mean_attack_duration_s':round(statistics.mean(e['duration_s'] for e in attack_ends),2) if attack_ends else 0},attack_events,dropout_events,rider_positions,attack_ends,detail_trace,break_history,break_snapshots)

def main():
    p=argparse.ArgumentParser();p.add_argument('--mode',choices=['scratch','points'],default='scratch');p.add_argument('--variant',choices=['A','B','C','D','E','F','G','H','I','J','K','L'],default='L');p.add_argument('--races',type=int,default=1000);p.add_argument('--riders',type=int,nargs='+',default=[8,12]);p.add_argument('--laps',type=int,default=25);p.add_argument('--seed',type=int,default=20261021);p.add_argument('--out',default='.');p.add_argument('--legacy-sprinter-wheels',action='store_true',help='Disable economical wheel-following for sprinters; baseline comparison (variant L).');a=p.parse_args()
    import os
    os.makedirs(a.out,exist_ok=True)
    rows=[];events=[];drops=[];positions=[];ends=[]
    for i in range(a.races):
        n=a.riders[i%len(a.riders)]
        row,ev,de,pos,en,*_=run(a.seed+i,n,a.laps,race_mode=a.mode,variant=a.variant,sprinter_wheel_economy=not a.legacy_sprinter_wheels);rows.append(row);events.extend(ev);drops.extend(de);positions.extend(pos);ends.extend(en)
    with open(os.path.join(a.out,'races.csv'),'w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
    if events:
        with open(os.path.join(a.out,'attacks.csv'),'w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=events[0].keys());w.writeheader();w.writerows(events)
    for filename,data in [('dropouts.csv',drops),('rider_results.csv',positions),('attack_outcomes.csv',ends)]:
        if data:
            with open(os.path.join(a.out,filename),'w',newline='') as f:
                w=csv.DictWriter(f,fieldnames=data[0].keys());w.writeheader();w.writerows(data)
    cols=['unique_dropped','drop_events','attacker_dropped','dropped_after_attack','drop_rider_seconds', 'attacks','unique_attackers','post_sprint_attacks','overlap_attacks','multi_attack_laps','mean_peloton_spread_m','mean_main_group_spread_m','mean_share_near_wheel','mean_drafting_share','lead_switches','player_ahead_seconds','player_recatches','short_attacks','countered_attacks','long_attacks','mean_attack_duration_s']
    summary={'simulation':'EXPERIMENTAL Python reference, not Godot','mode':a.mode,'races':len(rows),'total_attacks':len(events),'by_rider_count':{}}
    for n in sorted(set(r['riders'] for r in rows)):
        rr=[r for r in rows if r['riders']==n]
        summary['by_rider_count'][str(n)]={'races':len(rr),'means':{c:round(statistics.mean(r[c] for r in rr),3) for c in cols},'pct_no_attack':round(100*sum(r['attacks']==0 for r in rr)/len(rr),1),'pct_with_simultaneous_attacks':round(100*sum(r['overlap_attacks']>0 for r in rr)/len(rr),1),'pct_post_sprint_attack':round(100*sum(r['post_sprint_attacks'] for r in rr)/max(1,sum(r['attacks'] for r in rr)),1),'pct_post_sprints_without_attack':round(100*sum(r['no_attack_sprints'] for r in rr)/max(1,sum(r['sprint_opportunities'] for r in rr)),1),'profile_attacks':dict(Counter(e['role'] for e in events if e['riders']==n)),'scratch_finish_wins_by_profile':dict(Counter(r['finish_winner_role'] for r in rr)),'overall_finish_wins_by_profile':dict(Counter(r['overall_finish_winner_role'] for r in rr)),'points_wins_by_profile':dict(Counter(r['points_winner_role'] for r in rr)),'unique_points_winners':len(set(r['points_winner_id'] for r in rr)),'unique_scratch_finish_winners':len(set(r['finish_winner_id'] for r in rr)),'pct_races_with_dropped':round(100*sum(r['unique_dropped']>0 for r in rr)/len(rr),1)}
    with open(os.path.join(a.out,'summary.json'),'w') as f:json.dump(summary,f,indent=2)
    print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
