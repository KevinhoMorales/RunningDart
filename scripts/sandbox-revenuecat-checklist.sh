#!/usr/bin/env bash
# Checklist imprimible para prueba sandbox de Pro Team en dispositivo real.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/config/revenuecat_catalog.json"
PRODUCT_ID="$(python3 -c "import json; print(json.load(open('$CATALOG'))['product']['id'])")"
ENTITLEMENT="$(python3 -c "import json; print(json.load(open('$CATALOG'))['entitlementId'])")"

cat <<EOF
SAINTS — RevenueCat sandbox checklist
=====================================
Product:      $PRODUCT_ID
Entitlement:  $ENTITLEMENT
Bundle/pkg:   com.devlokos.runningdart (.dev for flavor dev)

Before device test
  [ ] App Store / Play product $PRODUCT_ID exists
  [ ] RevenueCat apps linked + offering/paywall live
  [ ] ./scripts/setup-revenuecat.sh completed (secret + function deployed)
  [ ] ./scripts/verify-revenuecat-setup.sh passes
  [ ] config/env/{dev|prod}.json has REVENUECAT_API_KEY (public SDK key)

iOS
  [ ] Sandbox Tester signed in (Settings → App Store → Sandbox)
  [ ] Or run via Xcode scheme with RevenueCat.storekit
  [ ] flutter run --flavor prod --dart-define-from-file=config/env/prod.json

Android
  [ ] License tester account on device
  [ ] Internal/closed testing build installed (or debug with license tester)
  [ ] flutter run --flavor prod --dart-define-from-file=config/env/prod.json

In-app
  [ ] Login with Firebase user (UID = RevenueCat app_user_id)
  [ ] Open Suscribirme a Pro Team (Settings / pending / upsell)
  [ ] Complete sandbox purchase
  [ ] Confirm entitlement active in RevenueCat Customer View
  [ ] Firestore environments/{env}/users/{uid}:
        membershipModality == proTeam
        membershipStatus == active
        role == member
  [ ] payments note contains "RevenueCat IAP"
  [ ] Restore purchases works
  [ ] Customer Center opens from Settings

Automated (no device)
  [ ] cd functions && node --test test/revenue_cat_membership.test.js
  [ ] flutter test test/revenue_cat_config_test.dart
EOF
