#!/bin/bash
# Quick wrapper to build and run the Docker test environment

set -e

echo "Building Docker test environment..."
docker build -f test-mason.Dockerfile -t airgap-mason-test .

echo ""
echo "Running Mason LSP installation test..."
echo "=========================================="
docker run --rm -v "$(pwd)/test-mason.sh:/test.sh:ro" airgap-mason-test bash /test.sh

echo ""
echo "=========================================="
echo "Test complete! To run interactively:"
echo "  docker run --rm -it -v \$(pwd):/workspace airgap-mason-test bash"
echo ""
echo "Then inside the container:"
echo "  bash /workspace/test-mason.sh"
