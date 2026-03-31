#!/bin/bash
# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
# @description: Test script to verify release notes generation logic

echo "=== Testing Release Notes Generation Logic ==="
echo

# Test 1: Beta tag detection
echo "[Test 1] Beta Tag Detection"
echo "Testing pattern matching for *-beta.*"

test_beta_detection() {
    local tag="$1"
    if [[ "$tag" == *"-beta."* ]]; then
        echo "  [OK] '$tag' -> Beta release detected"
    else
        echo "  [OK] '$tag' -> Stable release detected"
    fi
}

test_beta_detection "v0.2.2-beta.1"
test_beta_detection "v0.2.2-beta.44"
test_beta_detection "v1.0.0-beta.5"
test_beta_detection "v0.2.2"
test_beta_detection "v1.0.0"
echo

# Test 2: Conventional commit parsing
echo "[Test 2] Conventional Commit Pattern Matching"

test_commit() {
    local commit="$1"
    if [[ "$commit" =~ ^([a-zA-Z]+)(\([a-zA-Z0-9/_-]+\))?:\ (.+)$ ]]; then
        local type="${BASH_REMATCH[1]}"
        local scope="${BASH_REMATCH[2]}"
        local desc="${BASH_REMATCH[3]}"
        
        local section=""
        case "$type" in
            feat|feature) section="Added" ;;
            fix) section="Fixed" ;;
            perf) section="Changed" ;;
            refactor) section="Changed" ;;
            docs) section="Documentation" ;;
            test) section="Testing" ;;
            chore|ci|build) section="Maintenance" ;;
            break*) section="Breaking Changes" ;;
            *) section="Other" ;;
        esac
        
        echo "  [OK] '$commit'"
        echo "       -> Section: $section, Description: $desc"
    else
        echo "  [WARN] '$commit' -> No match (will use raw format)"
    fi
}

test_commit "feat(ui): add new fader component"
test_commit "fix(midi): resolve UMP reconstruction bug"
test_commit "chore(deps): update dependencies"
test_commit "docs(readme): update installation instructions"
test_commit "test(unit): add unit tests for MidiEvent"
test_commit "refactor(core): improve state management"
test_commit "perf(midi): reduce latency by 20%"
test_commit "ci(workflow): optimize build pipeline"
test_commit "Random commit without conventional format"
echo

# Test 3: Git log retrieval
echo "[Test 3] Git Log Retrieval"
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "  [OK] Inside git repository"
    echo "  Recent commits:"
    git log --oneline -5 --no-decorate | while read -r line; do
        echo "    - $line"
    done
else
    echo "  [ERROR] Not a git repository"
fi
echo

# Test 4: Tag detection
echo "[Test 4] Git Tag Detection"
LATEST_TAG=$(git describe --tags --match='v[0-9]*.[0-9]*.[0-9]*' --abbrev=0 2>/dev/null || echo "")

if [ -n "$LATEST_TAG" ]; then
    echo "  [OK] Latest production tag: $LATEST_TAG"
    
    BETA_NUM=$(git rev-list --count "$LATEST_TAG"..HEAD)
    echo "  [OK] Commits since last tag: $BETA_NUM"
    
    VERSION="${LATEST_TAG#v}"
    BETA_TAG="v${VERSION}-beta.${BETA_NUM}"
    echo "  [OK] Generated beta tag would be: $BETA_TAG"
else
    echo "  [WARN] No production tags found (first release)"
fi
echo

# Test 5: Simulate release notes generation
echo "[Test 5] Simulated Beta Release Notes Generation"
echo "==============================================="

TAG="v0.2.2-beta.${BETA_NUM:-1}"
echo "Simulating tag: $TAG"
echo

PREV_TAG=$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || git describe --tags --match='v[0-9]*.[0-9]*.[0-9]*' --abbrev=0 2>/dev/null || echo "")

if [ -n "$PREV_TAG" ]; then
    echo "Previous tag: $PREV_TAG"
    echo
    echo "Release Notes Preview:"
    echo "---------------------"
    echo "🚧 **Beta Release** - This is a release candidate for testing."
    echo
    echo "### Changes since $PREV_TAG"
    echo
    
    # Show what would be parsed
    git log --pretty=format:"%s" "$PREV_TAG"..HEAD 2>/dev/null | head -10 | while read -r commit_msg; do
        if [[ "$commit_msg" =~ ^([a-zA-Z]+)(\([a-zA-Z0-9/_-]+\))?:\ (.+)$ ]]; then
            type="${BASH_REMATCH[1]}"
            desc="${BASH_REMATCH[3]}"
            echo "  - [$type] $desc"
        else
            echo "  - $commit_msg"
        fi
    done
else
    echo "[No previous tag found - would show all commits]"
fi

echo
echo "=== Test Complete ==="
