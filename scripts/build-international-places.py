#!/usr/bin/env python3
"""Build the bundled catalog; no catalog downloads occur in the app."""
from pathlib import Path
from urllib.request import urlopen
from zipfile import ZipFile
from io import BytesIO
from collections import Counter
import hashlib, json, datetime

root = Path(__file__).resolve().parents[1]
countries = {'GB', 'CA', 'AU', 'NZ', 'IE', 'IN', 'SG', 'ZA'}
base = 'https://download.geonames.org/export/dump/'
archive = urlopen(base + 'cities500.zip', timeout=60).read()
admin_data = urlopen(base + 'admin1CodesASCII.txt', timeout=30).read()
admin = {f[0]: f[1] for line in admin_data.decode().splitlines() if len(f := line.split('\t')) >= 2}
rows = []
with ZipFile(BytesIO(archive)) as z:
    for line in z.read('cities500.txt').decode().splitlines():
        f = line.split('\t')
        if len(f) < 19 or f[8] not in countries:
            continue
        region = admin.get(f[8] + '.' + f[10], f[8])
        # Use the provided ASCII name for an English-language picker; preserve source IDs.
        rows.append(['gn-' + f[0], f[2] or f[1], region, f[4], f[5], f[8]])
rows.sort(key=lambda f: (f[5], f[1].casefold(), f[2], f[0]))
out = root / 'Sources/WorkshopCore/Resources/InternationalPlaces.tsv'
out.write_text('\n'.join('\t'.join(row) for row in rows) + '\n')
metadata = {'builtAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'source': base + 'cities500.zip', 'adminSource': base + 'admin1CodesASCII.txt', 'license': 'CC BY 4.0', 'archiveSHA256': hashlib.sha256(archive).hexdigest(), 'counts': dict(sorted(Counter(r[5] for r in rows).items())), 'bytes': out.stat().st_size}
(root / 'docs/international-places-build.json').write_text(json.dumps(metadata, indent=2) + '\n')
print(json.dumps(metadata, indent=2))
