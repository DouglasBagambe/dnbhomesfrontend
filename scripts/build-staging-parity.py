#!/usr/bin/env python3
"""Build both phone-test modes from one fingerprinted source, preserving outputs."""
import hashlib
import json
import subprocess
from pathlib import Path

repo = Path(__file__).resolve().parents[1]


def run(*args):
    subprocess.run(args, cwd=repo, check=True)


def fingerprint():
    digest = hashlib.sha256()
    paths = [repo / 'pubspec.yaml', repo / 'pubspec.lock']
    for folder in ['lib', 'assets', 'android']:
        paths.extend(p for p in (repo / folder).rglob('*')
                     if p.is_file() and not any(part in {'.gradle', '.cxx', 'build'} for part in p.parts)
                     and p.name not in {'local.properties', 'key.properties'})
    for path in sorted(paths):
        digest.update(str(path.relative_to(repo)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def main():
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo, text=True).strip())
    source = fingerprint()
    run('flutter', 'clean')
    run('flutter', 'pub', 'get', '--enforce-lockfile')
    output = repo / 'build' / 'staging-parity' / f'{sha[:12]}-{source[:12]}'
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for mode in ['debug', 'profile']:
        if fingerprint() != source:
            raise RuntimeError('Source changed during parity build; rebuild both modes')
        run('flutter', 'build', 'apk', f'--{mode}', '--flavor', 'staging',
            '--target', 'lib/main.dart', '--dart-define=HOMES_ENV=staging',
            '--dart-define=HOMES_API_URL=https://dnbhomesbackend.onrender.com/api/v1')
        apk = repo / 'build' / 'app' / 'outputs' / 'flutter-apk' / f'app-staging-{mode}.apk'
        payload = apk.read_bytes()
        preserved = output / f'Homes-{sha[:12]}-{mode}.apk'
        preserved.write_bytes(payload)
        records.append({'mode': mode, 'path': str(preserved), 'bytes': len(payload),
                        'sha256': hashlib.sha256(payload).hexdigest(),
                        'applicationId': 'com.nilebitlabs.dnbhomes.staging', 'label': 'Homes'})
    if fingerprint() != source:
        raise RuntimeError('Source changed during parity build; rebuild both modes')
    manifest = {'gitHead': sha, 'workingTreeDirty': dirty, 'sourceFingerprint': source, 'entrypoint': 'lib/main.dart',
                'environment': 'staging', 'api': 'https://dnbhomesbackend.onrender.com/api/v1',
                'artifacts': records, 'deviceParityVerified': False}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
