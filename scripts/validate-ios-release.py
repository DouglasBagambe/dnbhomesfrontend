#!/usr/bin/env python3
"""Xcode pre-build guard. Contains no credentials; tested on Linux as well."""
import base64
import os
from urllib.parse import urlsplit


def validate(values):
    if 'release' not in values.get('CONFIGURATION', '').lower():
        return
    defines = dict(base64.b64decode(item).decode().split('=', 1)
                   for item in values.get('DART_DEFINES', '').split(',') if item)
    if defines.get('HOMES_ENV') != 'production' or defines.get('HOMES_BUILD_VALIDATION') == 'true':
        raise ValueError('iOS release requires HOMES_ENV=production; test validation artifacts are forbidden')
    for key in ('HOMES_GOOGLE_WEB_CLIENT_ID', 'HOMES_GOOGLE_IOS_CLIENT_ID',
                'HOMES_APPLE_SERVICE_ID', 'HOMES_APPLE_REDIRECT_URI'):
        if not defines.get(key):
            raise ValueError(f'{key} is required for a production iOS release')
    reversed_client = values.get('HOMES_GOOGLE_REVERSED_CLIENT_ID', '')
    if not reversed_client.startswith('com.googleusercontent.apps.') or len(reversed_client) < 30:
        raise ValueError('HOMES_GOOGLE_REVERSED_CLIENT_ID must be configured for production iOS')
    apple_redirect = urlsplit(defines['HOMES_APPLE_REDIRECT_URI'])
    if apple_redirect.scheme != 'https' or not apple_redirect.hostname or '/api/v1/consumer/apple/callback/' not in apple_redirect.path:
        raise ValueError('HOMES_APPLE_REDIRECT_URI must use the public Homes callback')
    for key, root in [('HOMES_API_URL', '/api/v1'), ('HOMES_WEBSITE_URL', '')]:
        url = urlsplit(defines.get(key, ''))
        host = url.hostname or ''
        if (url.scheme != 'https' or '.' not in host or ':' in host or host.replace('.', '').isdigit()
                or host.endswith(('.invalid', '.test', '.local', '.localhost', '.example'))
                or any(host == domain or host.endswith('.'+domain) for domain in ('example.com','example.net','example.org'))
                or url.username or url.password or url.query or url.fragment or url.path.rstrip('/') != root):
            raise ValueError(f'{key} must be an explicit public HTTPS URL with the correct path')
        if key == 'HOMES_WEBSITE_URL' and values.get('HOMES_LINK_HOST', 'dnbhomeswebsite-psi.vercel.app') != host:
            raise ValueError('HOMES_LINK_HOST must match HOMES_WEBSITE_URL for universal links')


if __name__ == '__main__':
    try:
        validate(os.environ)
    except (ValueError, UnicodeError) as error:
        raise SystemExit(f'error: {error}')
