"""12-lane elimination research simulator. Approximation, not Godot parity."""
import math,random,statistics
from elimination_sim import CP,WMAX,PMAX,clamp,road,phys
LANES=12
LANE_WIDTH=.60
MIN_GAP=2.0
DT=.2

def draft_strength(r, riders, active):
    """Only riders ahead, with lateral overlap, can provide aerodynamic shelter."""
    best=0.
    for j in active:
        if j==r['id']: continue
        other=riders[j]
        longitudinal=other['d']-r['d']
        if not (0.5<longitudinal<12):continue
        lateral=abs(other['lane']-r['lane'])*LANE_WIDTH
        lateral_factor=clamp((1.35-lateral)/1.35,0,1)
        best=max(best,clamp((12-longitudinal)/10,0,1)*lateral_factor)
    return best

def choose_lanes(rs,active,clock,head,line):
    """Discrete tactical lane reservation, with a collision-free target corridor."""
    ordered=sorted(active,key=lambda i:rs[i]['d'],reverse=True)
    targets={}
    for rank,i in enumerate(ordered):
        r=rs[i]; cur=r['lane']; desired=cur
        nearest=None
        for j in active:
            if i==j:continue
            gap=rs[j]['d']-r['d']
            if 0<gap<8 and abs(rs[j]['lane']-cur)<=1:
                if nearest is None or gap<nearest[0]:nearest=(gap,j)
        if nearest and nearest[0]<5 and r['v']>rs[nearest[1]]['v']-.3:
            # Prefer the closest free side corridor when overtaking.
            options=[x for x in (cur-1,cur+1) if 0<=x<LANES]
            options.sort(key=lambda x:(abs(x-cur),x))
            for candidate in options:
                if corridor_clear(i,candidate,rs,active,targets):
                    desired=candidate;break
        elif cur>0 and corridor_clear(i,cur-1,rs,active,targets):
            desired=cur-1
        targets[i]=desired
    return targets

def corridor_clear(i,candidate,rs,active,targets):
    r=rs[i]
    for j in active:
        if j==i:continue
        other=rs[j]; other_lane=targets.get(j,other['lane'])
        if abs(candidate-other_lane)>0 or abs(r['d']-other['d'])>=MIN_GAP+1.2:continue
        return False
    return True

def resolve_collisions(rs,active,old):
    """No overlapping bodies in a lane, including riders overtaking during a tick."""
    by_lane={lane:[] for lane in range(LANES)}
    for i in active:by_lane[rs[i]['lane']].append(i)
    blocked=0
    for ids in by_lane.values():
        ids.sort(key=lambda i:(rs[i]['d'],old[i],-i),reverse=True)
        for lead,follow in zip(ids,ids[1:]):
            limit=rs[lead]['d']-MIN_GAP
            if rs[follow]['d']>limit:
                rs[follow]['d']=limit
                rs[follow]['v']=min(rs[follow]['v'],rs[lead]['v'])
                blocked+=1
    return blocked

