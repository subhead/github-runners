#!/bin/bash
# test-modular-runners.sh
# Test script for modular Linux GitHub Actions runners

set -e

echo "=========================================="
echo "Testing Modular Linux GitHub Actions Runners"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
SKIPPED=0

# Test functions
test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED++))
}

test_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((SKIPPED++))
}

test_info() {
    echo -e "${BLUE}ℹ INFO${NC}: $1"
}

# Check prerequisites
echo "1. Checking prerequisites..."
echo "------------------------------------------"

# Check Docker
if command -v docker &> /dev/null; then
    test_pass "Docker is installed"
    docker --version
else
    test_fail "Docker is not installed"
    exit 1
fi

# Check Docker is running
if docker info &> /dev/null; then
    test_pass "Docker daemon is running"
else
    test_fail "Docker daemon is not running"
    exit 1
fi

# Check directory structure
echo ""
echo "2. Checking directory structure..."
echo "------------------------------------------"

if [ -f "docker/linux/base/Dockerfile.base" ]; then
    test_pass "Base Dockerfile exists"
else
    test_fail "Base Dockerfile missing"
fi

if [ -f "docker/linux/entrypoint/entrypoint.sh" ]; then
    test_pass "Entrypoint script exists"
else
    test_fail "Entrypoint script missing"
fi

if [ -f "docker/linux/language-packs/cpp/Dockerfile.cpp" ]; then
    test_pass "C++ language pack exists"
else
    test_fail "C++ language pack missing"
fi

if [ -f "docker/linux/language-packs/python/Dockerfile.python" ]; then
    test_pass "Python language pack exists"
else
    test_fail "Python language pack missing"
fi

if [ -f "docker/linux/language-packs/nodejs/Dockerfile.nodejs" ]; then
    test_pass "Node.js language pack exists"
else
    test_fail "Node.js language pack missing"
fi

if [ -f "docker/linux/language-packs/go/Dockerfile.go" ]; then
    test_pass "Go language pack exists"
else
    test_fail "Go language pack missing"
fi

if [ -f "docker/linux/composite/Dockerfile.cpp-only" ]; then
    test_pass "C++ composite image exists"
else
    test_fail "C++ composite image missing"
fi

if [ -f "docker/linux/composite/Dockerfile.python-only" ]; then
    test_pass "Python composite image exists"
else
    test_fail "Python composite image missing"
fi

if [ -f "docker/linux/composite/Dockerfile.web" ]; then
    test_pass "Web composite image exists"
else
    test_fail "Web composite image missing"
fi

if [ -f "docker/linux/composite/Dockerfile.full-stack" ]; then
    test_pass "Full-stack composite image exists"
else
    test_fail "Full-stack composite image missing"
fi

# Check Docker Compose files
echo ""
echo "3. Checking Docker Compose files..."
echo "------------------------------------------"

for file in linux-base linux-cpp linux-python linux-web linux-full build-all; do
    if [ -f "docker-compose/${file}.yml" ]; then
        test_pass "${file}.yml exists"
    else
        test_fail "${file}.yml missing"
    fi
done

# Check documentation
echo ""
echo "4. Checking documentation..."
echo "------------------------------------------"

for doc in README.md quick-start.md migration.md performance.md PROJECT_SUMMARY.md; do
    if [ -f "docs/linux-modular/${doc}" ]; then
        test_pass "${doc} exists"
    else
        test_fail "${doc} missing"
    fi
done

# Check environment variables
echo ""
echo "5. Checking environment variables..."
echo "------------------------------------------"

if [ -z "$GITHUB_TOKEN" ]; then
    test_skip "GITHUB_TOKEN not set (will be required for deployment)"
else
    test_pass "GITHUB_TOKEN is set"
fi

if [ -z "$GITHUB_REPOSITORY" ]; then
    test_skip "GITHUB_REPOSITORY not set (will be required for deployment)"
else
    test_pass "GITHUB_REPOSITORY is set"
fi

# Validate Dockerfile syntax
echo ""
echo "6. Validating Dockerfile syntax..."
echo "------------------------------------------"

validate_dockerfile() {
    local file=$1
    if docker build -f "$file" --dry-run . > /dev/null 2>&1; then
        test_pass "$(basename $file) syntax is valid"
        return 0
    else
        test_fail "$(basename $file) syntax validation failed"
        return 1
    fi
}

# Note: Docker --dry-run requires Docker 24.0+ or BuildKit
# For older Docker, we'll skip this check
if docker build --help | grep -q "dry-run"; then
    test_info "Validating Dockerfiles with dry-run..."
    validate_dockerfile "docker/linux/base/Dockerfile.base"
    validate_dockerfile "docker/linux/language-packs/cpp/Dockerfile.cpp"
    validate_dockerfile "docker/linux/language-packs/python/Dockerfile.python"
    validate_dockerfile "docker/linux/language-packs/nodejs/Dockerfile.nodejs"
else
    test_skip "Docker version doesn't support dry-run validation"
fi

# Test build readiness
echo ""
echo "7. Testing build readiness..."
echo "------------------------------------------"

# Check if we can build a simple test
if [ -f "docker/linux/base/Dockerfile.base" ]; then
    test_pass "Base Dockerfile is ready for build"
    test_info "To build: docker build -f docker/linux/base/Dockerfile.base -t gh-runner:linux-base ."
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo "=========================================="
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Build base image: docker build -f docker/linux/base/Dockerfile.base -t gh-runner:linux-base ."
    echo "2. Build language packs"
    echo "3. Build composite images"
    echo "4. Deploy with docker-compose"
    echo ""
    echo "For detailed instructions, see: docs/linux-modular/quick-start.md"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    echo "Please address the failures above and run the test again."
    exit 1
fi
