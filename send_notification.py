#!/usr/bin/env python3
"""
Simple tester script to fetch player IDs from Supabase and send a OneSignal notification.

Usage examples (PowerShell / CMD / bash):

# Send to all active player_ids
python send_notification.py --title "Hello" --message "Test message"

# Send to a specific Supabase user (external user id)
python send_notification.py --user-id 5df62958-2eee-469b-95f9-8d2f3b5fa406 --title "Hi Jad" --message "Test"

# Dry-run (just print found player ids)
python send_notification.py --user-id 5df62958-2eee-469b-95f9-8d2f3b5fa406 --dry-run

Environment variables required:
- SUPABASE_URL (e.g. https://yourproject.supabase.co)
- SUPABASE_SERVICE_ROLE_KEY (recommended; needed if RLS blocks anon reads)
- ONESIGNAL_REST_API_KEY (OneSignal REST API key - keep secret)
- ONESIGNAL_APP_ID (OneSignal App ID)

Note: Do NOT embed REST keys in production apps. This script is for local/dev testing only.
"""

import os
import sys
import argparse
import requests
from typing import List, Optional
import json
try:
    from dotenv import load_dotenv
    _HAS_DOTENV = True
except Exception:
    _HAS_DOTENV = False


def get_supabase_players(supabase_url: str, supabase_key: str, user_id: Optional[str] = None) -> List[dict]:
    """Fetch rows from `user_player_ids` table. Returns list of dicts with keys including 'player_id' and 'user_id'."""
    headers = {
        'apikey': supabase_key,
        'Authorization': f'Bearer {supabase_key}',
    }
    # Build query
    if user_id:
        params = {
            'select': 'player_id,user_id,device_type,is_active',
            'user_id': f'eq.{user_id}',
            'is_active': 'eq.true'
        }
    else:
        params = {
            'select': 'player_id,user_id,device_type,is_active',
            'is_active': 'eq.true'
        }

    url = f"{supabase_url.rstrip('/')}/rest/v1/user_player_ids"
    resp = requests.get(url, headers=headers, params=params)
    if resp.status_code != 200:
        print(f"Failed to query Supabase: {resp.status_code} {resp.text}")
        sys.exit(1)
    return resp.json()


def send_onesignal_to_player_ids(app_id: str, rest_key: str, player_ids: List[str], title: str, message: str, data: Optional[dict] = None):
    url = 'https://onesignal.com/api/v1/notifications'
    headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': f'Basic {rest_key}',
    }
    body = {
        'app_id': app_id,
        'include_player_ids': player_ids,
        'headings': {'en': title},
        'contents': {'en': message},
    }
    if data:
        body['data'] = data

    resp = requests.post(url, headers=headers, json=body)
    print('OneSignal response code:', resp.status_code)
    print(resp.text)
    return resp


def send_onesignal_to_external_ids(app_id: str, rest_key: str, external_user_ids: List[str], title: str, message: str, data: Optional[dict] = None):
    url = 'https://onesignal.com/api/v1/notifications'
    headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': f'Basic {rest_key}',
    }
    body = {
        'app_id': app_id,
        'include_external_user_ids': external_user_ids,
        'headings': {'en': title},
        'contents': {'en': message},
    }
    if data:
        body['data'] = data

    resp = requests.post(url, headers=headers, json=body)
    print('OneSignal response code:', resp.status_code)
    print(resp.text)
    return resp


