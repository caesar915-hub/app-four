#!/usr/bin/env python3
"""
Fetch markdown transcripts from Google Drive folder → merge into inputs.json.

SETUP (one-time):
  pip install google-auth-oauthlib google-auth-httplib2 google-api-python-client

USAGE:
  # Fetch all .md files from your shared folder
  python fetch_drive_to_inputs.py --folder-id 1SMlbSBhQE9ClYo2uqdzPEhd3aopYVlzV

  # Preview without writing
  python fetch_drive_to_inputs.py --folder-id 1SMlbSBhQE9ClYo2uqdzPEhd3aopYVlzV --dry-run

  # Write to a separate file
  python fetch_drive_to_inputs.py --folder-id 1SMlbSBhQE9ClYo2uqdzPEhd3aopYVlzV --output inputs-voice.json

TRANSCRIPT EXTRACTION:
  Looks for "## Transcript" or "📝 TRANSCRIPT:" section in markdown.
  Pulls everything from that marker until the next ## header or end of file.
  Falls back to full file content if no section marker found.

FIRST RUN:
  On first run, you'll be asked to authenticate with Google. A browser will open.
  Credentials are cached in ~/.cache/flan-t5-fetch-drive.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# Deferred import — fail gracefully if dependencies missing
def _init_drive():
    try:
        from google.auth.transport.requests import Request
        from google.oauth2.service_account import Credentials
        from google.oauth2.credentials import Credentials as UserCredentials
        from google_auth_oauthlib.flow import InstalledAppFlow
        from googleapiclient.discovery import build
        from googleapiclient.errors import HttpError
        return {
            'Request': Request,
            'Credentials': Credentials,
            'UserCredentials': UserCredentials,
            'InstalledAppFlow': InstalledAppFlow,
            'build': build,
            'HttpError': HttpError,
        }
    except ImportError as e:
        print(f"Missing dependencies. Install with:\n  pip install google-auth-oauthlib google-auth-httplib2 google-api-python-client",
              file=sys.stderr)
        sys.exit(1)

HERE = Path(__file__).parent
INPUTS = HERE / "inputs.json"
CACHE_DIR = Path.home() / ".cache"
TOKEN_PATH = CACHE_DIR / "flan-t5-fetch-drive.json"
SCOPES = ["https://www.googleapis.com/auth/drive.readonly"]

# Google Drive OAuth client ID (from Google Cloud Console)
# If you don't have one, create it at https://console.cloud.google.com/
CLIENT_ID = "YOUR_CLIENT_ID.apps.googleusercontent.com"
CLIENT_SECRET = "YOUR_CLIENT_SECRET"


def kebab(stem: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9]+", "-", stem.strip().lower())
    return re.sub(r"-+", "-", s).strip("-") or "entry"


def extract_transcript(content: str) -> str:
    """
    Pull transcript from markdown.
    Looks for '## Transcript', '📝 TRANSCRIPT:', or uses full content.
    """
    lines = content.split("\n")

    # Try to find a transcript section
    markers = ["## Transcript", "# Transcript", "📝 TRANSCRIPT:", "TRANSCRIPT:"]
    for marker in markers:
        for i, line in enumerate(lines):
            if marker in line:
                # Collect lines after marker until next ## header or end
                collected = []
                for j in range(i + 1, len(lines)):
                    s = lines[j].strip()
                    # Stop at next header
                    if s.startswith("#"):
                        break
                    # Skip leading blanks, collect content
                    if s and not s.startswith("---"):
                        collected.append(s)
                text = " ".join(collected).strip()
                if text:
                    return text

    # Fallback: use full content, strip headers and metadata
    collected = []
    for line in lines:
        s = line.strip()
        # Skip headers, separators, metadata lines
        if s.startswith("#") or s.startswith("**") or s.startswith("---") or s.startswith("["):
            continue
        if s and not s.startswith("-"):  # skip bullet points (action items)
            collected.append(s)

    text = " ".join(collected).strip()
    return text or content.strip()


def authenticate() -> object:
    """Get authenticated Drive service. Caches credentials."""
    drive_lib = _init_drive()

    creds = None
    if TOKEN_PATH.exists():
        creds = drive_lib['UserCredentials'].from_authorized_user_file(TOKEN_PATH, SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(drive_lib['Request']())
        else:
            # You would need to set up OAuth credentials first
            print("ERROR: Google Drive authentication not set up.", file=sys.stderr)
            print("To use this script, set up OAuth 2.0 credentials in Google Cloud Console:", file=sys.stderr)
            print("  1. https://console.cloud.google.com/ → Create a project", file=sys.stderr)
            print("  2. APIs → Google Drive API → Enable", file=sys.stderr)
            print("  3. OAuth Consent Screen → Create credentials (Desktop app)", file=sys.stderr)
            print("  4. Download JSON and update CLIENT_ID/CLIENT_SECRET in this script", file=sys.stderr)
            print("OR use gdown (simpler): pip install gdown && gdown --folder <folder-url>", file=sys.stderr)
            sys.exit(1)

        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        with open(TOKEN_PATH, "w") as token:
            token.write(creds.to_json())

    return drive_lib['build']('drive', 'v3', credentials=creds)


def list_md_files(drive_service, folder_id: str) -> list[dict]:
    """List all .md files in a Drive folder."""
    try:
        query = f"'{folder_id}' in parents and name contains '.md' and trashed = false"
        results = drive_service.files().list(
            q=query,
            spaces='drive',
            fields='files(id, name, modifiedTime)',
            pageSize=100
        ).execute()
        return results.get('files', [])
    except Exception as e:
        print(f"Error listing files: {e}", file=sys.stderr)
        return []


def download_file(drive_service, file_id: str) -> str | None:
    """Download file content as text."""
    try:
        from googleapiclient.http import MediaIoBaseDownload
        import io
        request = drive_service.files().get_media(fileId=file_id)
        fh = io.BytesIO()
        downloader = MediaIoBaseDownload(fh, request)
        done = False
        while not done:
            _, done = downloader.next_chunk()
        return fh.getvalue().decode('utf-8', errors='replace')
    except Exception as e:
        print(f"Error downloading {file_id}: {e}", file=sys.stderr)
        return None


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--folder-id", required=True, help="Google Drive folder ID")
    ap.add_argument("--output", default=str(INPUTS), help="JSON to merge into (default: inputs.json)")
    ap.add_argument("--overwrite", action="store_true", help="replace entries whose id already exists")
    ap.add_argument("--dry-run", action="store_true", help="print result, do not write")
    args = ap.parse_args()

    print(f"Authenticating with Google Drive...", file=sys.stderr)
    drive = authenticate()

    print(f"Listing .md files in folder {args.folder_id}...", file=sys.stderr)
    files = list_md_files(drive, args.folder_id)

    if not files:
        print("No markdown files found in folder.", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(files)} markdown file(s). Downloading...", file=sys.stderr)

    out_path = Path(args.output)
    existing = json.loads(out_path.read_text()) if out_path.exists() else []
    by_id = {e["id"]: e for e in existing}
    order = [e["id"] for e in existing]

    added, skipped = 0, 0
    for f in files:
        eid = kebab(f["name"].replace(".md", ""))
        if eid in by_id and not args.overwrite:
            print(f"  · id '{eid}' exists — skip (use --overwrite to replace)", file=sys.stderr)
            skipped += 1
            continue

        content = download_file(drive, f["id"])
        if not content:
            skipped += 1
            continue

        transcript = extract_transcript(content)
        entry = {"id": eid, "note": f"voice import · {f['name']}", "transcript": transcript}

        if eid not in by_id:
            order.append(eid)
        by_id[eid] = entry
        added += 1
        print(f"  ✓ {eid}: {transcript[:80]}{'…' if len(transcript) > 80 else ''}", file=sys.stderr)

    merged = [by_id[i] for i in order]

    if args.dry_run:
        print(json.dumps(merged, indent=2, ensure_ascii=False))
    else:
        out_path.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n")
        print(f"\nWrote {out_path}  (+{added} added, {skipped} skipped, {len(merged)} total)",
              file=sys.stderr)


if __name__ == "__main__":
    main()
