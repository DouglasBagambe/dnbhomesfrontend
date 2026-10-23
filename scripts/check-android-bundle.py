#!/usr/bin/env python3
import argparse, json, struct
from pathlib import Path
from zipfile import ZipFile
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('--signed', action='store_true', help='Validate a real signed production bundle instead of an unsigned QA bundle')
args = parser.parse_args()

workspace = Path(__file__).resolve().parent.parent
repo = workspace
aab = repo / 'build/app/outputs/bundle/productionRelease/app-production-release.aab'
manifest = repo / 'build/app/intermediates/merged_manifests/productionRelease/processProductionReleaseManifest/AndroidManifest.xml'
root = ET.parse(manifest).getroot()
android = '{http://schemas.android.com/apk/res/android}'
assert root.attrib['package'] == 'com.nilebitlabs.dnbhomes'
assert root.find('uses-sdk').attrib[android + 'targetSdkVersion'] == '36'
permissions = {item.attrib[android + 'name'] for item in root.findall('uses-permission')}
required_permissions = {
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'com.nilebitlabs.dnbhomes.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
}
assert required_permissions <= permissions, ('Missing required permission', required_permissions - permissions)
forbidden_permissions = {
    'android.permission.READ_CONTACTS',
    'android.permission.WRITE_CONTACTS',
    'android.permission.READ_SMS',
    'android.permission.SEND_SMS',
    'android.permission.RECORD_AUDIO',
    'android.permission.CAMERA',
    'android.permission.READ_CALL_LOG',
    'android.permission.WRITE_CALL_LOG',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
}
assert not (permissions & forbidden_permissions), ('Unexpected sensitive permission', permissions & forbidden_permissions)
assert root.find('application').attrib.get(android + 'usesCleartextTraffic') != 'true'
rows = []
with ZipFile(aab) as archive:
    signed = any(n.upper().endswith(('.RSA', '.DSA', '.EC')) for n in archive.namelist())
    assert signed == args.signed, 'Bundle signature presence does not match requested validation mode.'
    assert 'base/assets/flutter_assets/.env' not in archive.namelist(), 'Environment files must not be bundled.'
    for name in archive.namelist():
        if not name.startswith(('base/lib/arm64-v8a/', 'base/lib/x86_64/')) or not name.endswith('.so'):
            continue
        data = archive.read(name)
        assert data[:6] == b'\x7fELF\x02\x01', name
        offset = struct.unpack_from('<Q', data, 32)[0]
        stride, count = struct.unpack_from('<HH', data, 54)
        loads = []
        relro = []
        load_ranges = []
        relro_ranges = []
        for i in range(count):
            header = offset + i * stride
            kind = struct.unpack_from('<I', data, header)[0]
            if kind == 1:
                align = struct.unpack_from('<Q', data, header + 48)[0]
                assert align >= 16384, (name, align)
                loads.append(align)
                address = struct.unpack_from('<Q', data, header + 16)[0]
                size = struct.unpack_from('<Q', data, header + 40)[0]
                load_ranges.append((address, address + size))
            if kind == 0x6474e552:
                address = struct.unpack_from('<Q', data, header + 16)[0]
                size = struct.unpack_from('<Q', data, header + 40)[0]
                relro_ranges.append((address, address + size))
                relro.append(address + size)
        for start, end in relro_ranges:
            # A RELRO suffix may end between pages when it occupies the rest
            # of its LOAD segment; there is no mutable data after it in that segment.
            suffix = any(begin <= start and end == finish for begin, finish in load_ranges)
            assert end % 16384 == 0 or suffix, (name, 'RELRO is neither 16 KB aligned nor a LOAD suffix')
        assert loads, name
        rows.append({'library': name, 'loadAlignments': loads, 'relroEnds': relro, 'loadRanges': load_ranges})
assert any('/arm64-v8a/libapp.so' in row['library'] for row in rows)
assert any('/x86_64/libapp.so' in row['library'] for row in rows)
(repo / 'build/android-bundle-check.json').write_text(json.dumps({'package': root.attrib['package'], 'targetApi': 36, 'unsigned': not args.signed, 'bytes': aab.stat().st_size, 'nativeLibraries': rows}, indent=2) + '\n')
print(f'PASS: {"signed" if args.signed else "unsigned"} production AAB, API 36 manifest, no bundled environment file, {len(rows)} 64-bit libraries with 16 KB compatible LOAD/RELRO layout.')
