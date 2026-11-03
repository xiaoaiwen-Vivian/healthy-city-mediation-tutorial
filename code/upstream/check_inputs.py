"""Check required external source releases before reconstructing the input."""
from pathlib import Path
import hashlib,json,re
config=dict(line.split('\t',1) for line in Path('input_paths.tsv').read_text().splitlines())
items=json.loads(Path('verification/INPUT_MANIFEST.json').read_text())
records=[]
for item in items:
    p=Path(re.sub(r'\$(\w+)',lambda m:config[m[1]],item['configured_path']))
    h=hashlib.file_digest(p.open('rb'),'sha256').hexdigest() if p.is_file() else None
    records.append({'input':item['configured_path'],'exists':p.is_file(),'matches_reference':h==item['sha256']})
Path('logs/upstream_inputs_verified.json').write_text(json.dumps(records,indent=2))
bad=[r for r in records if not r['matches_reference']]
if bad:raise SystemExit('Missing or different source releases: '+str(bad))
Path('logs/upstream_inputs_verified.ok').write_text(f'All {len(records)} external source files matched.\n')
print(f'All {len(records)} external source files matched.')
