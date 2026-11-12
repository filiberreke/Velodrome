"""Verify the delivered archive can run independently from an extracted folder."""
import csv,hashlib,json,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source_hash=hashlib.sha256((ROOT/'source/elimination_v2.py').read_bytes()).hexdigest()
target=ROOT.parents[1]/'work'/('elimination_package_check_'+source_hash[:10])
target.mkdir(parents=True,exist_ok=True)
archive=ROOT.parent/(ROOT.name+'_code_en_resultaten.zip')
with zipfile.ZipFile(archive) as z:
    assert all(not Path(i.filename).is_absolute() and '..' not in Path(i.filename).parts for i in z.infolist())
    z.extractall(target)
package=target/ROOT.name
engine=package/'source/elimination_v2.py'
assert hashlib.sha256(engine.read_bytes()).hexdigest()==source_hash
lap_path=target/'cli_laps.csv'
result=subprocess.run([sys.executable,str(engine),'--seed','17','--dt','0.13','--lap-csv',str(lap_path)],cwd=package,capture_output=True,text=True,check=True)
actual=json.loads(result.stdout)
with (ROOT/'results/before_after.csv').open(newline='') as f:
    expected=next(r for r in csv.DictReader(f) if r['variant']=='v2' and r['seed']=='17')
assert all(str(v)==expected[k] for k,v in actual.items()),(actual,expected)
with lap_path.open(newline='') as f: laps=list(csv.DictReader(f))
with (ROOT/'results/lap_speeds.csv').open(newline='') as f:
    expected_laps=[r for r in csv.DictReader(f) if r['variant']=='v2' and r['seed']=='17']
assert len(laps)==len(expected_laps)==30
assert all(abs(float(a['field_mean_kmh'])-float(b['field_mean_kmh']))<1e-9 for a,b in zip(laps,expected_laps))
proof=dict(passed=True,source_sha256=source_hash,portable_standard_library_cli=True,seed=17,frame_dt=.13,all_race_metrics_equal=True,all_30_lap_speeds_equal=True)
(ROOT/'results/package_smoke.json').write_text(json.dumps(proof,indent=2),encoding='utf-8')
print('Portable archive: race and all 30 laps match')
