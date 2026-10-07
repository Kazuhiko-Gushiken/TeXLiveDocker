#!/bin/sh

# ============================================================
# TeXLiveDocker Compiler - Linux/macOS
# ============================================================

IMAGE="tex-live-docker"

# Always operate relative to this script.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Create required directories.
mkdir -p input output build failed

clear

echo "========================================"
echo "      TeXLiveDocker Compiler"
echo "========================================"
echo

# ============================================================
# Check Docker
# ============================================================

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or is not accessible."
    echo "Please start Docker and try again."
    echo
    exit 1
fi

# ============================================================
# Create simplified error report
# ============================================================

create_error_log() {

    BUILD_NAME="$1"
    LOG_NAME="$2"

    LOGFILE="build/$BUILD_NAME/$LOG_NAME.log"
    ERRORFILE="failed/$BUILD_NAME-errors.txt"

    {
        echo "TeXLiveDocker Compiler - Error Report"
        echo "================================="
        echo
        echo "Project: $BUILD_NAME"
        echo "Status: FAILED"
        echo
        echo "ERRORS"
        echo "------"
        echo
    } > "$ERRORFILE"

    if [ -f "$LOGFILE" ]; then

        # Actual TeX errors normally begin with !
        grep -n '^!' "$LOGFILE" >> "$ERRORFILE" 2>/dev/null || true

        {
            echo
            echo "SOURCE LINES"
            echo "------------"
            echo
        } >> "$ERRORFILE"

        # Extract lines such as:
        # l.42 \someBrokenCommand
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

# ============================================================
# Compile a loose .tex file
# ============================================================

compile_file() {

    SOURCE="$1"
    FILE="$(basename "$SOURCE")"
    NAME="${FILE%.tex}"

    echo "========================================"
    echo "Compiling: $FILE"
    echo "========================================"
    echo

    # Delete previous build.
    rm -rf "build/$NAME"
    mkdir -p "build/$NAME"

    # Copy source into build directory.
    cp "$SOURCE" "build/$NAME/$FILE"

    # Compile inside Docker.
    if ! docker run --rm \
        -v "$SCRIPT_DIR/build/$NAME:/work" \
        -w /work \
        "$IMAGE" \
        latexmk -pdf -shell-escape "$FILE"
    then

        echo
        echo "[FAILED] $FILE"

        create_error_log "$NAME" "$NAME"

        echo
        echo "Error report:"
        echo "  failed/$NAME-errors.txt"
        echo
        echo "Full build files:"
        echo "  build/$NAME"
        echo

        return
    fi

    # Make sure PDF actually exists.
    if [ ! -f "build/$NAME/$NAME.pdf" ]; then

        echo
        echo "[FAILED] Expected PDF was not created."

        create_error_log "$NAME" "$NAME"

        echo
        echo "Error report:"
        echo "  failed/$NAME-errors.txt"
        echo

        return
    fi

    # Delete obsolete failure report.
    rm -f "failed/$NAME-errors.txt"

    # Copy source and PDF to output.
    # Original input remains untouched.
    cp "$SOURCE" "output/$FILE"
    cp "build/$NAME/$NAME.pdf" "output/$NAME.pdf"

    echo
    echo "[SUCCESS] $FILE"
    echo "Output: output"
    echo
}

# ============================================================
# Compile a project directory
# ============================================================

compile_project() {

    SOURCE_DIR="$1"
    PROJECT="$(basename "$SOURCE_DIR")"
    MAIN="$PROJECT.tex"

    echo "========================================"
    echo "Compiling: $PROJECT"
    echo "========================================"
    echo

    # --------------------------------------------------------
    # Check main file
    # --------------------------------------------------------
    #
    # Project convention:
    #
    # input/PhysicsLab/
    #     PhysicsLab.tex
    #     image.png
    #     data.csv
    #
    # Folder name must match main .tex filename.

    if [ ! -f "$SOURCE_DIR/$MAIN" ]; then

        echo "[FAILED] Main TeX file not found."
        echo
        echo "Expected:"
        echo "  $SOURCE_DIR/$MAIN"
        echo
        echo "Project directories must contain a .tex file"
        echo "with the same name as the directory."
        echo

        return
    fi

    # --------------------------------------------------------
    # Prepare build directory
    # --------------------------------------------------------

    rm -rf "build/$PROJECT"
    mkdir -p "build/$PROJECT"

    # Copy entire project, including hidden files.
    cp -R "$SOURCE_DIR"/. "build/$PROJECT/"

    # --------------------------------------------------------
    # Compile
    # --------------------------------------------------------

    if ! docker run --rm \
        -v "$SCRIPT_DIR/build/$PROJECT:/work" \
        -w /work \
        "$IMAGE" \
        latexmk -pdf -shell-escape "$MAIN"
    then

        echo
        echo "[FAILED] $PROJECT"

        create_error_log "$PROJECT" "$PROJECT"

        echo
        echo "Error report:"
        echo "  failed/$PROJECT-errors.txt"
        echo
        echo "Full build files:"
        echo "  build/$PROJECT"
        echo

        return
    fi

    # Make sure PDF actually exists.
    if [ ! -f "build/$PROJECT/$PROJECT.pdf" ]; then

        echo
        echo "[FAILED] Expected PDF was not created."

        create_error_log "$PROJECT" "$PROJECT"

        echo
        echo "Error report:"
        echo "  failed/$PROJECT-errors.txt"
        echo

        return
    fi

    # --------------------------------------------------------
    # Compilation succeeded
    # --------------------------------------------------------

    # Delete obsolete failure report.
    rm -f "failed/$PROJECT-errors.txt"

    # Remove previous output version.
    rm -rf "output/$PROJECT"
    mkdir -p "output/$PROJECT"

    # Copy ORIGINAL project to output.
    cp -R "$SOURCE_DIR"/. "output/$PROJECT/"

    # Add newly compiled PDF.
    cp \
        "build/$PROJECT/$PROJECT.pdf" \
        "output/$PROJECT/$PROJECT.pdf"

    echo
    echo "[SUCCESS] $PROJECT"
    echo "Output: output/$PROJECT"
    echo
}

# ============================================================
# Display available input
# ============================================================

echo "Available:"
echo

FOUND=0

# Show loose .tex files.
for FILE in input/*.tex; do
    if [ -f "$FILE" ]; then
        echo "  $(basename "$FILE")"
        FOUND=1
    fi
done

# Show project directories.
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
echo "Enter a file or project name to compile it."
echo "Press ENTER to compile EVERYTHING."
echo

printf "Selection: "
IFS= read -r SELECTION

echo

# ============================================================
# Compile everything
# ============================================================

if [ -z "$SELECTION" ]; then

    # Compile loose .tex files.
    for FILE in input/*.tex; do
        if [ -f "$FILE" ]; then
            compile_file "$FILE"
        fi
    done

    # Compile project directories.
    for DIR in input/*; do
        if [ -d "$DIR" ]; then
            compile_project "$DIR"
        fi
    done

# ============================================================
# Compile a specific project
# ============================================================

elif [ -d "input/$SELECTION" ]; then

    compile_project "input/$SELECTION"

# ============================================================
# Compile a specific loose file
# ============================================================

elif [ -f "input/$SELECTION" ] && \
     [ "${SELECTION##*.}" = "tex" ]; then

    compile_file "input/$SELECTION"

# Allow omission of .tex extension.
elif [ -f "input/$SELECTION.tex" ]; then

    compile_file "input/$SELECTION.tex"

else

    echo "ERROR: \"$SELECTION\" was not found in input."
    echo

fi

# ============================================================
# Finished
# ============================================================

echo
echo "========================================"
echo "             Finished"
echo "========================================"
echo