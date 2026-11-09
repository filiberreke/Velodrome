"""Run the native elimination checks with an installed Godot 4 executable."""
import argparse,json,os,shutil,subprocess,sys,time
from pathlib import Path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',default=os.environ.get('GODOT_BIN') or shutil.which('godot') or shutil.which('godot4'))
    parser.add_argument('--timeout',type=int,default=480)
    parser.add_argument('tests',nargs='*')
    args=parser.parse_args()
    if not args.godot:parser.error('Pass --godot /path/to/Godot or set GODOT_BIN')
    project=Path(__file__).resolve().parents[1]
    output=project/'verification/elimination_native/run';output.mkdir(parents=True,exist_ok=True)
    names=args.tests or ['test_elimination_native_core','test_elimination_native','test_elimination_rules','test_elimination_gameplay','test_elimination_corrections','test_elimination_peloton','test_shared_race_traffic','test_gameplay_headless','test_points_race']
    rows=[]
    for name in names:
        env=os.environ.copy()
        for key in ('APPDATA','LOCALAPPDATA'):
            directory=output/'runtime'/name/key;directory.mkdir(parents=True,exist_ok=True);env[key]=str(directory)
        start=time.monotonic()
        command=[args.godot,'--headless','--path',str(project),'--log-file',str(output/(name+'.engine.log')),'--script','res://tests/'+name+'.gd']
        try:
            result=subprocess.run(command,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=args.timeout,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
            text=result.stdout+result.stderr;code=result.returncode
        except subprocess.TimeoutExpired:
            text='TIMEOUT after '+str(args.timeout)+' seconds';code=-1
        errors=[line for line in text.splitlines() if any(mark in line for mark in ('SCRIPT ERROR','Parse Error','Assertion failed','ERROR:')) and 'root certificate store' not in line]
        passed=code==0 and not errors
        (output/(name+'.log')).write_text(text,encoding='utf-8')
        row=dict(test=name,passed=passed,exit_code=code,seconds=round(time.monotonic()-start,2),errors=errors[:20]);rows.append(row)
        print(json.dumps(row),flush=True)
        if not passed:break
    (output/'summary.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    return 0 if all(row['passed'] for row in rows) else 1

if __name__=='__main__':sys.exit(main())
