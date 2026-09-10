#!/usr/bin/env bash
# DEPRECATED: Pro Team / IAP sandbox checklist (product path removed in point 4).
# Kept for historical RevenueCat setup notes; do not treat as active product UX.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$ROOT/config/revenuecat_catalog.json"
PRODUCT_ID="$(python3 -c "import json; print(json.load(open('$CATALOG'))['product']['id'])")"
ENTITLEMENT="$(python3 -c "import json; print(json.load(open('$CATALOG'))['entitlementId'])")"

cat <<EOF
SAINTS — RevenueCat sandbox checklist (DEPRECATED — Pro Team retired)
=====================================
Product:      $PRODUCT_ID
Entitlement:  $ENTITLEMENT
Bundle/pkg:   com.devlokos.runningdart (.dev for flavor dev)

NOTE: App no longer offers Pro Team. Official is admin-activated (USD 5/mes
product copy only; IAP not shipped). Use this script only for legacy RC ops.

Before device test
  [ ] App Store / Play product $PRODUCT_ID exists
  [ ] RevenueCat apps linked + offering/paywall live
  [ ] ./scripts/setup-revenuecat.sh completed (secret + function deployed)
  [ ] ./scripts/verify-revenuecat-setup.sh passes
  [ ] config/env/{dev|prod}.json has REVENUECAT_API_KEY (public SDK key)

In-app (legacy expectations — superseded)
  [ ] Login with Firebase user (UID = RevenueCat app_user_id)
  [ ] (retired) Open Suscribirme a Pro Team
  [ ] Complete sandbox purchase
  [ ] Confirm entitlement active in RevenueCat Customer View
  [ ] Firestore environments/{env}/users/{uid}:
        membershipModality == official   # legacy proTeam mapped on read
        membershipStatus == active
        role == member
EOF
