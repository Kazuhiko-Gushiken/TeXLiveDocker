#!/bin/sh

# image builder

IMAGE="tex-live-docker"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

clear

echo "========================================"
echo "      TeX Live Docker - Setup"
echo "========================================"
echo

# check for docker actually running
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or is not accessible."
    echo "Please start Docker and try again."
    echo
    exit 1
fi

# now check the docker file
if [ ! -f "Dockerfile" ]; then
    echo "ERROR: Dockerfile not found."
    echo
    exit 1
fi

echo "Building Docker image:"
echo "  $IMAGE"
echo
echo "This may take a while on the first build."
echo

if ! docker build -t "$IMAGE" .; then
    echo
    echo "========================================"
    echo "             BUILD FAILED"
    echo "========================================"
    echo
    exit 1
fi

echo
echo "========================================"
echo "           BUILD COMPLETE"
echo "========================================"
echo
echo "Docker image created:"
echo "  $IMAGE"
echo
echo "You can now use ./compile.sh."
echo