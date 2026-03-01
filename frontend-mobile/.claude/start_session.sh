#!/bin/bash
# Run at start of each Claude Code session

echo "=== Claude Code Session Initialization ==="
echo "Checking project state..."

# Get the project root (parent of .claude directory)
PROJECT_ROOT="$(dirname "$(dirname "$(readlink -f "$0")")")"

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo "⚠️  Uncommitted changes detected. Consider committing first."
fi

# Check for TODOs left from previous session
TODO_COUNT=$(grep -r "TODO" --include="*.dart" --include="*.ts" "$PROJECT_ROOT/mobile/" "$PROJECT_ROOT/backend/" 2>/dev/null | wc -l)
if [ "$TODO_COUNT" -gt 0 ]; then
    echo "⚠️  $TODO_COUNT TODOs found from previous session"
fi

# Run tests to establish baseline if mobile directory exists
if [ -d "$PROJECT_ROOT/mobile" ]; then
    echo "Running tests to establish baseline..."
    cd "$PROJECT_ROOT/mobile" && flutter test --coverage
    
    # Check coverage if lcov is available
    if [ -f coverage/lcov.info ]; then
        COVERAGE=$(lcov --summary coverage/lcov.info 2>/dev/null | grep "lines" | grep -o '[0-9.]*%' | head -1)
        echo "Current test coverage: $COVERAGE"
    else
        echo "Coverage data not available yet"
    fi
else
    echo "⚠️  Mobile directory not found at $PROJECT_ROOT/mobile"
fi

echo "=== Ready for TDD Development ==="
echo "Remember: Write tests FIRST, then implementation"