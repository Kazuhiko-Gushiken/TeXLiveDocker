#!/bin/sh

IMAGE="tex-live-docker"
CONTAINER="tex-live-docker-live"
STATE=".texlivedocker-live"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

mkdir -p input output build failed

clear
echo "========================================"
echo "      TeXLiveDocker Live Compiler"
echo "========================================"
echo

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or is not accessible."
    exit 1
fi

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

if ! docker run -d --rm \
    --name "$CONTAINER" \
    --mount "type=bind,source=$SCRIPT_DIR,target=/repo" \
    -w /repo \
    "$IMAGE" \
    sh -c 'while :; do sleep 3600; done' >/dev/null
then
    echo "ERROR: Could not start the live container."
    exit 1
fi

rm -rf "$STATE"
mkdir -p "$STATE/snapshot"
: > "$STATE/running"

cleanup() {
    rm -f "$STATE/running"
    [ -n "${WATCH_PID:-}" ] && kill "$WATCH_PID" >/dev/null 2>&1 || true
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    rm -rf "$STATE"
}
trap cleanup EXIT INT TERM

# snapshot existing tex files
find input -type f -name '*.tex' -print | while IFS= read -r FILE; do
    REL="${FILE#input/}"
    SNAP="$STATE/snapshot/$REL"
    mkdir -p "$(dirname "$SNAP")"
    cp "$FILE" "$SNAP"
done

compile_changed() {
    SOURCE="$1"
    REL="${SOURCE#input/}"
    FILE="$(basename "$SOURCE")"
    NAME="${FILE%.tex}"
    SOURCE_DIR="$(dirname "$SOURCE")"
    REL_DIR="$(dirname "$REL")"

    if [ "$REL_DIR" = "." ]; then
        BUILD="build/$NAME"
        OUTPUT="output"
    else
        BUILD="build/$REL_DIR/$NAME"
        OUTPUT="output/$REL_DIR"
    fi

    mkdir -p "$BUILD" "$OUTPUT"

    # refresh source files without overwriting latex build files
    find "$SOURCE_DIR" -maxdepth 1 -type f \
        ! -name '*.aux' \
        ! -name '*.log' \
        ! -name '*.out' \
        ! -name '*.fls' \
        ! -name '*.fdb_latexmk' \
        ! -name '*.synctex.gz' \
        ! -name '*.toc' \
        ! -name '*.lof' \
        ! -name '*.lot' \
        -exec cp -f {} "$BUILD/" \;

    echo
    echo "[CHANGE] $REL"

    if docker exec "$CONTAINER" \
        sh -c 'cd "$1" && latexmk -pdf -shell-escape "$2"' \
        sh "/repo/$BUILD" "$FILE"
    then
        if [ -f "$BUILD/$NAME.pdf" ]; then
            cp -f "$BUILD/$NAME.pdf" "$OUTPUT/$NAME.pdf"
            echo
            echo "[SUCCESS] $REL"
        else
            echo
            echo "[FAILED] $REL - expected PDF was not created."
        fi
    else
        echo
        echo "[FAILED] $REL"
    fi
}

watch_loop() {
    while [ -f "$STATE/running" ]; do
        find input -type f -name '*.tex' -print | while IFS= read -r FILE; do
            [ -f "$STATE/running" ] || exit 0

            REL="${FILE#input/}"
            SNAP="$STATE/snapshot/$REL"

            if [ ! -f "$SNAP" ]; then
                mkdir -p "$(dirname "$SNAP")"
                cp "$FILE" "$SNAP"
            elif ! cmp -s "$FILE" "$SNAP"; then
                cp "$FILE" "$SNAP"
                compile_changed "$FILE"
            fi
        done
        sleep 1
    done
}

echo "Watching all .tex files in input/"
echo "Save a .tex file to compile it."
echo "Press ENTER to stop."
echo

watch_loop &
WATCH_PID=$!

IFS= read -r _
rm -f "$STATE/running"
kill "$WATCH_PID" >/dev/null 2>&1 || true
wait "$WATCH_PID" 2>/dev/null || true

echo
echo "Live compiler stopped."
