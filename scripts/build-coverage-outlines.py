#!/usr/bin/env python3
"""Bundle simplified country outlines for the offline coverage map."""
import json, hashlib, datetime
from pathlib import Path
from urllib.request import urlopen
root = Path(__file__).resolve().parents[1]
url = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson'
data = urlopen(url, timeout=45).read()
source = json.loads(data)
wanted = {'US', 'GB', 'CA', 'AU', 'NZ', 'IE', 'IN', 'SG', 'ZA', 'PR'}
result = {}
for feature in source['features']:
    code = feature['properties']['ISO_A2_EH']
    if code not in wanted: continue
    g = feature['geometry']
    polygons = g['coordinates'] if g['type'] == 'MultiPolygon' else [g['coordinates']]
    # Outer rings only; round coordinates to reduce bundle size. Context outlines,
    # not legal or administrative boundaries for assigning news to a region.
    rings = [[[round(x, 3), round(y, 3)] for x, y in polygon[0]] for polygon in polygons]
    result.setdefault('US' if code == 'PR' else code, []).extend(rings)
assert set(result) == wanted - {'PR'}
p = root / 'Sources/WorkshopCore/Resources/CountryOutlines.json'
p.write_text(json.dumps(result, separators=(',', ':')))
meta = {'source': url, 'sha256': hashlib.sha256(data).hexdigest(), 'builtAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'license': 'Public domain', 'bytes': p.stat().st_size}
(root / 'docs/coverage-outlines-build.json').write_text(json.dumps(meta, indent=2) + '\n')
print(json.dumps(meta, indent=2))
