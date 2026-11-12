"""Build a readable simulator with separate frame, control and physics clocks."""
import shutil,difflib
from experiments import ROOT,source,BASE

HEADER='''"""Elimination research simulator v2: natural pace, no minimum-speed rule.
Standard-library only; not Godot parity.

dt is the caller/frame interval; integration_dt is the numerical physics step.
Changing frame size does not change authoritative physics/control ticks.
"""
import math,random,statistics
from lane_sim import CP,WMAX,PMAX,clamp,road,phys,LANES,LANE_WIDTH,MIN_GAP,DT,draft_strength,resolve_collisions

def lane_metric(lane):
    return 1.+math.pi*lane*LANE_WIDTH/250.

def swept_laterally_clear(cur,candidate,other,other_target):
    start=cur-other;end=candidate-other_target
    return start*end>0 and min(abs(start),abs(end))>=1

def can_leave_corridor(gap,relative_progress_speed,duration=.2):
    # Departing an already safe wheel does not require the NEW-merge buffer.
    # Preserve the physical following gap until the paths separate.
    future=gap+relative_progress_speed*duration
    return gap*future>0 and min(abs(gap),abs(future))>=MIN_GAP

def power_to_speed(v,desired,aero,tau=1.25):
    acceleration=clamp((desired-v)/tau,-1.5,1.5)
    return (road(v,aero)+80*max(v,2.5)*acceleration)/.975

def cycle_urgency(head):
    # Reserve a route in the final 50m before the bell; full positional urgency
    # by 200m to the cut. This controls effort, never a minimum speed.
    return clamp((head%500.-200.)/100.,0.,1.)

def feasible_power(request,v,aero,safe_v,dt):
    # Invert the same explicit force equation used by the physics integrator.
    resistance=.5*1.2*.334*v*v*aero+.004*80*9.81
    ceiling=max(0,(resistance+80*(safe_v-v)/dt)*max(v,2.5)/.975)
    return min(request,ceiling)

'''

WRAPPER='''

def simulate(seed=17,n=16,difficulty=80,dt=.2,integration_dt=.05,decision_dt=.2,observe=None):
    """Run through fixed physics ticks, accumulated independently of frame dt.

    observe receives every integration tick. All durations are represented as
    integer nanoseconds in the scheduler. Refinement studies vary integration_dt,
    not the frame interval dt. Control and sampling cadences remain fixed.
    """
    for name,value in (('dt',dt),('integration_dt',integration_dt),('decision_dt',decision_dt)):
        if not math.isfinite(value) or value<=0:raise ValueError(name+' must be finite and positive')
    if n<3 or difficulty<=0:raise ValueError('n>=3 and difficulty>0 required')
    frame_ns=round(dt*1_000_000_000);step_ns=round(integration_dt*1_000_000_000)
    control_ns=round(decision_dt*1_000_000_000)
    if min(frame_ns,step_ns,control_ns)<=0:raise ValueError('duration below scheduler resolution')
    if control_ns%step_ns or 500_000_000%step_ns:
        raise ValueError('integration_dt must divide decision_dt and 0.5 seconds')
    if step_ns>control_ns:raise ValueError('physics step exceeds decision interval')
    h=step_ns/1_000_000_000
    core=_run(seed,n,difficulty,h,control_ns//step_ns,500_000_000//step_ns,observe)
    accumulator=0
    while True:
        accumulator+=frame_ns
        while accumulator>=step_ns:
            try:next(core)
            except StopIteration as done:return done.value
            accumulator-=step_ns
'''

CLI='''

if __name__=='__main__':
    import argparse,json,csv
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--seed',type=int,default=17)
    ap.add_argument('--dt',type=float,default=.2,help='external frame interval')
    ap.add_argument('--integration-dt',type=float,default=.05,help='internal physics step')
    ap.add_argument('--lap-csv',help='write time-weighted field speeds per lap')
    args=ap.parse_args()
    recorder=None
    if args.lap_csv:
        from metrics import Recorder
        recorder=Recorder()
    result=simulate(seed=args.seed,dt=args.dt,integration_dt=args.integration_dt,observe=recorder)
    if recorder is not None:
        recorder.finish()
        with open(args.lap_csv,'w',newline='',encoding='utf-8') as f:
            w=csv.DictWriter(f,fieldnames=list(recorder.laps[0]));w.writeheader();w.writerows(recorder.laps)
    print(json.dumps(result,indent=2))
'''

