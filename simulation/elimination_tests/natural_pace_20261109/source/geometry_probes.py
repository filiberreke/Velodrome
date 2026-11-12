from experiments import *
names=['traffic_feedback_metric_safe_corridor', 'traffic_feedback_metric_swept',
       'traffic_feedback_metric_safe_corridor_prediction_metric',
       'traffic_feedback_metric_swept_prediction_metric',
       'traffic_feedback_metric_swept_prediction_metric_cycle',
       'traffic_feedback_metric_safe_corridor_cycle']
rows=[]
for name in names:
    fn=load(name)
    for seed in range(17,29):
        r=fn(seed);r['variant']=name;rows.append(r)
    print(name,{k:round(statistics.mean(r[k] for r in rows[-12:]),3) for k in ('span_m','draft','anticipations','blocked','elimination_kmh','mean_wprime_after_eliminations')},flush=True)
with (ROOT/'results/geometry_exploration.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
