#!/usr/bin/env bash
# scripts/check_docs.sh — Stale-doc check for CurveShellFEM
# Part of the v4.1 Documentation-as-Code (DaC) enforcement layer.
#
# Checks that for every src/ file modified since the last phase gate,
# a corresponding session log exists with:
#   1. A "Date opened:" timestamp BEFORE the earliest src/ modification
#   2. A non-empty Objective section
#   3. A non-empty Mathematical derivation section (or explicit N/A)
#
# Exit codes:
#   0 = PASS — docs are current
#   1 = FAIL — stale documentation detected
#
# Usage:
#   bash scripts/check_docs.sh [--phase N]
#   bash scripts/check_docs.sh --help
#
# Called by:
#   - FEM Engineer before Gate 1 request
#   - Verification Engineer as part of Tier 4 data integrity
#   - Project Scribe during WF-06 sync
# -----------------------------------------------------------------------

set -euo pipefail

PHASE="${1:-}"
SESSIONS_DIR="docs/dev_logs/sessions"
SRC_DIR="src"
PASS=0
FAIL=1
issues=0

echo "=== CurveShellFEM Stale-Doc Check (v4.1) ==="
echo "Checking: $SESSIONS_DIR vs $SRC_DIR"
echo ""

# -----------------------------------------------------------------------
# 1. Find the most recently modified src/ file
# -----------------------------------------------------------------------
latest_src=$(find "$SRC_DIR" -name "*.m" -newer "$SESSIONS_DIR" 2>/dev/null | head -1)

if [ -z "$latest_src" ]; then
    echo "[PASS] No src/ files modified since last session log."
    exit $PASS
fi

echo "[INFO] src/ modifications detected since last session log."
echo "       Most recent: $latest_src"
echo ""

# -----------------------------------------------------------------------
# 2. Find session log for this phase
# -----------------------------------------------------------------------
if [ -n "$PHASE" ]; then
    session_log=$(find "$SESSIONS_DIR" -name "*Phase${PHASE}*FEM_Engineer*" 2>/dev/null | tail -1)
else
    # Most recent session log
    session_log=$(ls -t "$SESSIONS_DIR"/*.md 2>/dev/null | head -1)
fi

if [ -z "$session_log" ]; then
    echo "[FAIL] No session log found in $SESSIONS_DIR"
    echo "       Log-first rule violated — session log must exist before src/ changes."
    exit $FAIL
fi

echo "[INFO] Session log found: $session_log"
echo ""

# -----------------------------------------------------------------------
# 3. Check "Date opened" precedes earliest src/ modification
# -----------------------------------------------------------------------
date_opened=$(grep "Date opened" "$session_log" | head -1 | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" | head -1)

if [ -z "$date_opened" ]; then
    echo "[FAIL] 'Date opened' field is missing from session log."
    echo "       Add: **Date opened**: YYYY-MM-DD to the log header."
    issues=$((issues + 1))
else
    echo "[INFO] Session log 'Date opened': $date_opened"
    # Find earliest src/ modification date
    # Note: 'date -r' is macOS; use 'stat -c %y' on Linux
    earliest_src_date=$(find "$SRC_DIR" -name "*.m" -newer "$session_log" 2>/dev/null \
        | xargs stat -c "%y %n" 2>/dev/null \
        | sort | head -1 | cut -d' ' -f1)

    if [ -n "$earliest_src_date" ] && [[ "$earliest_src_date" < "$date_opened" ]]; then
        echo "[FAIL] src/ files were modified BEFORE the session log was opened."
        echo "       Earliest src/ change: $earliest_src_date"
        echo "       Session log opened:   $date_opened"
        echo "       Log-first rule violated."
        issues=$((issues + 1))
    else
        echo "[PASS] Session log opened before or at first src/ modification."
    fi
fi

# -----------------------------------------------------------------------
# 4. Check Objective section is non-empty
# -----------------------------------------------------------------------
objective_content=$(awk '/^## 1\. Objective/,/^## 2\./' "$session_log" 2>/dev/null | grep -v "^##" | grep -v "^\[" | grep -v "^$" | head -3)

if [ -z "$objective_content" ]; then
    echo "[FAIL] Objective section is empty or contains only placeholder text."
    echo "       Fill section 1 (Objective) with the verbatim text from the task brief."
    issues=$((issues + 1))
else
    echo "[PASS] Objective section is populated."
fi

# -----------------------------------------------------------------------
# 5. Check Mathematical derivation section (or explicit N/A)
# -----------------------------------------------------------------------
deriv_content=$(awk '/^## 3\. Mathematical derivation/,/^## 4\./' "$session_log" 2>/dev/null | grep -v "^##" | grep -v "^\[" | grep -v "^$" | head -3)

if [ -z "$deriv_content" ]; then
    echo "[FAIL] Mathematical derivation section (section 3) is empty."
    echo "       Either fill it with the derivation, or write 'N/A — no physics change.'"
    issues=$((issues + 1))
else
    echo "[PASS] Mathematical derivation section is populated."
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "=== Summary ==="
if [ "$issues" -eq 0 ]; then
    echo "PASS — All documentation checks passed."
    exit $PASS
else
    echo "FAIL — $issues issue(s) found. Fix before requesting Gate 1."
    exit $FAIL
fi