def main():
    parser = argparse.ArgumentParser(description='Send OneSignal notifications using player IDs read from Supabase')
    parser.add_argument('--user-id', help='Supabase user id (external id) to target; if omitted, targets all active player ids')
    parser.add_argument('--title', default='Test Notification')
    parser.add_argument('--message', default='Hello from send_notification.py')
    parser.add_argument('--use-external-ids', action='store_true', help='Send by external_user_ids instead of player ids')
    parser.add_argument('--dry-run', action='store_true', help='Only print found player ids, do not send')
    parser.add_argument('--data', help='Optional JSON string for data payload')

    args = parser.parse_args()

    # Load .env if available (project root)
    if _HAS_DOTENV:
        # prefer project .env in cwd
        dotenv_path = os.path.join(os.getcwd(), '.env')
        load_dotenv(dotenv_path)

    # Load config from environment first, then fallback to project config file
    def load_config_file() -> dict:
        candidates = [
            os.path.join(os.getcwd(), 'notification_config.json'),
            os.path.join(os.path.dirname(__file__), 'notification_config.json'),
        ]
        for path in candidates:
            try:
                if os.path.isfile(path):
                    with open(path, 'r', encoding='utf-8') as f:
                        return json.load(f)
            except Exception:
                continue
        return {}

    cfg = load_config_file()

    supabase_url = os.getenv('SUPABASE_URL') or cfg.get('SUPABASE_URL')
    supabase_key = (
        os.getenv('SUPABASE_SERVICE_ROLE_KEY')
        or os.getenv('SUPABASE_KEY')
        or cfg.get('SUPABASE_SERVICE_ROLE_KEY')
        or cfg.get('SUPABASE_KEY')
    )
    onesignal_key = os.getenv('ONESIGNAL_REST_API_KEY') or cfg.get('ONESIGNAL_REST_API_KEY')
    onesignal_app_id = os.getenv('ONESIGNAL_APP_ID') or cfg.get('ONESIGNAL_APP_ID')

    if not supabase_url or not supabase_key:
        print('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY / SUPABASE_KEY in environment')
        # Debug help: show where we looked and what we loaded (mask secrets)
        print('Working directory:', os.getcwd())
        cfg_path = os.path.join(os.getcwd(), 'notification_config.json')
        print('notification_config.json present in cwd:', os.path.isfile(cfg_path))
        print('Loaded config keys:', list(cfg.keys()))
        print('Env SUPABASE_URL present:', bool(os.getenv('SUPABASE_URL')))
        print('Env SUPABASE_SERVICE_ROLE_KEY present:', bool(os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_KEY')))
        # Mask values
        def mask(s: Optional[str]) -> str:
            if not s:
                return '<empty>'
            s = str(s)
            if len(s) <= 12:
                return s
            return s[:6] + '...' + s[-6:]

        print('cfg SUPABASE_URL:', mask(cfg.get('SUPABASE_URL')))
        print('cfg SUPABASE_SERVICE_ROLE_KEY:', mask(cfg.get('SUPABASE_SERVICE_ROLE_KEY')))
        sys.exit(1)

    players = get_supabase_players(supabase_url, supabase_key, user_id=args.user_id)
    if not players:
        print('No active player ids found for the query')
        return

    print(f'Found {len(players)} active device(s):')
    for p in players:
        print('  user_id:', p.get('user_id'), 'player_id:', p.get('player_id'), 'device_type:', p.get('device_type'))

    if args.dry_run:
        print('Dry run, exiting')
        return

    if not onesignal_key or not onesignal_app_id:
        print('Missing OneSignal REST key or App ID. Set ONESIGNAL_REST_API_KEY and ONESIGNAL_APP_ID in env to actually send.')
        sys.exit(1)

    data_payload = None
    if args.data:
        try:
            import json

            data_payload = json.loads(args.data)
        except Exception as e:
            print('Invalid JSON for --data:', e)
            sys.exit(1)

    if args.use_external_ids:
        external_ids = list({p.get('user_id') for p in players if p.get('user_id')})
        print('Sending to external user ids:', external_ids)
        send_onesignal_to_external_ids(onesignal_app_id, onesignal_key, external_ids, args.title, args.message, data_payload)
    else:
        player_ids = [p.get('player_id') for p in players if p.get('player_id')]
        print('Sending to player ids:', player_ids)
        send_onesignal_to_player_ids(onesignal_app_id, onesignal_key, player_ids, args.title, args.message, data_payload)


if __name__ == '__main__':
    main()
