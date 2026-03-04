#!/bin/bash
# Test plugin installation using plugin-manifest.lua
# This script uses the same manifest that GitHub Actions will use

set -e

MANIFEST="${MANIFEST_PATH:-/workspace/config/plugin-manifest.lua}"

echo "=========================================="
echo "🚀 Testing with Plugin Manifest"
echo "=========================================="
echo "Manifest: $MANIFEST"
echo ""

# Run the installer
/workspace/scripts/install-from-manifest.sh "$MANIFEST"

echo ""
echo "=========================================="
echo "🎯 Next Steps"
echo "=========================================="
echo ""
echo "To package these plugins:"
echo "  docker cp <container>:~/.local/share/nvim/lazy ./plugins/"
echo "  docker cp <container>:~/.local/share/nvim/mason/packages ./mason/"
echo ""
echo "Or run: make test-package-manifest"
