#!/usr/bin/env python3
import base64
import importlib.util
from pathlib import Path
import plistlib
import unittest
import json
import xml.etree.ElementTree as ET

repo = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('guard', repo / 'scripts/validate-ios-release.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

class IOSReleaseTests(unittest.TestCase):
    def config(self, **patch):
        values = {
            'HOMES_ENV':'production',
            'HOMES_API_URL':'https://api.homes-fixture.co.ug/api/v1',
            'HOMES_WEBSITE_URL':'https://homes-fixture.co.ug',
            'HOMES_GOOGLE_WEB_CLIENT_ID':'web-client',
            'HOMES_GOOGLE_IOS_CLIENT_ID':'ios-client',
            'HOMES_APPLE_SERVICE_ID':'homes.apple.service',
            'HOMES_APPLE_REDIRECT_URI':'https://api.homes-fixture.co.ug/api/v1/consumer/apple/callback/production',
        }
        values.update(patch)
        return {
            'CONFIGURATION':'Release',
            'HOMES_LINK_HOST':'homes-fixture.co.ug',
            'HOMES_GOOGLE_REVERSED_CLIENT_ID':'com.googleusercontent.apps.1234567890-homes',
            'DART_DEFINES':','.join(base64.b64encode(f'{key}={value}'.encode()).decode() for key,value in values.items()),
        }
    def test_release_guard(self):
        guard.validate(self.config())
        for patch in [{'HOMES_ENV':'development'}, {'HOMES_API_URL':'http://127.0.0.1/api/v1'}, {'HOMES_WEBSITE_URL':''}, {'HOMES_BUILD_VALIDATION':'true'}, {'HOMES_API_URL':'https://api.example.com/api/v1'}]:
            with self.assertRaises(ValueError): guard.validate(self.config(**patch))
    def test_repository_configuration(self):
        info = plistlib.loads((repo / 'ios/Runner/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleDisplayName'],'Homes')
        self.assertNotIn('NSAppTransportSecurity',info)
        self.assertNotIn('NSCameraUsageDescription',info)
        schemes = info['CFBundleURLTypes'][0]['CFBundleURLSchemes']
        self.assertEqual(schemes, ['$(HOMES_GOOGLE_REVERSED_CLIENT_ID)'])
        for name in ['DebugProfile','Release']:
            entitlements = plistlib.loads((repo / f'ios/Runner/{name}.entitlements').read_bytes())
            self.assertEqual(entitlements['com.apple.developer.associated-domains'],['applinks:$(HOMES_LINK_HOST)'])
            self.assertEqual(entitlements['com.apple.developer.applesignin'], ['Default'])
        project = (repo / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        self.assertNotIn('com.uganda.rent',project)
        self.assertIn('validate-ios-release.py',project)
        self.assertEqual(project.count('ABCD11111111111111111111'),2)
        privacy = plistlib.loads((repo / 'ios/Runner/PrivacyInfo.xcprivacy').read_bytes())
        self.assertFalse(privacy['NSPrivacyTracking'])
        self.assertTrue(privacy['NSPrivacyCollectedDataTypes'])

    def test_native_launch_bridge(self):
        storyboard = ET.parse(repo / 'ios/Runner/Base.lproj/LaunchScreen.storyboard')
        self.assertEqual(storyboard.findall('.//imageView'), [])
        self.assertEqual(storyboard.find('.//color[@key="backgroundColor"]').get('name'), 'HomesLaunchBackground')
        colors = json.loads((repo / 'ios/Runner/Assets.xcassets/HomesLaunchBackground.colorset/Contents.json').read_text())['colors']
        self.assertEqual(len(colors), 2)
        for folder in ['drawable', 'drawable-v21', 'drawable-night', 'drawable-night-v21']:
            launch = ET.parse(repo / f'android/app/src/main/res/{folder}/launch_background.xml')
            self.assertEqual(launch.findall('.//bitmap'), [])
            self.assertEqual(launch.find('item').get('{http://schemas.android.com/apk/res/android}drawable'), '@color/homes_launch_background')

        for folder in ['values-v31', 'values-night-v31']:
            styles = ET.parse(repo / f'android/app/src/main/res/{folder}/styles.xml')
            icon = styles.find('.//item[@name="android:windowSplashScreenAnimatedIcon"]')
            self.assertEqual(icon.text, '@drawable/launch_empty_icon')
        icon = ET.parse(repo / 'android/app/src/main/res/drawable/launch_empty_icon.xml')
        self.assertEqual(icon.find('path').get('{http://schemas.android.com/apk/res/android}fillColor'), '#00000000')

if __name__ == '__main__': unittest.main()
