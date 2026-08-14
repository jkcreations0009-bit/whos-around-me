#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

EXPECTED_CONFIRMATION = "DEPLOY_WHO_S_AROUND_ME_DEVELOPMENT"


def fail(message: str) -> None:
    print(f"BLOCKED: {message}", file=sys.stderr)
    raise SystemExit(2)


def main() -> None:
    confirmation = os.environ.get("PHASE8E_DEPLOY_CONFIRMATION", "")
    if confirmation != EXPECTED_CONFIRMATION:
        fail("explicit development-deploy confirmation is missing or incorrect")

    project_id = os.environ.get("FIREBASE_PROJECT_ID_DEV", "").strip()
    if not project_id:
        fail("FIREBASE_PROJECT_ID_DEV is missing")
    if project_id.startswith("demo-"):
        fail("demo Firebase projects are not valid deployment targets")

    credentials_path_raw = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
    if not credentials_path_raw:
        fail("GOOGLE_APPLICATION_CREDENTIALS is missing")
    credentials_path = Path(credentials_path_raw)
    if not credentials_path.is_file():
        fail("service-account credential file does not exist")

    try:
        credentials = json.loads(credentials_path.read_text())
    except Exception as error:  # noqa: BLE001 - CLI boundary must fail closed.
        fail(f"service-account JSON is invalid: {type(error).__name__}")

    if credentials.get("type") != "service_account":
        fail("credential JSON is not a service-account key")
    credential_project = str(credentials.get("project_id", "")).strip()
    if credential_project != project_id:
        fail("service-account project_id does not match FIREBASE_PROJECT_ID_DEV")
    if not str(credentials.get("client_email", "")).endswith(".gserviceaccount.com"):
        fail("credential client_email is not a Google service account")
    if not str(credentials.get("private_key", "")).startswith("-----BEGIN PRIVATE KEY-----"):
        fail("credential private key is missing")

    print("PASS: explicit development deployment confirmation")
    print("PASS: non-demo Firebase development project id")
    print("PASS: service-account credential structure")
    print("PASS: credential project matches deployment target")
    print("PASS: no credential values printed")


if __name__ == "__main__":
    main()
