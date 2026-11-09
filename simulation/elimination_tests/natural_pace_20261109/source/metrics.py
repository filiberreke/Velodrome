"""Time-weighted field speed, interpolated lap crossings and safety diagnostics."""
import csv,gzip,math,statistics,hashlib,json,struct
from collections import Counter

class Recorder:
    def __init__(self,n=16,trace_path=None):
        self.n=n;self.lap=1;self.lap_start=0.;self.integral=0.;self.ai_integral=0.;self.duration=0.
        self.laps=[];self.rider_laps=[];self.previous_cross={i:0. for i in range(n)}
        self.counts=Counter();self.max_span=0.;self.max_ai_span=0.;self.events=[]
        self.last_sample=-1;self.sums=Counter();self.hash=hashlib.sha256()
        self.file=gzip.open(trace_path,'wt',newline='',encoding='utf-8') if trace_path else None
        self.writer=None

    def __call__(self,seed,t,h,rs,active,before,info,drafts,powers,final,line):
        self.hash.update(struct.pack('<I',len(active)))
        for i in active:
            r=rs[i];self.hash.update(struct.pack('<idddi',i,r['d'],r['v'],r['w'],r['lane']))
        mean0=statistics.mean(before[i]['v']*3.6 for i in active)
        mean1=statistics.mean(rs[i]['v']*3.6 for i in active)
        ai=[i for i in active if i!=0]
        amean0=statistics.mean(before[i]['v']*3.6 for i in ai) if ai else mean0
        amean1=statistics.mean(rs[i]['v']*3.6 for i in ai) if ai else mean1
        fractions=[]
        for i in active:
            d0=before[i]['d'];d1=rs[i]['d']
            for lap in range(max(1,int(d0//250)+1),int(d1//250)+1):
                if lap>2*(self.n-1):continue
                f=(lap*250-d0)/(d1-d0);cross=t+h*f;duration=cross-self.previous_cross[i]
                self.rider_laps.append(dict(seed=seed,rider=i,lap=lap,type=self.lap_type(lap),crossing_s=cross,duration_s=duration,reference_kmh=900/duration))
                self.previous_cross[i]=cross
                if lap==self.lap:fractions.append((f,lap))
        end=min(f for f,lap in fractions) if fractions else 1.
        if self.lap<=2*(self.n-1):
            self.add_integral(h,0.,end,mean0,mean1,amean0,amean1)
            if fractions:
                crossing=t+h*end
                self.laps.append(dict(seed=seed,lap=self.lap,type=self.lap_type(self.lap),start_s=self.lap_start,end_s=crossing,duration_s=crossing-self.lap_start,
                    field_mean_kmh=self.integral/self.duration,ai_mean_kmh=self.ai_integral/self.duration,leader_reference_kmh=900/(crossing-self.lap_start)))
                self.lap+=1;self.lap_start=crossing;self.integral=0.;self.ai_integral=0.;self.duration=0.
                if self.lap<=2*(self.n-1):self.add_integral(h,end,1.,mean0,mean1,amean0,amean1)
        span=max(rs[i]['d'] for i in active)-min(rs[i]['d'] for i in active)
        ai_span=max(rs[i]['d'] for i in ai)-min(rs[i]['d'] for i in ai) if ai else 0.
        if not final:
            self.max_span=max(self.max_span,span);self.max_ai_span=max(self.max_ai_span,ai_span)
            self.sums['duration']+=h;self.sums['span_time']+=span*h;self.sums['ai_span_time']+=ai_span*h
            if span>100 and (not self.events or t-self.events[-1]['time_s']>=10):
                tail=min(active,key=lambda i:rs[i]['d']);self.events.append(dict(time_s=t,span_m=span,tail=tail,tail_lane=rs[tail]['lane'],tail_wprime=rs[tail]['w'],tail_power=powers[tail],ai_span_m=ai_span))
        log_this=int((t+1e-8)*5)!=self.last_sample
        if log_this:self.last_sample=int((t+1e-8)*5)
        for i in active:
            r=rs[i];x=info[i];leader=x['safety_leader'];wheel=x['wheel']
            self.counts['rider_ticks']+=1
            self.counts['speed_caps']+=x['cap'];self.counts['traffic_power_limited']+=x.get('traffic_limited',False)
            self.counts['wprime_empty']+=r['w']<1e-7
            assert r['w']>=-1e-7 and r['w']<=r['wmax']+1e-7
            assert r['d']>=before[i]['d']-1e-7
            if leader>=0:
                assert rs[leader]['d']-r['d']>=2-1e-7
                if x['cap']:
                    assert rs[leader]['d']-r['d']<=before[leader]['d']-before[i]['d']+1e-7
            if self.file and log_this:
                row=dict(seed=seed,time_s=t,rider=i,lane=r['lane'],d_before=before[i]['d'],d_after=r['d'],v_before=before[i]['v'],v_after=r['v'],
                    wheel=wheel,wheel_gap=before[wheel]['d']-before[i]['d'] if wheel in before else '',safety_leader=leader,
                    safety_gap=before[leader]['d']-before[i]['d'] if leader>=0 else '',draft=drafts[i],raw_power=x.get('raw_request',powers[i]),
                    feasible_power=x.get('feasible_request',powers[i]),actual_power=powers[i],wprime=r['w'],traffic_limited=x.get('traffic_limited',False),speed_cap=x['cap'])
                if self.writer is None:self.writer=csv.DictWriter(self.file,fieldnames=list(row));self.writer.writeheader()
                self.writer.writerow(row)

    def add_integral(self,h,a,b,m0,m1,am0,am1):
        self.integral+=h*((b-a)*m0+(b*b-a*a)*(m1-m0)/2)
        self.ai_integral+=h*((b-a)*am0+(b*b-a*a)*(am1-am0)/2)
        self.duration+=h*(b-a)

    def lap_type(self,lap):
        if lap>2*(self.n-2):return 'finale'
        return 'tussenronde' if lap%2 else 'afvallingsronde'

    def finish(self):
        if self.file:self.file.close()
        return dict(counts=dict(self.counts),max_span_m=self.max_span,max_ai_span_m=self.max_ai_span,
                    mean_ai_span_m=self.sums['ai_span_time']/self.sums['duration'],mean_span_m=self.sums['span_time']/self.sums['duration'],
                    state_hash=self.hash.hexdigest(),large_gap_events=self.events)
