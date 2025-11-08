#!/bin/bash

# Default values
SHOW_LINE_NUMBERS=false
INCLUDE_PROPERTIES=false
INCLUDE_BUILD_FILES=false
INCLUDE_ALL_SOURCE=false
OUTPUT_FILE="project_contents.txt"
SEPARATOR_STYLE="standard"
VERBOSE=false

# Function to display help
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Bundles project files into a single text file for code sharing.

OPTIONS:
    -l, --line-numbers    Add line numbers to source files
    -p, --properties      Include .properties files
    -b, --build-files     Include build files (pom.xml, build.gradle, build.xml)
    -a, --all-source      Include all common source files (.java, .py, .js, .cpp, .c, .h)
    -o, --output FILE     Specify output file (default: project_contents.txt)
    -s, --separator TYPE  Separator style: standard, detailed, minimal (default: standard)
    -v, --verbose         Show verbose output
    -h, --help            Show this help message

EXAMPLES:
    $(basename "$0") -l -p              # Java files with line numbers + properties
    $(basename "$0") -a -b -o output.txt # All source + build files
    $(basename "$0") --all-source --separator minimal --verbose
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--line-numbers)
            SHOW_LINE_NUMBERS=true
            shift
            ;;
        -p|--properties)
            INCLUDE_PROPERTIES=true
            shift
            ;;
        -b|--build-files)
            INCLUDE_BUILD_FILES=true
            shift
            ;;
        -a|--all-source)
            INCLUDE_ALL_SOURCE=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -s|--separator)
            SEPARATOR_STYLE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set separator based on style
case $SEPARATOR_STYLE in
    "minimal")
        SEPARATOR_START=""
        SEPARATOR_END=""
        ;;
    "detailed")
        SEPARATOR_START="--- FILE: {} ---"
        SEPARATOR_END=""
        ;;
    *)
        SEPARATOR_START="=== FILE: {} ==="
        SEPARATOR_END=""
        ;;
esac

# Build find command patterns
find_patterns=()
find_patterns+=(-name "*.java")

if [ "$INCLUDE_PROPERTIES" = true ]; then
    find_patterns+=(-o -name "*.properties")
fi

if [ "$INCLUDE_BUILD_FILES" = true ]; then
    find_patterns+=(-o -name "pom.xml" -o -name "build.gradle" -o -name "build.xml" -o -name "*.gradle" -o -name "Makefile")
fi

if [ "$INCLUDE_ALL_SOURCE" = true ]; then
    find_patterns+=(-o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.html" -o -name "*.css")
fi

# If no additional patterns were added, we need to adjust the find command
if [ ${#find_patterns[@]} -eq 1 ]; then
    # Only Java files
    find_command=("find" "." "-name" "*.java" "-type" "f")
else
    # Multiple file types - build the OR pattern
    find_command=("find" "." "(" "${find_patterns[@]}" ")" "-type" "f")
fi

# Verbose output
if [ "$VERBOSE" = true ]; then
    echo "Output file: $OUTPUT_FILE"
    echo "Line numbers: $SHOW_LINE_NUMBERS"
    echo "Separator style: $SEPARATOR_STYLE"
    echo "Find command: ${find_command[@]}"
    echo "Processing files..."
fi

# Clear output file
> "$OUTPUT_FILE"

# Process files based on options
if [ "$SHOW_LINE_NUMBERS" = true ]; then
    # With line numbers
    "${find_command[@]}" -exec sh -c '
        echo "$1" >> "$2"
        cat -n "$3" >> "$2"
        echo "" >> "$2"
    ' _ "$SEPARATOR_START" "$OUTPUT_FILE" {} \;
else
    # Without line numbers
    if [ -n "$SEPARATOR_START" ]; then
        "${find_command[@]}" -exec sh -c '
            echo "$1" >> "$2"
            cat "$3" >> "$2"
            echo "" >> "$2"
        ' _ "$SEPARATOR_START" "$OUTPUT_FILE" {} \;
    else
        # Minimal style - no separators
        "${find_command[@]}" -exec sh -c '
            cat "$1" >> "$2"
            echo "" >> "$2"
        ' _ {} "$OUTPUT_FILE" \;
    fi
fi

# Final message
file_count=$("${find_command[@]}" | wc -l)
echo "Done! Bundled $file_count files into $OUTPUT_FILE"

if [ "$VERBOSE" = true ]; then
    echo "File sizes:"
    ls -lh "$OUTPUT_FILE"
fi
