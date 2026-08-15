#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / 'apps' / 'mobile' / 'ios'
PBX = IOS / 'Runner.xcodeproj' / 'project.pbxproj'
PODFILE = IOS / 'Podfile'
SCHEMES = IOS / 'Runner.xcodeproj' / 'xcshareddata' / 'xcschemes'
REFERENCE = IOS / 'Flutter' / 'WhosAroundMeEnvironmentIds.xcconfig'

checks: list[str] = []
errors: list[str] = []


def req(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


pbx = PBX.read_text()
podfile = PODFILE.read_text()
reference = REFERENCE.read_text()

environments = {
    'development': 'com.dC0dez.Whosaroundme.dev',
    'test': 'com.dC0dez.Whosaroundme.test',
    'staging': 'com.dC0dez.Whosaroundme.staging',
    'production': 'com.dC0dez.Whosaroundme',
}

for environment, bundle_id in environments.items():
    for base in ('Debug', 'Profile', 'Release'):
        name = f'{base}-{environment}'
        req(name in pbx, f'Xcode build configuration {name} exists')
        req(f"'{name}' =>" in podfile, f'CocoaPods maps configuration {name}')
    scheme_path = SCHEMES / f'{environment}.xcscheme'
    req(scheme_path.is_file(), f'shared iOS scheme {environment} exists')
    if scheme_path.is_file():
        scheme = scheme_path.read_text()
        req(f'buildConfiguration = "Debug-{environment}"' in scheme,
            f'{environment} scheme uses Debug-{environment}')
        req(f'buildConfiguration = "Profile-{environment}"' in scheme,
            f'{environment} scheme uses Profile-{environment}')
        req(f'buildConfiguration = "Release-{environment}"' in scheme,
            f'{environment} scheme uses Release-{environment}')
    req(bundle_id in pbx, f'exact {environment} bundle id is present in Xcode project')
    key = f'WHOSAROUNDME_BUNDLE_ID_{environment.upper()}={bundle_id}'
    req(key in reference, f'exact {environment} bundle id reference is retained')

req('com.dC0dez.Whosaroundme.dev' in pbx and 'com.dC0dez.whosaroundme.dev' not in pbx,
    'development bundle-id case is preserved exactly')
req('com.dC0dez.Whosaroundme.test' in pbx and 'com.dC0dez.whosaroundme.test' not in pbx,
    'test bundle-id case is preserved exactly')
req('com.dC0dez.Whosaroundme.staging' in pbx and 'com.dC0dez.whosaroundme.staging' not in pbx,
    'staging bundle-id case is preserved exactly')

print('PHASE 8E IOS ENVIRONMENT VERIFICATION')
for item in checks:
    print('PASS:', item)
for item in errors:
    print('FAIL:', item)
print(f'PASS COUNT: {len(checks)}')
print(f'FAIL COUNT: {len(errors)}')
sys.exit(1 if errors else 0)
