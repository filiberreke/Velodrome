"""Generate deterministic cross-language policy cases from the tested Python policy.
Run from the repository after changing the policy: python game/tests/generate_intermediate_sprint_cases.py
"""
import sys,json,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'simulation'))
from energy_core import PARS
from sim_f import Rider
from intermediate_sprint import Experiment

PARS['tt']=(265.,*PARS['tt'][1:]);PARS['sprinter']=(240.,*PARS['sprinter'][1:])
cases=[]
for name,lap in [('compact_early',10),('hopeless_abort',10),('depleted_middle',20),('late_opportunity',30)]:
    riders=[Rider(i,('tt','sprinter','attacker')[(i-1)%3],random.Random(i)) for i in range(1,17)]
    for r in riders:
        r.d=lap*250-100-r.id*2;r.v=12.
        r.store=r.store_max*(.15 if name=='depleted_middle' else (.45+.02*r.id if name=='late_opportunity' else .95))
    if name=='hopeless_abort':riders[-1].d-=150;riders[-1].v=5.
    policy=Experiment(riders,40,'B')
    policy.sprints=[dict(lap=n,order=list(range(1,17))) for n in (10,20) if n<lap]
    if name=='hopeless_abort':policy.active.add(16)
    if name=='late_opportunity':policy.points={r.id:r.id%7 for r in riders}
    policy.begin_step(riders)
    expected=[]
    for r in riders:
        policy.demand(r,300.,riders,100.)
        expected.append(dict(policy.decisions[-1]))
    # Zero is a finished human placeholder; sixteen active AI indices match IDs.
    case=dict(name=name,lap=lap,leader=policy.head,attempting=[16] if name=='hopeless_abort' else [],
              profiles=[0]+[1 if r.role=='tt' else 2 if r.role=='sprinter' else 3 for r in riders],
              points=[0]+[policy.points[r.id] for r in riders],expected=expected)
    for key,values in dict(distance=[r.d for r in riders],speed=[r.v for r in riders],cp=[r.phys.cp for r in riders],
                           wmax=[r.store_max for r in riders],pmax=[r.phys.pmax for r in riders],w=[r.store for r in riders]).items():
        case[key]=[0.]+values
    cases.append(case)
output=Path(__file__).with_name('intermediate_sprint_policy_cases.json')
output.write_text(json.dumps(cases,indent=2)+'\n',encoding='utf-8')
print(f'{len(cases)} cases / {sum(len(c["expected"]) for c in cases)} decisions: {output.name}')
