#!/usr/bin/env python3
import base64
import importlib.util
from pathlib import Path
import plistlib
import unittest

repo = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('guard', repo / 'scripts/validate-ios-release.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

class IOSReleaseTests(unittest.TestCase):
    def config(self, **patch):
        values = {'HOMES_ENV':'production', 'HOMES_API_URL':'https://api.homes-fixture.co.ug/api/v1', 'HOMES_WEBSITE_URL':'https://homes-fixture.co.ug'}
        values.update(patch)
        return {'CONFIGURATION':'Release', 'HOMES_LINK_HOST':'homes-fixture.co.ug', 'DART_DEFINES':','.join(base64.b64encode(f'{key}={value}'.encode()).decode() for key,value in values.items())}
    def test_release_guard(self):
        guard.validate(self.config())
        for patch in [{'HOMES_ENV':'development'}, {'HOMES_API_URL':'http://127.0.0.1/api/v1'}, {'HOMES_WEBSITE_URL':''}, {'HOMES_BUILD_VALIDATION':'true'}, {'HOMES_API_URL':'https://api.example.com/api/v1'}]:
            with self.assertRaises(ValueError): guard.validate(self.config(**patch))
    def test_repository_configuration(self):
        info = plistlib.loads((repo / 'ios/Runner/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleDisplayName'],'Homes')
        self.assertNotIn('NSAppTransportSecurity',info)
        self.assertNotIn('NSCameraUsageDescription',info)
        for name in ['DebugProfile','Release']:
            entitlements = plistlib.loads((repo / f'ios/Runner/{name}.entitlements').read_bytes())
            self.assertEqual(entitlements['com.apple.developer.associated-domains'],['applinks:$(HOMES_LINK_HOST)'])
        project = (repo / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        self.assertNotIn('com.uganda.rent',project)
        self.assertIn('validate-ios-release.py',project)
        self.assertEqual(project.count('ABCD11111111111111111111'),2)
        privacy = plistlib.loads((repo / 'ios/Runner/PrivacyInfo.xcprivacy').read_bytes())
        self.assertFalse(privacy['NSPrivacyTracking'])
        self.assertTrue(privacy['NSPrivacyCollectedDataTypes'])

if __name__ == '__main__': unittest.main()
