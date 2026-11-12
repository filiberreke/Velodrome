from experiments import *
names=['traffic_feedback','traffic_feedback_metric','traffic_pass_feedback_metric',
       'traffic_pass_feedback_metric_safe_corridor','traffic_feedback_metric_safe_corridor',
       'traffic_pass_feedback_metric_safe_corridor_no_upstream','traffic_feedback_metric_align',
       'traffic_pass_feedback_metric_safe_corridor_reach','traffic_feedback_metric_clock']
rows=[]
for name in names:
    fn=load(name)
    for seed in range(17,29):
        r=fn(seed);r['variant']=name;rows.append(r)
    print(name,{k:round(statistics.mean(r[k] for r in rows[-12:]),3) for k in ('span_m','draft','anticipations','blocked','elimination_kmh','mean_wprime_after_eliminations')},flush=True)
with (ROOT/'results/feedback_exploration.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
