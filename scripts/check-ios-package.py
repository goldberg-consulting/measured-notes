#!/usr/bin/env python3
"""Check the contents of an exported IPA without installing or uploading it."""
import plistlib
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as package:
    names = package.namelist()
    roots = [name for name in names if name.startswith('Payload/') and name.count('/') == 2 and name.endswith('.app/')]
    if len(roots) != 1:
        raise SystemExit('Expected one application in the package.')
    root = roots[0]
    info = plistlib.loads(package.read(root + 'Info.plist'))
    assert info['CFBundleIdentifier'] == 'one.measured.notes.mobile', 'Wrong application identifier'
    assert info.get('CFBundleVersion'), 'Missing build number'
    assert info.get('CFBundleShortVersionString'), 'Missing version'
    assert set(info['UIDeviceFamily']) == {1, 2}, 'Expected iPhone and iPad support'
    assert root + 'embedded.mobileprovision' in names, 'Missing distribution profile'
    assert root + 'Assets.car' in names, 'Missing compiled assets'
    privacy = plistlib.loads(package.read(root + 'PrivacyInfo.xcprivacy'))
    assert privacy['NSPrivacyTracking'] is False, 'Unexpected tracking declaration'
    assert privacy['NSPrivacyCollectedDataTypes'] == [], 'Review changed data collection declarations'
    reasons = {entry['NSPrivacyAccessedAPIType']: entry['NSPrivacyAccessedAPITypeReasons'] for entry in privacy['NSPrivacyAccessedAPITypes']}
    assert 'CA92.1' in reasons.get('NSPrivacyAccessedAPICategoryUserDefaults', []), 'Missing preferences reason'
    assert 'C617.1' in reasons.get('NSPrivacyAccessedAPICategoryFileTimestamp', []), 'Missing file timestamp reason'
    unexpected = [name for name in names if name.startswith(root) and name.endswith(('.swift', '.yml', '.entitlements', '.md'))]
    assert not unexpected, f'Unexpected source files packaged: {unexpected}'
    print(f"PASS: iOS {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}), phone/tablet support, assets, profile, privacy manifest, no source files")
