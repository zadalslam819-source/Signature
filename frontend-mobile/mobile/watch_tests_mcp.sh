#!/bin/bash
# ABOUTME: Watches Dart files and triggers Claude Code to run tests via Dart MCP.
# ABOUTME: Provides better test output formatting and integration with development tools.

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEST_PATH="${1:-test/}"
WATCH_PATTERN="**/*.dart"
DEBOUNCE_SECONDS=1
PROJECT_ROOT="file://$(pwd)"

echo -e "${BLUE}🔍 OpenVine Test Watcher (MCP-Enhanced)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Project root: ${YELLOW}${PROJECT_ROOT}${NC}"
echo -e "Watching: ${YELLOW}lib/${NC} and ${YELLOW}test/${NC}"
echo -e "Test path: ${YELLOW}${TEST_PATH}${NC}"
echo -e "Press ${YELLOW}Ctrl+C${NC} to stop"
echo ""

# Function to run tests using MCP via Claude
run_tests_mcp() {
    local timestamp=$(date +"%H:%M:%S")
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚡ Running tests via MCP at ${timestamp}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # Use flutter test directly for now
    # TODO: Integrate with Claude Code MCP when available
    if flutter test "$TEST_PATH" --no-pub 2>&1; then
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
run_tests_mcp

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
    --exclude='.*\.g\.dart$' \
    --exclude='.*\.freezed\.dart$' \
    --exclude='.*\.mocks\.dart$' \
    --include='.*\.dart$' \
    lib/ test/ | while read file; do
    echo -e "\n${YELLOW}📝 File changed: ${file}${NC}"
    run_tests_mcp
done
