#!/bin/bash
set -euo pipefail

# ============================================
# FamilyPulse — Build, Upload & TestFlight Setup
# ============================================
# Usage:  ./scripts/build-and-deploy.sh
#         ./scripts/build-and-deploy.sh --upload-only   # skip archive, upload latest existing
# Prereq: Xcode, PyJWT (pip3 install PyJWT)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_DIR/FamilyPulse.xcodeproj/project.pbxproj"
WORKSPACE="$PROJECT_DIR/FamilyPulse.xcworkspace"
SCHEME="FamilyPulse_Release"
EXPORT_OPTIONS="$PROJECT_DIR/ExportOptions.plist"
ARCHIVE_PATH="/tmp/FamilyPulse.xcarchive"
EXPORT_PATH="/tmp/FamilyPulseIPA"
XCODE_ARCHIVES_DIR="$HOME/Library/Developer/Xcode/Archives"

# App Store Connect config
APP_ID="6776137268"
GROUP_ID="5d994b69-cda5-416e-a27e-a678fcf74e36"
KEY_ID="7GUN8L4659"
ISSUER_ID="684113e3-cb4d-44fc-ae75-881cd99b73bb"
KEY_PATH="/Users/keria/Downloads/AuthKey_7GUN8L4659.p8"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${BLUE}==>${NC} $1"; }
ok()    { echo -e "${GREEN}✅${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠️ $1${NC}"; }

get_build_number_from_archive() {
    local archive="$1"
    /usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "$archive/Info.plist" 2>/dev/null || echo ""
}

# ---- Find or create archive ----
UPLOAD_ONLY="${1:-}"

NEW_BUILD_NUMBER=""

if [ "$UPLOAD_ONLY" = "--upload-only" ]; then
    # Find the latest xcarchive from Xcode's archives
    LATEST_ARCHIVE=$(find "$XCODE_ARCHIVES_DIR" -name "*.xcarchive" -type d -maxdepth 2 2>/dev/null \
        | sort -r | head -1)

    if [ -z "$LATEST_ARCHIVE" ]; then
        warn "No existing archive found. Doing full build instead."
    else
        ARCHIVE_PATH="$LATEST_ARCHIVE"
        NEW_BUILD_NUMBER=$(get_build_number_from_archive "$ARCHIVE_PATH")
        info "Using existing archive: $(basename "$ARCHIVE_PATH") (Build $NEW_BUILD_NUMBER)"
    fi
fi

if [ -z "$NEW_BUILD_NUMBER" ]; then
    # ---- 1. Increment build number ----
    info "Incrementing build number..."
    CURRENT=$(grep -m1 "CURRENT_PROJECT_VERSION" "$PROJECT_FILE" | sed 's/.*= //;s/;//')
    NEW_BUILD_NUMBER=$((CURRENT + 1))
    sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT;/CURRENT_PROJECT_VERSION = $NEW_BUILD_NUMBER;/g" "$PROJECT_FILE"
    ok "Build number: $CURRENT → $NEW_BUILD_NUMBER"

    # ---- 2. Archive ----
    info "Archiving ($SCHEME)..."
    rm -rf "$ARCHIVE_PATH"
    xcodebuild archive \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -archivePath "$ARCHIVE_PATH" \
        -allowProvisioningUpdates \
        -quiet
    ok "Archive done"
fi

# ---- 3. Export IPA ----
info "Exporting IPA..."
rm -rf "$EXPORT_PATH"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    -quiet
ok "IPA exported"

# ---- 4. Upload via altool ----
info "Uploading to App Store Connect..."
IPA=$(find "$EXPORT_PATH" -name "*.ipa" | head -1)
if [ -z "$IPA" ]; then
    warn "IPA not found in $EXPORT_PATH"
    exit 1
fi

xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$KEY_ID" \
    --apiIssuer "$ISSUER_ID" \
    --apiKeyPath "$KEY_PATH" \
    --verbose 2>&1 | tail -5
ok "Uploaded to App Store Connect"

# ---- 5. Poll for new build ----
info "Waiting for Build $NEW_BUILD_NUMBER to appear in App Store Connect..."
INTERVAL=30
MAX_RETRIES=40
RETRY=0
BUILD_JSON=""
BUILD_ID=""

