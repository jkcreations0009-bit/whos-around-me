#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = []
errors = []

layout_fix = ROOT / 'tools/apply_phase7_layout_fix.py'
subprocess.run([sys.executable, str(layout_fix)], check=True)


def req(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


screen = (ROOT / 'apps/mobile/lib/features/nearby/nearby_local_screen.dart').read_text()
query = (ROOT / 'apps/mobile/lib/domain/models/nearby_list_query.dart').read_text()
service = (ROOT / 'apps/mobile/lib/domain/policies/nearby_list_service.dart').read_text()
unit = (ROOT / 'apps/mobile/test/unit/nearby_list_service_test.dart').read_text()
widget = (ROOT / 'apps/mobile/test/widget/app_smoke_test.dart').read_text()
local_service = (ROOT / 'apps/mobile/lib/domain/policies/local_nearby_service.dart').read_text()
overlay = (ROOT / 'tools/apply_native_overlays.py').read_text()

req('NearbySortOrder' in query, 'sort model exists')
for value in ['nearestFirst', 'farthestFirst', 'nameAscending']:
    req(value in query, f'sort option {value} exists')
for value in ['within1Km', 'within5Km', 'within20Km']:
    req(value in query, f'distance filter {value} exists')
req('meters == null || meters > maximumMeters' in service,
    'distance filters fail closed for unknown contact distance')
req('aMeters == null' in service and 'bMeters == null' in service,
    'sort keeps unknown distance semantically separate')
req('savedLocationsByContactId' in local_service and 'userLocation == null || saved == null' in local_service,
    'distance requires both user and saved/authorized contact location')
req('ProximityPreferences.defaults()' in screen,
    'screen uses centralized semantic proximity thresholds')
for text in ['Very close', 'Very near', 'Nearby', 'Moderate', 'Far', 'Unavailable']:
    req(text in screen, f'accessible proximity text {text} exists')
for text in ['≤ 1 km', '≤ 5 km', '≤ 20 km', 'Nearest first', 'Farthest first', 'Name A–Z']:
    req(text in screen, f'Phase7 control {text} exists')
req('No authorized/saved location available' in screen,
    'unknown contact location is explicit rather than fabricated')
req('not published by this phase' in screen,
    'Private Local Mode publication boundary remains visible')
req('live sharing' not in screen.lower(),
    'Phase7 screen does not activate live-sharing workflow')
req('child: CustomScrollView(' in screen,
    'Nearby screen uses a vertically scrollable responsive root')
req('SliverFillRemaining(' in screen and 'SliverList(' in screen,
    'empty and populated nearby states participate in one scrollable viewport')
for boundary in ['1000m', '1001m', '5000m', '5001m', '20000m', '20001m']:
    req(boundary in unit, f'list-filter boundary test includes {boundary}')
req('distance filter excludes contacts with unknown location' in widget,
    'widget regression checks unknown location filtering')
req('Size(360, 640)' in widget and 'CustomScrollView' in widget,
    'phone-sized responsive widget regression exists')
req('create("qa")' in overlay, 'Android Gradle-safe qa flavor retained')
req('resValues = true' in overlay, 'AGP9 resValues opt-in retained')
req('compileSdk = 37' in overlay,
    'Android bridge compiles against API 37 for Contacts Picker APIs')

print('PHASE 7 DISTANCE / LIST VERIFICATION')
for item in checks:
    print('PASS:', item)
for item in errors:
    print('FAIL:', item)
print(f'PASS COUNT: {len(checks)}')
print(f'FAIL COUNT: {len(errors)}')
sys.exit(1 if errors else 0)