def run(seed=17,n=16,difficulty=80,policy='improved',dt=DT,player_watts=0):
    rng=random.Random(seed);rs=[]
    for i in range(n):
        k=i%3;f=rng.uniform(.94,1.06)
        rs.append(dict(id=i,kind=k,cp=CP[k]*f,wmax=WMAX[k]*f,pmax=PMAX[k]*f,w=WMAX[k]*f,fatigue=0.,d=-(i//LANES)*MIN_GAP,v=0.,power=0.,lane=i%LANES,last_lane_change=-10.))
    active=list(range(n));line=500.;clock=0.;elims=[];samples=[];blocked=0;lane_changes=0
    final_distance=(n-1)*500.
    while clock<2400:
        active.sort(key=lambda i:rs[i]['d'],reverse=True)
        if len(active)==2 and min(rs[i]['d'] for i in active)>=final_distance:break
        head=rs[active[0]]['d'];middle=rs[active[len(active)//2]]['d'];final=len(active)==2
        old={i:rs[i]['d'] for i in active}
        targets=choose_lanes(rs,active,clock,head,line)
        # One lane per decision, and only if the destination is free.
        for i in active:
            if (targets[i]!=rs[i]['lane'] and clock-rs[i]['last_lane_change']>=2.0
                    and corridor_clear(i,targets[i],rs,active,{})):
                rs[i]['lane']=targets[i];rs[i]['last_lane_change']=clock;lane_changes+=1
        drafts={i:draft_strength(rs[i],rs,active) for i in active}
        powers={}
        for rank,i in enumerate(active):
            r=rs[i];aero=max(.31,1-.69*drafts[i]);sheltered=drafts[i]>.12
            ahead=[(rs[j]['d']-r['d'],j) for j in active if j!=i and 0<rs[j]['d']-r['d']<70 and abs(rs[j]['lane']-r['lane'])<=2]
            gap,j=min(ahead,default=(70.,-1))
            target=r['cp']*(.76 if sheltered else .92)
            if j>=0:
                wanted=max(0,rs[j]['v']+clamp((gap-3.2)*.28,-1,1.2))
                target=clamp(road(wanted,aero)/.975,0,r['cp']+min(130,r['w']/22))
            if policy=='baseline':
                danger=min(3,max(1,len(active)//4));risk=clamp(((rank+1)-(len(active)-danger))/danger,0,1)
                jury_remaining=max(0,line-head);remaining=max(0,line-r['d'])
                positioning=not final and risk>0 and remaining>0 and jury_remaining<110
                if not final and not positioning and clock>=14 and r['d']-middle>8:
                    target=min(target,road(max(5,rs[active[len(active)//2]]['v']-1),aero)/.975)
                if positioning:
                    urgency=clamp((110-jury_remaining)/85,0,1)*risk
                    seconds=max(6,remaining/max(r['v'],7));kick=r['cp']+r['w']/(seconds+r['w']/max(1,r['pmax']-r['cp']))
                    target=max(target,target+(kick*.99-target)*urgency)
            else:
                if not final:
                    remaining=max(0,line-head);danger=min(4,max(2,len(active)//3))
                    risk=clamp((rank-(len(active)-danger-2))/max(1,danger),0,1)
                    floor_speed=11.8 if remaining>200 else 12.3
                    if clock>14:
                        floor_power=(road(floor_speed,aero)+80*max(r['v'],1)*clamp((floor_speed-r['v'])*.38,-1.5,1.5))/.975
                        target=max(target,min(floor_power,r['cp']+min(160,r['w']/25)))
                    if remaining<260 and risk>0:
                        urgency=clamp((260-remaining)/200,0,1)*risk
                        kick=r['cp']+r['w']/(max(6,(line-r['d'])/max(r['v'],7))+r['w']/max(1,r['pmax']-r['cp']))
                        target=max(target,target+(kick*.85-target)*urgency)
                else:
                    remaining=max(0,final_distance-r['d']);urgency=clamp((220-remaining)/170,0,1)
                    kick=r['cp']+r['w']/(max(6,remaining/max(r['v'],7))+r['w']/max(1,r['pmax']-r['cp']))
                    target=max(target,target+(kick*.98-target)*urgency)
            if clock<14 and r['v']<11 and r['d']<170:
                wt=clamp((14-clock)/7,0,1)*clamp((11-r['v'])/3,0,1)
                target=max(target,(1-wt)*r['cp']*(.76 if sheltered else .91)+wt*min(450,max(350,r['cp']*1.65)))
            powers[i]=player_watts if player_watts>0 and i==0 else phys(r,target*difficulty/80,dt)
        for i in active:
            r=rs[i];v=r['v'];aero=max(.31,1-.69*drafts[i]);drive=powers[i]*.975/max(v,2.5)
            r['v']=max(0,v+(drive-.5*1.2*.334*v*v*aero-.004*80*9.81)/80*dt)
            r['d']+=r['v']*dt;r['power']=powers[i]
        blocked+=resolve_collisions(rs,active,old)
        clock+=dt
        if int((clock-dt)*2)!=int(clock*2):
            samples.append((clock,statistics.mean(rs[i]['v']*3.6 for i in active),len(active),max(rs[i]['d'] for i in active)-min(rs[i]['d'] for i in active),statistics.mean(drafts.values())))
        if not final and min(rs[i]['d'] for i in active)>=line:
            crossings=sorted(active,key=lambda i:(clock-dt+dt*clamp((line-old[i])/max(rs[i]['d']-old[i],1e-9),0,1),i))
            loser=crossings[-1];elims.append((line,loser,clock));active.remove(loser);line+=500
    pre=[s for s in samples if s[2]>2];last=[s for s in samples if s[2]==2]
    return dict(seed=seed,finished=len(elims)==n-2 and len(last)>0,elapsed=round(clock,1),eliminations=len(elims),elimination_kmh=round(statistics.mean(s[1] for s in pre),2) if pre else 0,final_kmh=round(statistics.mean(s[1] for s in last),2) if last else 0,span_m=round(statistics.mean(s[3] for s in pre),2) if pre else 0,draft=round(statistics.mean(s[4] for s in pre),3) if pre else 0,blocked=blocked,lane_changes=lane_changes,lanes_used=len({r['lane'] for r in rs}),min_wprime=min(r['w'] for r in rs),max_lane=max(r['lane'] for r in rs),min_lane=min(r['lane'] for r in rs))
