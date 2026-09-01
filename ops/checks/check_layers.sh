#!/usr/bin/env bash
# internal/domain must stay pure: no imports from app, store, http, or platform.
set -euo pipefail

MODULE="github.com/PivotSolutions-dev/civicsync/api"

cd "$(dirname "$0")/../../api"

if [ ! -d internal/domain ]; then
    echo "check_layers: internal/domain not present yet, skipping"
    exit 0
fi

violations=$(go list -deps ./internal/domain/... 2>/dev/null \
    | grep -E "^${MODULE}/internal/(app|store|http|platform)" || true)

if [ -n "$violations" ]; then
    echo "LAYER VIOLATION — internal/domain must not import:"
    echo "$violations" | sed 's/^/  /'
    echo
    echo "Dependency rule: http -> app -> domain, app -> store. domain imports nothing."
    exit 1
fi

echo "Layer check passed."
