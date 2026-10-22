#!/usr/bin/env python3
"""App Store Connect signing helper for the TestFlight workflow.

Runs on the GitHub macOS runner. Authenticates with an App Store Connect API key
(env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8). Never prints secrets.

  create-cert  Create an Apple Distribution certificate (first run only) and
               write it with its private key to a password-protected .p12.
  profiles     (Re)create App Store provisioning profiles for the app and the
               widget, install them, and check they contain the App Group.
  write-key    Write the API key (normalized) to a .p8 file for xcodebuild.
"""
import argparse
import base64
import json
import os
import plistlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import jwt
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID

API = os.environ.get("ASC_API_BASE", "https://api.appstoreconnect.apple.com/v1")


def fail(message: str) -> None:
    print(f"::error::{message}")
    sys.exit(1)


def private_key_text() -> str:
    raw = os.environ.get("ASC_KEY_P8", "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not raw:
        fail("ASC_KEY_P8 is empty.")
    if "BEGIN PRIVATE KEY" not in raw:
        body = "".join(raw.split())
        lines = [body[i:i + 64] for i in range(0, len(body), 64)]
        raw = "-----BEGIN PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END PRIVATE KEY-----"
    return raw + "\n"


def token() -> str:
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"].strip(), "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        private_key_text(),
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"].strip(), "typ": "JWT"},
    )


def call(method: str, path: str, body=None, params=None):
    url = API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + token(),
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        hint = ""
        if error.code == 401:
            hint = " Check ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8."
        elif error.code == 403:
            hint = " The API key needs the Admin role."
        fail(f"App Store Connect API {method} {path} -> HTTP {error.code}.{hint}\n{detail}")


# ---------------------------------------------------------------- create-cert

def cmd_create_cert(args) -> None:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "WidgetSimple CI")]))
           .sign(key, hashes.SHA256()))
    csr_pem = csr.public_bytes(serialization.Encoding.PEM).decode()

    result = call("POST", "/certificates", {"data": {
        "type": "certificates",
        "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr_pem},
    }})
    cert = x509.load_der_x509_certificate(base64.b64decode(result["data"]["attributes"]["certificateContent"]))

    # 3DES/SHA1 so macOS `security import` accepts it.
    encryption = (serialization.PrivateFormat.PKCS12.encryption_builder()
                  .kdf_rounds(50000)
                  .key_cert_algorithm(pkcs12.PBES.PBESv1SHA1And3KeyTripleDESCBC)
                  .hmac_hash(hashes.SHA1())
                  .build(args.password.encode()))
    data = pkcs12.serialize_key_and_certificates(b"WidgetSimple CI", key, cert, None, encryption)
    Path(args.out).write_bytes(data)
    print(f"Created Apple Distribution certificate (id {result['data']['id']}, expires {cert.not_valid_after_utc:%Y-%m-%d}).")


# ---------------------------------------------------------------- profiles

def load_certificate(p12_path: str, password: str) -> x509.Certificate:
    _, cert, _ = pkcs12.load_key_and_certificates(Path(p12_path).read_bytes(), password.encode())
    if cert is None:
        fail("The stored .p12 contains no certificate.")
    return cert


def certificate_id(cert: x509.Certificate) -> str:
    wanted = format(cert.serial_number, "X").lstrip("0")
    result = call("GET", "/certificates", params={"limit": 200})
    for item in result.get("data", []):
        serial = (item["attributes"].get("serialNumber") or "").upper().lstrip("0")
        if serial == wanted:
            return item["id"]
    fail("The stored signing certificate no longer exists in your developer account "
         "(revoked or expired). Delete the SIGNING_P12_BASE64 and SIGNING_P12_PASSWORD "
         "repository secrets and run the workflow again to create a new one.")


def bundle_id_resource(identifier: str) -> str:
    result = call("GET", "/bundleIds", params={"filter[identifier]": identifier, "limit": 200})
    for item in result.get("data", []):
        if item["attributes"].get("identifier") == identifier:
            return item["id"]
    fail(f"Bundle ID {identifier} is not registered. Create it at developer.apple.com "
         f"› Identifiers › + › App IDs, with the App Groups capability.")


def profile_entitlements(content: bytes) -> dict:
    match = re.search(rb"<\?xml.*?</plist>", content, re.S)
    if not match:
        return {}
    return plistlib.loads(match.group(0)).get("Entitlements", {})


def install_profile(name: str, bundle: str, cert_id: str, group: str, outdir: Path) -> None:
    bundle_rid = bundle_id_resource(bundle)
    existing = call("GET", "/profiles", params={"filter[name]": name, "limit": 200})
    for item in existing.get("data", []):
        if item["attributes"].get("name") == name:
            call("DELETE", f"/profiles/{item['id']}")

    result = call("POST", "/profiles", {"data": {
        "type": "profiles",
        "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle_rid}},
            "certificates": {"data": [{"type": "certificates", "id": cert_id}]},
        },
    }})
    attributes = result["data"]["attributes"]
    content = base64.b64decode(attributes["profileContent"])
    groups = profile_entitlements(content).get("com.apple.security.application-groups", [])
    if group not in groups:
        fail(f"The App ID {bundle} is not linked to the App Group {group}. "
             f"At developer.apple.com › Identifiers › {bundle} › App Groups › Configure, "
             f"tick {group}, save, and run the workflow again.")

    uuid = attributes["uuid"]
    for folder in (Path.home() / "Library/MobileDevice/Provisioning Profiles",
                   Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
                   outdir):
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{uuid}.mobileprovision").write_bytes(content)
    print(f"Installed profile '{name}' for {bundle}.")


def cmd_profiles(args) -> None:
    cert = load_certificate(args.p12, args.password)
    cert_id = certificate_id(cert)
    outdir = Path(args.outdir)
    install_profile(args.app_profile, args.app, cert_id, args.group, outdir)
    install_profile(args.widget_profile, args.widget, cert_id, args.group, outdir)


def cmd_write_key(args) -> None:
    path = Path(args.out)
    path.write_text(private_key_text())
    path.chmod(0o600)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("create-cert")
    create.add_argument("--out", required=True)
    create.add_argument("--password", required=True)
    create.set_defaults(func=cmd_create_cert)

    profiles = sub.add_parser("profiles")
    profiles.add_argument("--p12", required=True)
    profiles.add_argument("--password", required=True)
    profiles.add_argument("--app", required=True)
    profiles.add_argument("--widget", required=True)
    profiles.add_argument("--group", required=True)
    profiles.add_argument("--app-profile", default="WidgetSimple CI App")
    profiles.add_argument("--widget-profile", default="WidgetSimple CI Widget")
    profiles.add_argument("--outdir", required=True)
    profiles.set_defaults(func=cmd_profiles)

    write_key = sub.add_parser("write-key", help="Write the API key as a .p8 file for xcodebuild")
    write_key.add_argument("--out", required=True)
    write_key.set_defaults(func=cmd_write_key)

    args = parser.parse_args()
    for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8"):
        if not os.environ.get(name, "").strip():
            fail(f"Repository secret {name} is missing.")
    args.func(args)


if __name__ == "__main__":
    main()
