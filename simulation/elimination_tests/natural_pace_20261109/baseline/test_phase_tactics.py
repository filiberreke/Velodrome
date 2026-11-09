"""Phase-aware 12-lane elimination tactics; approximate Python research model.
Compare to existing chain-follow model with the same seeded field and attack.
"""
import argparse,csv,statistics,random,math
from pathlib import Path
from lane_sim import CP,WMAX,PMAX,clamp,road,phys,LANES,LANE_WIDTH,MIN_GAP,DT,draft_strength,resolve_collisions
from test_chain_follow import simulate as chain_sim

def simulate(seed=17,n=16,difficulty=80,dt=DT):
    rng=random.Random(seed);rs=[]
    for i in range(n):
        k=i%3;f=rng.uniform(.94,1.06)
        rs.append(dict(id=i,kind=k,cp=CP[k]*f,wmax=WMAX[k]*f,pmax=PMAX[k]*f,w=WMAX[k]*f,fatigue=0.,d=-(i//LANES)*MIN_GAP,v=0.,power=0.,lane=i%LANES,last_lane_change=-10.,wheel=-1,outside_since=0.,pull_until=0.))
    active=list(range(n));line=500.;clock=0.;elims=[];samples=[];blocked=0;lane_changes=0
    final_distance=(n-1)*500.;peak_gap=0.;outside_seconds=0.;gap5=gap10=gap20=0; head_changes=0;previous_head=None
    wprime_at_lines=[];inner_decisions=0;advance_decisions=0;wheel_switches=0
    while clock<2400:
        active.sort(key=lambda i:rs[i]['d'],reverse=True)
        if len(active)==2 and min(rs[i]['d'] for i in active)>=final_distance:break
        head=rs[active[0]]['d'];final=len(active)==2;remaining=max(0,line-head)
        # First lap after elimination: energy/inner lanes. Second lap: position priority.
        urgency=clamp((250.-remaining)/190.,0.,1.) if not final else clamp((220.-max(0,final_distance-head))/170,0,1)
        old={i:rs[i]['d'] for i in active}
        targets={}; ordered=active[:]
        for rank,i in enumerate(ordered):
            r=rs[i];cur=r['lane'];desired=cur
            if clock-r['last_lane_change']>=2.0:
                # Move inward preferentially after the elimination, even if rank slips.
                if cur>0 and (remaining>220 or cur>=5):
                    desired=cur-1;inner_decisions+=1
                # Late cycle: pass when at risk, not everyone at once.
                elif not final and urgency>.35 and rank>=len(active)-max(3,len(active)//4):
                    desired=min(LANES-1,cur+1);advance_decisions+=1
                # Outer riders blocked by the peloton: finish the pass instead of parking outside.
                elif cur>=4 and remaining<220 and rank>1:
                    desired=max(0,cur-1)
            # Reserve corridor with lookahead, avoiding same-position lateral overlap.
            if desired!=cur:
                safe=True
                for j in active:
                    if j==i:continue
                    o=rs[j];other=targets.get(j,o['lane'])
                    if min(cur,desired)-1>max(o['lane'],other) or max(cur,desired)+1<min(o['lane'],other):continue
                    gap=o['d']-r['d'];future=gap+(o['v']-r['v'])*1.2
                    if min(abs(gap),abs(future))<3.1 or gap*future<0:safe=False;break
                if safe:targets[i]=desired
                else:targets[i]=cur
            else:targets[i]=cur
        for i in active:
            if targets[i]!=rs[i]['lane']:
                rs[i]['lane']=targets[i];rs[i]['last_lane_change']=clock;lane_changes+=1
        drafts={i:draft_strength(rs[i],rs,active) for i in active};powers={}
        for rank,i in enumerate(active):
            r=rs[i];aero=max(.31,1-.69*drafts[i]);sheltered=drafts[i]>.12
            candidates=[]
            for j in active:
                if j==i:continue
                gap=rs[j]['d']-r['d'];lateral=abs(rs[j]['lane']-r['lane'])*LANE_WIDTH
                if 1.8<gap<25 and lateral<1.35:
                    candidates.append((gap+2.5*(j!=r['wheel'])+lateral,gap,j))
            wheel=-1;gap=0
            if candidates:_,gap,wheel=min(candidates)
            if wheel!=r['wheel']:wheel_switches+=1;r['wheel']=wheel
            target=r['cp']*(.76 if sheltered else .92)
            if wheel>=0:
                w=rs[wheel];desired_speed=max(0,w['v']+clamp((gap-3.2)*.24,-.65,1.1))
                target=clamp(road(desired_speed,aero)/.975,0,r['cp']+min(200,r['w']/19))
                # Look past the immediate wheel: close a gap that its leader has let open.
                upstream=[rs[j]['d']-w['d'] for j in active if j!=wheel and rs[j]['d']>w['d']+7 and rs[j]['d']<w['d']+35]
                if upstream and min(upstream)>8 and gap<6 and urgency>.15:
                    desired_speed=max(desired_speed,w['v']+.35)
                    target=max(target,min(road(desired_speed,aero)/.975,r['cp']+min(160,r['w']/22)))
            elif rank==0 and rs[0]['d']>r['d']+3.5 and rs[0]['d']-r['d']<90 and clock>=35:
                target=max(target,min(road(max(rs[0]['v']+.2,11.5),aero)/.975,r['cp']+min(240,r['w']/15)))
            # Existing improved race-speed anchor, but allow energy recovery after elimination.
            floor_speed=(11.5+0.8*urgency) if not final else 11.5
            if clock>14:
                floor_power=(road(floor_speed,aero)+80*max(r['v'],1)*clamp((floor_speed-r['v'])*.38,-1.5,1.5))/.975
                target=max(target,min(floor_power,r['cp']+min(160,r['w']/25)))
            if not final and urgency>.0:
                risk=clamp((rank-(len(active)-max(3,len(active)//3)-2))/max(1,len(active)//3),0,1)
                if risk>0:
                    seconds=max(6,(line-r['d'])/max(r['v'],7));kick=r['cp']+r['w']/(seconds+r['w']/max(1,r['pmax']-r['cp']))
                    target=max(target,target+(kick*.82-target)*urgency*risk)
            if final:
                rem=max(0,final_distance-r['d']);u=clamp((220-rem)/170,0,1)
                kick=r['cp']+r['w']/(max(6,rem/max(r['v'],7))+r['w']/max(1,r['pmax']-r['cp']))
                target=max(target,target+(kick*.98-target)*u)
            # Outside lanes cost real distance per 250m lap; forward work is real watts.
            if r['lane']>=4 and not final and remaining>220:
                target=min(target,r['cp']*1.12) if rank<len(active)-3 else target
            if clock<14 and r['v']<11 and r['d']<170:
                wt=clamp((14-clock)/7,0,1)*clamp((11-r['v'])/3,0,1)
                target=max(target,(1-wt)*r['cp']*(.76 if sheltered else .91)+wt*min(450,max(350,r['cp']*1.65)))
            if i==0 and 35<=clock<60:target=650.
            elif i==0 and clock>=60:target=250.
            powers[i]=phys(r,target*difficulty/80,dt)
        for i in active:
            r=rs[i];v=r['v'];aero=max(.31,1-.69*drafts[i]);drive=powers[i]*.975/max(v,2.5)
            r['v']=max(0,v+(drive-.5*1.2*.334*v*v*aero-.004*80*9.81)/80*dt)
            # Wider lanes require a longer trajectory around the bends (approx. oval metric).
            path_metric=1.+math.pi*(r['lane']*LANE_WIDTH)/(250.)
            r['d']+=r['v']*dt/path_metric;r['power']=powers[i]
            if r['lane']>=4:outside_seconds+=dt
        blocked+=resolve_collisions(rs,active,old)
        clock+=dt
        if previous_head!=active[0]:
            if previous_head is not None:head_changes+=1
            previous_head=active[0]
        if 35<=clock<=100 and len(active)>2:
            peak_gap=max(peak_gap,rs[0]['d']-max(rs[j]['d'] for j in active if j!=0))
        if int((clock-dt)*2)!=int(clock*2):
            sorted_d=sorted((rs[i]['d'] for i in active),reverse=True)
            gaps=[a-b for a,b in zip(sorted_d,sorted_d[1:])]
            gap5+=sum(g>5 for g in gaps);gap10+=sum(g>10 for g in gaps);gap20+=sum(g>20 for g in gaps)
            samples.append((clock,statistics.mean(rs[i]['v']*3.6 for i in active),len(active),max(sorted_d)-min(sorted_d),statistics.mean(drafts.values())))
        if not final and min(rs[i]['d'] for i in active)>=line:
            crossings=sorted(active,key=lambda i:(clock-dt+dt*clamp((line-old[i])/max(rs[i]['d']-old[i],1e-9),0,1),i))
            loser=crossings[-1];elims.append((line,loser,clock));active.remove(loser)
            wprime_at_lines.append(statistics.mean(rs[i]['w']/rs[i]['wmax'] for i in active))
            line+=500
    pre=[s for s in samples if s[2]>2];last=[s for s in samples if s[2]==2]
    return dict(seed=seed,finished=len(elims)==n-2 and bool(last),elapsed=round(clock,1),elimination_kmh=round(statistics.mean(s[1] for s in pre),2) if pre else 0,final_kmh=round(statistics.mean(s[1] for s in last),2) if last else 0,span_m=round(statistics.mean(s[3] for s in pre),2) if pre else 0,draft=round(statistics.mean(s[4] for s in pre),3) if pre else 0,blocked=blocked,lane_changes=lane_changes,peak_gap_m=round(peak_gap,2),outside_rider_seconds=round(outside_seconds,1),head_changes=head_changes,gaps_over_5=gap5,gaps_over_10=gap10,gaps_over_20=gap20,mean_wprime_after_eliminations=round(statistics.mean(wprime_at_lines),3) if wprime_at_lines else 0,wheel_switches=wheel_switches)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--seeds',type=int,default=5);ap.add_argument('--out',default='phase_results');a=ap.parse_args()
    out=Path(a.out);out.mkdir(parents=True,exist_ok=True);rows=[]
    for seed in range(17,17+a.seeds):
        for policy in ('chain','phase'):
            r=chain_sim(seed,'chain') if policy=='chain' else simulate(seed)
            r.pop('probe',None);r['policy']=policy;rows.append(r)
            print('RACE',seed,policy,{k:r.get(k) for k in ('finished','elimination_kmh','span_m','blocked','peak_gap_m','outside_rider_seconds')},flush=True)
    fields=sorted(set().union(*(r.keys() for r in rows)))
    with (out/'races.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
    for policy in ('chain','phase'):
        sub=[r for r in rows if r['policy']==policy]
        print('SUMMARY',policy,{k:round(statistics.mean(r[k] for r in sub),2) for k in ('elimination_kmh','final_kmh','span_m','draft','blocked')},flush=True)