while [ $RETRY -lt $MAX_RETRIES ]; do
    BUILD_JSON=$(python3 -c "
import jwt, time, json
KEY_ID = '$KEY_ID'
ISSUER_ID = '$ISSUER_ID'
KEY_PATH = '$KEY_PATH'
with open(KEY_PATH) as f:
    pk = f.read()
payload = {'iss': ISSUER_ID, 'iat': int(time.time()), 'exp': int(time.time()) + 300, 'aud': 'appstoreconnect-v1'}
token = jwt.encode(payload, pk, algorithm='ES256', headers={'kid': KEY_ID})
import urllib.request
req = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/builds?filter[app]=$APP_ID&sort=-uploadedDate&limit=5&fields[builds]=version,processingState')
req.add_header('Authorization', f'Bearer {token}')
resp = urllib.request.urlopen(req)
data = json.loads(resp.read())
for b in data['data']:
    if b['attributes']['version'] == '$NEW_BUILD_NUMBER':
        print(json.dumps(b))
        break
" 2>/dev/null || true)

    if [ -n "$BUILD_JSON" ]; then
        STATE=$(echo "$BUILD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['attributes']['processingState'])" 2>/dev/null)
        BUILD_ID=$(echo "$BUILD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
        ok "Build $NEW_BUILD_NUMBER found (State: $STATE, ID: $BUILD_ID)"
        break
    fi

    RETRY=$((RETRY + 1))
    if [ $RETRY -ge $MAX_RETRIES ]; then
        warn "Build $NEW_BUILD_NUMBER didn't appear after 20 minutes. Check App Store Connect manually."
        exit 1
    fi
    sleep $INTERVAL
done

# ---- 6. Set export compliance ----
info "Setting export compliance..."
python3 -c "
import jwt, time, json
KEY_ID = '$KEY_ID'
ISSUER_ID = '$ISSUER_ID'
KEY_PATH = '$KEY_PATH'
with open(KEY_PATH) as f:
    pk = f.read()
payload = {'iss': ISSUER_ID, 'iat': int(time.time()), 'exp': int(time.time()) + 300, 'aud': 'appstoreconnect-v1'}
token = jwt.encode(payload, pk, algorithm='ES256', headers={'kid': KEY_ID})
import urllib.request
data = json.dumps({'data': {'type': 'builds', 'id': '$BUILD_ID', 'attributes': {'usesNonExemptEncryption': False}}}).encode()
req = urllib.request.Request(f'https://api.appstoreconnect.apple.com/v1/builds/$BUILD_ID', data=data, method='PATCH')
req.add_header('Authorization', f'Bearer {token}')
req.add_header('Content-Type', 'application/json')
resp = urllib.request.urlopen(req)
print(f'Status: {resp.status}')
" 2>/dev/null
ok "Export compliance set"

# ---- 7. Assign to beta group ----
info "Assigning to beta group..."
python3 -c "
import jwt, time, json
KEY_ID = '$KEY_ID'
ISSUER_ID = '$ISSUER_ID'
KEY_PATH = '$KEY_PATH'
with open(KEY_PATH) as f:
    pk = f.read()
payload = {'iss': ISSUER_ID, 'iat': int(time.time()), 'exp': int(time.time()) + 300, 'aud': 'appstoreconnect-v1'}
token = jwt.encode(payload, pk, algorithm='ES256', headers={'kid': KEY_ID})
import urllib.request
data = json.dumps({'data': [{'type': 'builds', 'id': '$BUILD_ID'}]}).encode()
req = urllib.request.Request(f'https://api.appstoreconnect.apple.com/v1/betaGroups/$GROUP_ID/relationships/builds', data=data, method='POST')
req.add_header('Authorization', f'Bearer {token}')
req.add_header('Content-Type', 'application/json')
resp = urllib.request.urlopen(req)
print(f'Status: {resp.status}')
" 2>/dev/null
ok "Assigned to external testers group"

# ---- 8. Submit for beta review ----
info "Submitting for beta review..."
RESULT=$(python3 -c "
import jwt, time, json
KEY_ID = '$KEY_ID'
ISSUER_ID = '$ISSUER_ID'
KEY_PATH = '$KEY_PATH'
with open(KEY_PATH) as f:
    pk = f.read()
payload = {'iss': ISSUER_ID, 'iat': int(time.time()), 'exp': int(time.time()) + 300, 'aud': 'appstoreconnect-v1'}
token = jwt.encode(payload, pk, algorithm='ES256', headers={'kid': KEY_ID})
import urllib.request
data = json.dumps({'data': {'type': 'betaAppReviewSubmissions', 'relationships': {'build': {'data': {'type': 'builds', 'id': '$BUILD_ID'}}}}}).encode()
req = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/betaAppReviewSubmissions', data=data, method='POST')
req.add_header('Authorization', f'Bearer {token}')
req.add_header('Content-Type', 'application/json')
resp = urllib.request.urlopen(req)
body = json.loads(resp.read())
print(body['data']['attributes'].get('betaReviewState', '?'))
" 2>/dev/null)
ok "Beta review submitted — State: $RESULT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build $NEW_BUILD_NUMBER all done! 🚀${NC}"
echo -e "${GREEN}========================================${NC}"
