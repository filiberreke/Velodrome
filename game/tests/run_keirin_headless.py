"""Run native keirin and selected regression tests with Godot 4.7+.

python tests/run_keirin_headless.py --godot /path/to/Godot
python tests/run_keirin_headless.py --godot /path/to/Godot --quick test_keirin
"""
import argparse,csv,json,os,shutil,subprocess,sys,time
from pathlib import Path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',default=os.environ.get('GODOT_BIN') or shutil.which('godot') or shutil.which('godot4'))
    parser.add_argument('--quick',action='store_true')
    parser.add_argument('--timeout',type=int,default=600)
    parser.add_argument('tests',nargs='*')
    args=parser.parse_args()
    if not args.godot:parser.error('Pass --godot /path/to/Godot or set GODOT_BIN')
    project=Path(__file__).resolve().parents[1]
    output=project/'verification/keirin/run';output.mkdir(parents=True,exist_ok=True)
    names=args.tests or ['test_keirin','test_keirin_flow','test_derny_session','test_derny_training','test_menu','test_v02_menu','test_elimination_native_core','test_elimination_native_small','test_shared_race_traffic','test_gameplay_headless','test_points_race']
    results=[]
    for name in names:
        env=os.environ.copy()
        for key in ('APPDATA','LOCALAPPDATA'):
            path=output/'runtime'/name/key;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
        command=[args.godot,'--headless','--path',str(project),'--log-file',str(output/(name+'.engine.log')),'--script','res://tests/'+name+'.gd']
        if name=='test_keirin':
            command+=['--','--output='+str(output/'keirin_headless.json')]
            if args.quick:command+=['--quick']
        start=time.monotonic()
        try:
            r=subprocess.run(command,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=args.timeout,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            text=r.stdout+r.stderr;code=r.returncode
        except subprocess.TimeoutExpired:
            text='TIMEOUT';code=-1
        (output/(name+'.log')).write_text(text,encoding='utf-8')
        errors=[line for line in text.splitlines() if any(mark in line for mark in ('SCRIPT ERROR','Parse Error','Assertion failed','ERROR:'))]
        # Both messages also occur in the unmodified v0.2 baseline. Keep them
        # visible in the report; assertions and script errors are never filtered.
        environment=[line for line in errors if 'root certificate store' in line or (line=='ERROR: Parameter "material" is null.' and 'servers/rendering/dummy/storage/material_storage.cpp:264' in text)]
        errors=[line for line in errors if line not in environment]
        result=dict(test=name,passed=code==0 and not errors,exit_code=code,seconds=round(time.monotonic()-start,2),errors=errors,environment=environment)
        results.append(result);print(json.dumps(result),flush=True)
        if not result['passed']:break
    (output/'summary.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    if (output/'keirin_headless.json').exists():export_csv(output)
    return 0 if all(r['passed'] for r in results) else 1

def export_csv(output):
    data=json.loads((output/'keirin_headless.json').read_text(encoding='utf-8'))
    races=[];riders=[]
    for race in data['races']:
        row={k:v for k,v in race.items() if not isinstance(v,list)}
        row['last_finish_s']=max(race['finish_times']);races.append(row)
        for i,t in enumerate(race['finish_times']):
            riders.append(dict(derny=race['derny'],seed=race['seed'],rider_id=i,profile='sprinter' if i<4 else 'attacker',finish_time_s=t,sprint_start_free_s=race['sprint_starts'][i],sprint_remaining_m=race['sprint_distances'][i]))
    for name,rows in [('races.csv',races),('riders.csv',riders)]:
        with (output/name).open('w',newline='',encoding='utf-8') as f:
            w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
if __name__=='__main__':sys.exit(main())