def main():
    s=source('traffic_feedback_metric_swept_prediction_metric_cycle')
    s=s[s.index('def simulate('):]
    s=s.replace('def simulate(seed=17,n=16,difficulty=80,dt=DT):',
                'def _run(seed,n,difficulty,dt,control_stride,sample_stride,observe):')
    s=s.replace('    while clock<2400:', '    tick=0;requests={};last_info={}\n    while clock<2400:')
    s=s.replace('clamp((250.-(500.-head%500.))/190.,0.,1.)', 'cycle_urgency(head)')
    s=s.replace("        old={i:rs[i]['d'] for i in active}",
                "        old={i:rs[i]['d'] for i in active}\n        before={i:dict(rs[i]) for i in active}")
    # Freeze tactical choices on a control clock independent of frame/physics dt.
    start=s.index('        targets={}; ordered=active[:]')
    end=s.index('        # Project unconstrained',start)
    block=s[start:end]
    block=block.replace('        drafts={i:draft_strength(rs[i],rs,active) for i in active};powers={};requests={}',
                        '        drafts={i:draft_strength(rs[i],rs,active) for i in active};powers={};requests={};last_info={}')
    block=block.replace('            requests[i]=target*difficulty/80',
                        "            requests[i]=target*difficulty/80\n            last_info[i]=dict(wheel=wheel,wheel_gap=gap,desired_speed=desired_speed if wheel>=0 else None,urgency=urgency)")
    block=block.replace("if (cur-o['lane'])*(candidate-other)>0 and min(abs(cur-o['lane']),abs(candidate-other))>=1:continue",
                        "if swept_laterally_clear(cur,candidate,o['lane'],other):continue")
    block=block.replace("(road(r['v'],aero)+80*max(r['v'],2.5)*clamp((desired_speed-r['v'])*.8,-1.5,1.5))/.975", "power_to_speed(r['v'],desired_speed,aero)")
    block=block.replace("w['v']+.35", "w['v']*lane_metric(r['lane'])/lane_metric(w['lane'])+.35")
    # No absolute pace anchor. Existing wheel-following/closing power and the
    # CP/W-prime positional kick remain; a detached rider receives no free speed.
    start_floor=block.index('            # Existing improved race-speed anchor')
    end_floor=block.index('            if not final and urgency>.0:',start_floor)
    block=block[:start_floor]+block[end_floor:]
    dead_start=block.index("            elif rank==0 and rs[0]['d']")
    dead_end=block.index('            if not final and urgency>.0:',dead_start)
    block=block[:dead_start]+block[dead_end:]
    block=block.replace('                        if gap*future<=0 or min(abs(gap),abs(future))<3.6:',
                        "                        if cur==o['lane'] and candidate!=other and can_leave_corridor(gap,(future-gap)/1.8,control_stride*dt):\n                            continue\n                        if gap*future<=0 or min(abs(gap),abs(future))<3.6:")
    s=s[:start]+'        if tick%control_stride==0:\n'+''.join('    '+line+'\n' for line in block.splitlines())+s[end:]
    s=s.replace('Preserve wheel-following, launch and speed-floor power requests;', 'Preserve wheel-following, launch and positional power requests;')
    s=s.replace('        predicted={}; proposed={}',
                "        drafts={i:draft_strength(rs[i],rs,active) for i in active}\n        powers={};info={}\n        predicted={}; proposed={}")
    s=s.replace("            leader=lane_leaders.get(r['lane'])", "            leader=lane_leaders.get(r['lane'])\n            request=requests[i]\n            info[i]=dict(last_info[i],raw_request=request,safety_leader=-1 if leader is None else leader,traffic_limited=False)")
    s=s.replace("                drag=.5*1.2*.334*v*v*aero+.004*80*9.81\n                safe_power=max(0,(drag+80*(safe_v-v)/dt)*max(v,2.5)/.975)\n                requests[i]=min(requests[i],safe_power)",
                "                request=feasible_power(request,v,aero,safe_v,dt)\n                info[i]['traffic_limited']=request<requests[i]-1e-7")
    s=s.replace('            powers[i]=phys(r,requests[i],dt)',
                "            info[i]['feasible_request']=request\n            powers[i]=phys(r,request,dt)")
    s=s.replace("            proposed[i]=r['d']+predicted[i]*dt/metric", "            proposed[i]=r['d']+predicted[i]*dt/metric\n            info[i].update(raw_v=predicted[i],metric=metric,cap=False)")
    s=s.replace('                    anticipations+=1', "                    anticipations+=1\n                    info[follow]['cap']=True")
    s=s.replace('        clock+=dt',
                '        if observe is not None:observe(seed,clock,dt,rs,active,before,info,drafts,powers,final,line)\n        tick+=1;clock=tick*dt')
    s=s.replace('        if int((clock-dt)*2)!=int(clock*2):', '        if tick%sample_stride==0:')
    # Advance the generator after all events of the tick are committed.
    s=s.replace('    pre=[s for s in samples', '        yield None\n    pre=[s for s in samples')
    (ROOT/'source/elimination_v2.py').write_text(HEADER+s+WRAPPER+CLI,encoding='utf-8')
    for name in ('lane_sim.py','elimination_sim.py'):shutil.copyfile(ROOT/'baseline'/name,ROOT/'source'/name)
    (ROOT/'source/changes.patch').write_text(''.join(difflib.unified_diff(BASE.splitlines(True),(HEADER+s+WRAPPER+CLI).splitlines(True),fromfile='baseline/predictive_fixed.py',tofile='source/elimination_v2.py')),encoding='utf-8')
    print('Built readable v2')

if __name__=='__main__':main()
