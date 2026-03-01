#!/bin/bash
# ABOUTME: Watches Dart files for changes and automatically runs tests for TDD workflow.
# ABOUTME: Supports running all tests or specific test files on code changes.

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEST_PATH="${1:-test/}"
WATCH_PATTERN="**/*.dart"
DEBOUNCE_SECONDS=1

echo -e "${BLUE}🔍 OpenVine Test Watcher${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Watching: ${YELLOW}lib/${NC} and ${YELLOW}test/${NC}"
echo -e "Test path: ${YELLOW}${TEST_PATH}${NC}"
echo -e "Press ${YELLOW}Ctrl+C${NC} to stop"
echo ""

# Function to run tests
run_tests() {
    local timestamp=$(date +"%H:%M:%S")
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚡ Running tests at ${timestamp}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if flutter test "$TEST_PATH" 2>&1; then
        echo -e "\n${GREEN}✅ Tests passed at ${timestamp}${NC}"
    else
        echo -e "\n${RED}❌ Tests failed at ${timestamp}${NC}"
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Waiting for file changes...${NC}"
}

# Check if fswatch is available
if ! command -v fswatch &> /dev/null; then
    echo -e "${RED}❌ Error: fswatch is not installed${NC}"
    echo -e "${YELLOW}Install it with: brew install fswatch${NC}"
    exit 1
fi

# Run tests once at startup
run_tests

# Watch for changes and run tests with debouncing
fswatch -r -l "$DEBOUNCE_SECONDS" \
    --exclude='.*\.git/.*' \
    --exclude='.*build/.*' \
    --exclude='.*\.dart_tool/.*' \
    --exclude='.*\.idea/.*' \
    --exclude='.*\.vscode/.*' \
    --exclude='.*node_modules/.*' \
    --exclude='.*ios/Pods/.*' \
    --exclude='.*macos/Pods/.*' \
    --include='.*\.dart$' \
    lib/ test/ | while read file; do
    run_tests
done
