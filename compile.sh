#!/bin/sh

# compiler

IMAGE="tex-live-docker"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

mkdir -p input output build failed
clear

echo "========================================"
echo "      TeXLiveDocker Compiler"
echo "========================================"
echo

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or is not accessible."
    echo "Please start Docker and try again."
    echo
    exit 1
fi

create_error_log() {
    BUILD_DIR="$1"
    NAME="$2"
    ERROR_DIR="$3"
    DISPLAY="$4"

    LOGFILE="$BUILD_DIR/$NAME.log"
    ERRORFILE="$ERROR_DIR/$NAME-errors.txt"

    mkdir -p "$ERROR_DIR"

    {
        echo "TeXLiveDocker Compiler - Error Report"
        echo "====================================="
        echo
        echo "Document: $DISPLAY"
        echo "Status: FAILED"
        echo
        echo "ERRORS"
        echo "------"
        echo
    } > "$ERRORFILE"

    if [ -f "$LOGFILE" ]; then
        grep -n '^!' "$LOGFILE" >> "$ERRORFILE" 2>/dev/null || true
        {
            echo
            echo "SOURCE LINES"
            echo "------------"
            echo
        } >> "$ERRORFILE"
        grep -n '^l\.[0-9][0-9]*' "$LOGFILE" >> "$ERRORFILE" 2>/dev/null || true
    else
        {
            echo "No LaTeX log file was generated."
            echo
            echo "The failure may have occurred before LaTeX"
            echo "was able to create a log file."
        } >> "$ERRORFILE"
    fi

    {
        echo
        echo "---------------------------------"
        echo "Full log: $LOGFILE"
    } >> "$ERRORFILE"
}

run_latex() {
    BUILD_DIR="$1"
    FILE="$2"
    NAME="$3"
    ERROR_DIR="$4"
    DISPLAY="$5"

    mkdir -p "$ERROR_DIR"

    if ! docker run --rm \
        -v "$SCRIPT_DIR/$BUILD_DIR:/work" \
        -w /work \
        "$IMAGE" \
        latexmk -pdf -shell-escape "$FILE"
    then
        echo
        echo "[FAILED] $DISPLAY"
        create_error_log "$BUILD_DIR" "$NAME" "$ERROR_DIR" "$DISPLAY"
        echo
        echo "Error report:"
        echo "  $ERROR_DIR/$NAME-errors.txt"
        echo
        echo "Full build files:"
        echo "  $BUILD_DIR"
        echo
        return 1
    fi

    if [ ! -f "$BUILD_DIR/$NAME.pdf" ]; then
        echo
        echo "[FAILED] $DISPLAY - expected PDF was not created."
        create_error_log "$BUILD_DIR" "$NAME" "$ERROR_DIR" "$DISPLAY"
        echo
        echo "Error report:"
        echo "  $ERROR_DIR/$NAME-errors.txt"
        echo
        return 1
    fi

    return 0
}

compile_loose_file() {
    SOURCE="$1"
    FILE="$(basename "$SOURCE")"
    NAME="${FILE%.tex}"
    BUILD_DIR="build/$NAME"

    echo "========================================"
    echo "Compiling: $FILE"
    echo "========================================"
    echo

    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cp "$SOURCE" "$BUILD_DIR/$FILE"

    if ! run_latex "$BUILD_DIR" "$FILE" "$NAME" "failed" "$FILE"; then
        return
    fi

    cp "$SOURCE" "output/$FILE"
    cp "$BUILD_DIR/$NAME.pdf" "output/$NAME.pdf"
    rm -f "failed/$NAME-errors.txt"

    echo
    echo "[SUCCESS] $FILE"
    echo "Output: output"
    echo
}

compile_directory_file() {
    SOURCE_DIR="$1"
    PROJECT="$2"
    SOURCE_FILE="$3"
    FILE="$(basename "$SOURCE_FILE")"
    NAME="${FILE%.tex}"
    BUILD_DIR="build/$PROJECT/$NAME"
    ERROR_DIR="failed/$PROJECT"

    echo "----------------------------------------"
    echo "Compiling: $PROJECT/$FILE"
    echo "----------------------------------------"
    echo

    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    # Copy the whole source directory so this document can still access
    # sibling images, bibliography files, data files, etc.
    cp -R "$SOURCE_DIR"/. "$BUILD_DIR/"

    if ! run_latex "$BUILD_DIR" "$FILE" "$NAME" "$ERROR_DIR" "$PROJECT/$FILE"; then
        return
    fi

    cp "$BUILD_DIR/$NAME.pdf" "output/$PROJECT/$NAME.pdf"
    rm -f "$ERROR_DIR/$NAME-errors.txt"
    rmdir "$ERROR_DIR" 2>/dev/null || true

    echo
    echo "[SUCCESS] $FILE"
    echo
}

compile_directory() {
    SOURCE_DIR="$1"
    PROJECT="$(basename "$SOURCE_DIR")"
    FOUND_TEX=0

    echo "========================================"
    echo "Compiling directory: $PROJECT"
    echo "========================================"
    echo

    for FILE in "$SOURCE_DIR"/*.tex; do
        if [ -f "$FILE" ]; then
            FOUND_TEX=1
            break
        fi
    done

    if [ "$FOUND_TEX" -eq 0 ]; then
        echo "[SKIPPED] No .tex files found directly inside $SOURCE_DIR"
        echo
        return
    fi

    # make an output copy of the source then pdf
    rm -rf "output/$PROJECT"
    mkdir -p "output/$PROJECT"
    cp -R "$SOURCE_DIR"/. "output/$PROJECT/"

    for FILE in "$SOURCE_DIR"/*.tex; do
        if [ -f "$FILE" ]; then
            compile_directory_file "$SOURCE_DIR" "$PROJECT" "$FILE"
        fi
    done

    echo "Finished directory: $PROJECT"
    echo "Output: output/$PROJECT"
    echo
}

echo "Available:"
echo
FOUND=0

for FILE in input/*.tex; do
    if [ -f "$FILE" ]; then
        echo "  $(basename "$FILE")"
        FOUND=1
    fi
done

for DIR in input/*; do
    if [ -d "$DIR" ]; then
        echo "  $(basename "$DIR")"
        FOUND=1
    fi
done

if [ "$FOUND" -eq 0 ]; then
    echo "  [EMPTY]"
    echo
    echo "Nothing to compile."
    echo
    exit 0
fi

echo
echo "----------------------------------------"
echo
echo "Enter a file or directory name to compile it."
echo "Selecting a directory compiles every .tex file directly inside it."
echo "Press ENTER to compile EVERYTHING."
echo
printf "Selection: "
IFS= read -r SELECTION
echo

if [ -z "$SELECTION" ]; then
    for FILE in input/*.tex; do
        if [ -f "$FILE" ]; then
            compile_loose_file "$FILE"
        fi
    done

    for DIR in input/*; do
        if [ -d "$DIR" ]; then
            compile_directory "$DIR"
        fi
    done
elif [ -d "input/$SELECTION" ]; then
    compile_directory "input/$SELECTION"
elif [ -f "input/$SELECTION" ] && [ "${SELECTION##*.}" = "tex" ]; then
    compile_loose_file "input/$SELECTION"
elif [ -f "input/$SELECTION.tex" ]; then
    compile_loose_file "input/$SELECTION.tex"
else
    echo "ERROR: \"$SELECTION\" was not found in input."
    echo
fi

echo
echo "========================================"
echo "             Finished"
echo "========================================"
echo
