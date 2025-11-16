#!/bin/bash
# Shell Script Checker
# Runs validation checks on all bash scripts in the repository
#
# Usage:
#   ./check.sh

set -e

echo "=========================================="
echo "Shell Script Validation"
echo "=========================================="
echo ""

# Find all .sh scripts in current directory (not subdirectories)
SCRIPTS=(*.sh)
SCRIPT_COUNT=${#SCRIPTS[@]}

echo "Found $SCRIPT_COUNT shell scripts to check:"
for script in "${SCRIPTS[@]}"; do
    echo "  - $script"
done
echo ""

# Track results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Check 1: Shellcheck (if available)
echo "=========================================="
echo "Check 1: ShellCheck (static analysis)"
echo "=========================================="
echo ""

if command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK_FAILED=()
    for script in "${SCRIPTS[@]}"; do
        echo "Checking $script..."
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

        if shellcheck "$script" 2>&1; then
            echo "✓ $script passed shellcheck"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo "✗ $script failed shellcheck"
            SHELLCHECK_FAILED+=("$script")
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
        echo ""
    done

    if [ ${#SHELLCHECK_FAILED[@]} -gt 0 ]; then
        echo "⚠️  Scripts with shellcheck issues:"
        for script in "${SHELLCHECK_FAILED[@]}"; do
            echo "   - $script"
        done
        echo ""
    fi
else
    echo "⚠️  shellcheck not found - skipping static analysis"
    echo "   Install with: sudo apt install shellcheck (Debian/Ubuntu)"
    echo "   or: brew install shellcheck (macOS)"
    echo ""
fi

# Check 2: Executable permissions
echo "=========================================="
echo "Check 2: Executable Permissions"
echo "=========================================="
echo ""

NON_EXECUTABLE=()
for script in "${SCRIPTS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ -x "$script" ]; then
        echo "✓ $script is executable"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "✗ $script is NOT executable"
        NON_EXECUTABLE+=("$script")
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done
echo ""

if [ ${#NON_EXECUTABLE[@]} -gt 0 ]; then
    echo "To fix executable permissions, run:"
    for script in "${NON_EXECUTABLE[@]}"; do
        echo "  chmod +x $script"
    done
    echo ""
fi

# Check 3: Shebang verification
echo "=========================================="
echo "Check 3: Shebang (#!/bin/bash)"
echo "=========================================="
echo ""

NO_SHEBANG=()
WRONG_SHEBANG=()
for script in "${SCRIPTS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FIRST_LINE=$(head -n 1 "$script")

    if [[ "$FIRST_LINE" == "#!/bin/bash" ]]; then
        echo "✓ $script has correct shebang"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    elif [[ "$FIRST_LINE" == "#!"* ]]; then
        echo "⚠️  $script has shebang: $FIRST_LINE"
        WRONG_SHEBANG+=("$script: $FIRST_LINE")
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "✗ $script missing shebang"
        NO_SHEBANG+=("$script")
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done
echo ""

if [ ${#WRONG_SHEBANG[@]} -gt 0 ]; then
    echo "Note: Non-standard shebangs found:"
    for item in "${WRONG_SHEBANG[@]}"; do
        echo "   - $item"
    done
    echo ""
fi

# Check 4: Syntax check (bash -n)
echo "=========================================="
echo "Check 4: Bash Syntax Check"
echo "=========================================="
echo ""

SYNTAX_ERRORS=()
for script in "${SCRIPTS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if bash -n "$script" 2>&1; then
        echo "✓ $script has valid syntax"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "✗ $script has syntax errors"
        SYNTAX_ERRORS+=("$script")
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done
echo ""

if [ ${#SYNTAX_ERRORS[@]} -gt 0 ]; then
    echo "⚠️  Scripts with syntax errors:"
    for script in "${SYNTAX_ERRORS[@]}"; do
        echo "   - $script"
    done
    echo ""
fi

# Check 5: 'set -e' usage
echo "=========================================="
echo "Check 5: Error Handling (set -e)"
echo "=========================================="
echo ""

NO_SET_E=()
for script in "${SCRIPTS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q "^set -e" "$script"; then
        echo "✓ $script uses 'set -e'"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "⚠️  $script doesn't use 'set -e'"
        NO_SET_E+=("$script")
        # Not counting as failed - just a warning
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi
done
echo ""

if [ ${#NO_SET_E[@]} -gt 0 ]; then
    echo "Note: Scripts without 'set -e' (not critical):"
    for script in "${NO_SET_E[@]}"; do
        echo "   - $script"
    done
    echo ""
fi

# Final summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Total checks run: $TOTAL_CHECKS"
echo "Passed: $PASSED_CHECKS"
echo "Failed: $FAILED_CHECKS"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo "✅ All checks passed!"
    exit 0
else
    echo "❌ Some checks failed. Please review the output above."
    exit 1
fi
