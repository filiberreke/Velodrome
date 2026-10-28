"""Verify unchanged physics against the pinned Git commit (or exact export)."""
import argparse
import ast
import hashlib
import importlib.util
import json
import subprocess
import tempfile
from pathlib import Path
import energy_core
import sim_f

BASE='edab6a112df472ec301603bf56919c827dde0355'
ROOT=Path(__file__).resolve().parent
BLOBS={'sim_f.py':'3fc33da1c4c7d6ed4f92ee4a3ccee5b5565126c5',
       'energy_core.py':'49effd46f6f643665a71dd3654de7c4567099624'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--upstream-dir',type=Path)
    a=p.parse_args()
    sources={}
    for name,sha in BLOBS.items():
        raw=(a.upstream_dir/name).read_bytes() if a.upstream_dir else subprocess.check_output(
            ['git','show',f'{BASE}:simulation/{name}'],cwd=ROOT)
        assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==sha
        sources[name]=raw
    old=ast.parse(sources['sim_f.py'].decode())
    new=ast.parse((ROOT/'sim_f.py').read_text(encoding='utf-8'))
    checks={}
    for name in ('Rider','road_power','integrate_speed','draft_speed_factor','bank_height','lane_distance_multiplier'):
        checks[name]=ast.dump(next(x for x in old.body if getattr(x,'name',None)==name))==ast.dump(next(x for x in new.body if getattr(x,'name',None)==name))
    checks['energy_core_identical']=(ROOT/'energy_core.py').read_bytes()==sources['energy_core.py']
    with tempfile.TemporaryDirectory() as tmp:
        file=Path(tmp)/'original.py';file.write_bytes(sources['sim_f.py'])
        spec=importlib.util.spec_from_file_location('original',file)
        original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
        for seed in (1,1049):
            kwargs=dict(seed=seed,count=8,laps=25,variant='L',final750=True,
                        no_speed_cap=True,breakaway_v=True,real_laps=True)
            checks[f'legacy_full_output_seed_{seed}']=original.run(**kwargs)==sim_f.run(**kwargs)
    assert all(checks.values()),checks
    (ROOT/'physics_verification.json').write_text(json.dumps(checks,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(checks,indent=2))


if __name__=='__main__':main()
