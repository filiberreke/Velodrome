"""Points-only adaptation of sim_f.run at 94095e9 (variant L).
Derived loop: scratch source stays untouched. Shared Rider, Phys, road load,
0.25 s integration, lanes, bank costs and wheel economy are imported directly.
Changes: AI-only field, leader clock, separate jury, all-profile sprint demand,
circular lane proximity and shared finish. No old scoring/finish proxy is used.
"""
import math, random, statistics
from collections import Counter
from sim_f import (Rider, DT, LAP, LANES, WHEEL_OFFSET, MIN_WHEEL_CLEARANCE,
                   clamp, pcurve, road_power, integrate_speed, draft_speed_factor,
                   DRIVETRAIN_EFF, bank_height, lane_distance_multiplier)
from tempo_jury import Jury

def run(seed=1, count=16, laps=40):
    variant="L"; race_mode="points"; player_w=0
    sprint_switch=False; final750=False; no_speed_cap=True
    breakaway_v=True; chase_scale=1.; break_follow=True
    real_laps=True; sprinter_wheel_economy=True; lap_probe=None
    rng=random.Random(seed)
    lap_events=[]
    assert race_mode in ("scratch","points")
    assert variant in ("A","B","C","D","E","F","G","H","I","J","K","L")
    riders=[Rider(i,('tt','sprinter','attacker')[(i-1)%3],rng) for i in range(1,count+1)]
    player_d=-1e12; player_v=0.; player_finished_at=None; t=0.; n_steps=0
    attack_events=[]; overlap_attacks=0; no_attack_sprints=0;attack_ends=[]
    break_events=[]; counter_events=[]; break_age_samples=[]; break_group_sums=[]; solo_leads=0; group_leads=0; turn_states={}; rotations=0; refusals=0; completed_pulls=[]; next_group_id=0; break_history=[]; break_snapshots=[]
    spread_samples=[]; pack_spread_samples=[]; tight_samples=[]; draft_samples=[];gap_samples=[]; player_ahead_s=0.;caught=0; had_ahead=False
    leaders=[]; recent_attacks=[]; laps_checked=set(); attack_per_window=Counter(); prev_player_ahead=False
    last_sprint_index=-1; sprint_events=[]
    dropout_events=[]; sample_count=0; dropped_samples=0; any_dropped_ids=set(); rider_positions=[]; finish_line=laps*LAP
    jury=Jury(riders, laps)
    points_score=jury.points
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
        before={r.id:(r.d,r.store,r.phys.fatigue) for r in riders}
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
        race_lap=int(max(0,lead)//LAP)
        post_sprint=jury.last_sprint_time is not None and t-jury.last_sprint_time<16
        next_lap=jury.next_sprint_lap
        pre_sprint=next_lap is not None and 0<next_lap*LAP-lead<250
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
                    duration=(rng.uniform(24,42) if chosen.role=='attacker' else rng.uniform(35,65) if chosen.role=='tt' else rng.uniform(8,14))
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
            candidates=[x for x in main_cluster if x.store/x.store_max>(.22 if x.role=='sprinter' else .38) and x.cooperation>.38 and x.mode=='draft' and (x.role=='sprinter' or rng.random()<.35)]
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
            if r.finished_at is not None:
                desired.append((0., 1.))
                continue
            # Circular track: a rider almost one lap in front may be physically
            # behind the bunch, even though unwrapped progress is greater.
            def physical_ahead_gap(s):
                if s.finished_at is not None:
                    return float('inf')
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
                    nearest=min(front,key=physical_ahead_gap)
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
                base={'attacker':.043,'tt':.023,'sprinter':.00015}[r.role]
                post_boost=1.0  # Tempo: no special post-sprint attack window
                mode_mult=1.35 if race_mode=='points' else .66
                # Laggards are more willing to gamble for sprint points.
                score_need=1.25 if race_mode=='points' and points_score[r.id]<max(points_score.values(),default=0) else 1.
                pre_penalty=1.0  # Every scoring lap is a normal race lap
                busy_penalty=(.85 if r.role=='attacker' else .22) if active_attackers else (.8 if recent else 1.)
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
            needs_chase=(lead-mid)>13
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
                target=r.aero*((1.09 if r.role=='tt' else 1.015)+(.035 if r.role=='tt' else .045)*urgency)
            elif r.mode=='break_pull':
                # Stronger than sustainable solo, but bounded by W' and fatigue.
                # Shorter sprinter pulls compensate for their higher relative cost.
                target=r.aero*({'tt':1.23,'attacker':1.14,'sprinter':1.08}[r.role] if breakaway_v else {'tt':1.20,'attacker':1.12,'sprinter':1.06}[r.role])
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
            elif pre_sprint and r.role=='sprinter' and energy_ratio>.52 and lead-r.d<8:
                target=r.aero+.19*(r.peak-r.aero)
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
                                return sum(1 for x in riders if x is not r and abs((x.d-r.d+LAP/2)%LAP-LAP/2)<1.45 and abs(x.lane-z)<.85)
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
            target=jury.sprint_demand(r, target, lead)
            power=r.step_power(target,DT)
            # Wheel shelter lets same speed at lower actual power; no artificial group speed bonus.
            # Dynamical target speed with inertia.
            v_target=11.0*((power/300./(.82 if draft else 1.))**(1/3)) if variant=='A' else 11.0*((max(power-33,1)/(267*aero_factor))**(1/3))
            desired.append((power,aero_factor) if no_speed_cap else clamp(v_target,5.5,16.))
        for r,tar in zip(riders,desired):
            if r.finished_at is not None: continue
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
                    return sum(1 for x in riders if x is not r and abs((x.d-r.d+LAP/2)%LAP-LAP/2)<1.45 and abs(x.lane-z)<.85)
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
        jury.observe(t, DT, before, riders)
        if jury.done:
            break
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
        t+=DT
        if len(recent_attacks)>100:recent_attacks=[a for a in recent_attacks if t-a<45]
    return jury.result(seed, riders, attack_events)
