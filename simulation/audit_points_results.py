"""Check every saved batch race independently of summary generation."""
import json
import sys
from pathlib import Path


def audit(path):
    races=json.loads(Path(path).read_text(encoding='utf-8'))
    assert len({r['seed'] for r in races})==len(races)
    for r in races:
        ids={x['id'] for x in r['riders']}
        assert len(ids)==16 and r['laps']==40 and r['field']==16
        assert [s['lap'] for s in r['sprints']]==[10,20,30,40]
        assert {e['id'] for e in r['energy35']}==ids
        assert len({e['time_s'] for e in r['energy35']})==1
        assert all(0<=e['w_pct']<=100 for e in r['energy35'])
        totals=dict.fromkeys(ids,0)
        net=dict.fromkeys(ids,0)
        for e in r['lap_events']:
            assert e['delta'] in (-1,1) and e['points']==20*e['delta']
            assert e['time_s']<=r['finish_time_s']
            totals[e['id']]+=e['points']
            net[e['id']]+=e['delta']
        for s in r['sprints']:
            assert len(s['order'])==16 and set(s['order'])==ids
            assert s['crossing_times']==sorted(s['crossing_times'])
            rewards=[10,6,4,2] if s['lap']==40 else [5,3,2,1]
            assert s['awards']==rewards+[0]*12
            for ident,award in zip(s['order'],s['awards']):
                totals[ident]+=award
        assert totals=={x['id']:x['points'] for x in r['riders']}
        assert net=={x['id']:x['net_laps'] for x in r['riders']}
        assert r['standings']==[x['id'] for x in sorted(r['riders'],key=lambda x:(-x['points'],x['final_place']))]
    print(f'PASS: {len(races)} races; {len(races)*16} rider and energy records; {len(races)*4} sprints')


if __name__=='__main__':
    audit(sys.argv[1] if len(sys.argv)>1 else 'results_points_100/races.json')
