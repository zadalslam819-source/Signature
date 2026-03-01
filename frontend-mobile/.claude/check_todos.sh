#!/bin/bash
# Check for TODOs in codebase

TODO_COUNT=$(grep -r "TODO\|FIXME\|HACK" --include="*.dart" --include="*.ts" mobile/ backend/ 2>/dev/null | wc -l)

if [ "$TODO_COUNT" -gt 0 ]; then
    echo "❌ Found $TODO_COUNT TODOs/FIXMEs in code:"
    grep -r "TODO\|FIXME\|HACK" --include="*.dart" --include="*.ts" mobile/ backend/ 2>/dev/null
    exit 1
else
    echo "✅ No TODOs found"
fi