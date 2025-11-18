#!/bin/bash

# Default values
SHOW_LINE_NUMBERS=false
INCLUDE_PROPERTIES=false
INCLUDE_BUILD_FILES=false
INCLUDE_ALL_SOURCE=false
OUTPUT_FILE="project_contents.txt"
SEPARATOR_STYLE="standard"
VERBOSE=false

ONLY_LANGS_RAW=()
EXCLUDE_LANGS_RAW=()

# ---------------------------
# Language → extension mapping
# ---------------------------

# Normalizes user language names to canonical keys
normalize_language() {
    local name="$1"
    name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"

    case "$name" in
        c++|cpp) echo "cpp" ;;
        c) echo "c" ;;
        cs|c#|csharp|dotnet) echo "csharp" ;;
        js|javascript) echo "javascript" ;;
        ts|typescript) echo "typescript" ;;
        py|python) echo "python" ;;
        pas|pascal) echo "pascal" ;;
        delphi|dpr|dfm) echo "delphi" ;;
        prolog|pl) echo "prolog" ;;
        lisp|elisp|clisp|cl) echo "lisp" ;;
        asm|s) echo "asm" ;;
        go|golang) echo "go" ;;
        php) echo "php" ;;
        rb|ruby) echo "ruby" ;;
        rs|rust) echo "rust" ;;
        kt|kts|kotlin) echo "kotlin" ;;
        hs|haskell) echo "haskell" ;;
        r) echo "r" ;;
        sh|bash|zsh|shell) echo "shell" ;;
        ps1|psm1|powershell) echo "powershell" ;;
        sql) echo "sql" ;;
        html|htm) echo "html" ;;
        css) echo "css" ;;
        xml) echo "xml" ;;
        json) echo "json" ;;
        java) echo "java" ;;
        *) echo "$name" ;;  # unknown but still pass through
    esac
}

# Canonical language → file globs (space-separated list)
declare -A LANG_EXT_MAP

LANG_EXT_MAP[java]="*.java"
LANG_EXT_MAP[c]="*.c *.h"
LANG_EXT_MAP[cpp]="*.cpp *.cc *.cxx *.hpp *.hh *.hxx"
LANG_EXT_MAP[csharp]="*.cs"
LANG_EXT_MAP[javascript]="*.js"
LANG_EXT_MAP[typescript]="*.ts"
LANG_EXT_MAP[python]="*.py"
LANG_EXT_MAP[pascal]="*.pas"
LANG_EXT_MAP[delphi]="*.pas *.dpr *.dfm"
LANG_EXT_MAP[prolog]="*.pl *.prolog"
LANG_EXT_MAP[lisp]="*.lisp *.lsp *.cl *.el"
LANG_EXT_MAP[asm]="*.asm *.s *.S"
LANG_EXT_MAP[go]="*.go"
LANG_EXT_MAP[php]="*.php"
LANG_EXT_MAP[ruby]="*.rb"
LANG_EXT_MAP[rust]="*.rs"
LANG_EXT_MAP[kotlin]="*.kt *.kts"
LANG_EXT_MAP[haskell]="*.hs"
LANG_EXT_MAP[r]="*.r"
LANG_EXT_MAP[shell]="*.sh *.bash *.zsh"
LANG_EXT_MAP[powershell]="*.ps1 *.psm1"
LANG_EXT_MAP[sql]="*.sql"
LANG_EXT_MAP[html]="*.html *.htm"
LANG_EXT_MAP[css]="*.css"
LANG_EXT_MAP[xml]="*.xml"
LANG_EXT_MAP[json]="*.json"

# ---------------------------
# Help
# ---------------------------

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Bundles project files into a single text file for code sharing.

OPTIONS:
    -l, --line-numbers        Add line numbers to source files

    -p, --properties          Include .properties files

    -b, --build-files         Include build files:
                              - Java: pom.xml, build.gradle, build.xml, *.gradle, Makefile
                              - .NET: *.csproj, *.fsproj, *.vbproj, *.sln,
                                      Directory.Build.props, Directory.Build.targets,
                                      *.props, *.targets

    -a, --all-source          Include all known source languages:
                              java, c, cpp, csharp, pascal, delphi, javascript, typescript,
                              python, prolog, lisp, asm, go, php, ruby, rust, kotlin,
                              haskell, r, shell, powershell, sql, html, css, xml, json

        --only-languages=LIST Comma-separated language filter (stronger than exclude).
                              Examples:
                                --only-languages=cpp,java
                                --only-languages=cs,js,py
                              Aliases:
                                cpp/c++, js/javascript, py/python, cs/c#/csharp, etc.

        --exclude-languages=LIST
                              Comma-separated language filter to exclude.
                              The positive list (only-languages) wins if both mention
                              the same language.

    -o, --output FILE         Specify output file (default: project_contents.txt)
    -s, --separator TYPE      Separator style: standard, detailed, minimal (default: standard)
    -v, --verbose             Show verbose output
    -h, --help                Show this help message

EXAMPLES:
    $(basename "$0") -l -p
      # Java files with line numbers + .properties

    $(basename "$0") -a -b -o code.txt
      # All known sources + build files (Java, .NET, etc.)

    $(basename "$0") -a --only-languages=cpp,java,javascript
      # Only C++, Java, JS sources

    $(basename "$0") -a --exclude-languages=py,js
      # All languages except Python & JS

    $(basename "$0") -a --only-languages=java --exclude-languages=java
      # Still includes Java (positive filter is stronger)
EOF
}

# ---------------------------
# Argument parsing
# ---------------------------

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
        --only-languages=*)
            ONLY_LANGS_RAW+=("${1#*=}")
            shift
            ;;
        --only-languages)
            ONLY_LANGS_RAW+=("$2")
            shift 2
            ;;
        --exclude-languages=*)
            EXCLUDE_LANGS_RAW+=("${1#*=}")
            shift
            ;;
        --exclude-languages)
            EXCLUDE_LANGS_RAW+=("$2")
            shift 2
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
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# ---------------------------
# Separator handling
# ---------------------------

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

# ---------------------------
# Resolve language sets
# ---------------------------

# Expand comma-separated lists into arrays, normalize names
ONLY_LANGS=()
EXCLUDE_LANGS=()

for raw in "${ONLY_LANGS_RAW[@]}"; do
    IFS=',' read -r -a parts <<< "$raw"
    for p in "${parts[@]}"; do
        p="$(echo "$p" | tr -d '[:space:]')"
        [ -z "$p" ] && continue
        ONLY_LANGS+=("$(normalize_language "$p")")
    done
done

for raw in "${EXCLUDE_LANGS_RAW[@]}"; do
    IFS=',' read -r -a parts <<< "$raw"
    for p in "${parts[@]}"; do
        p="$(echo "$p" | tr -d '[:space:]')"
        [ -z "$p" ] && continue
        EXCLUDE_LANGS+=("$(normalize_language "$p")")
    done
done

# Build base set of languages
SELECTED_LANGS=()

if [ "${#ONLY_LANGS[@]}" -gt 0 ]; then
    # Only explicit languages
    SELECTED_LANGS=("${ONLY_LANGS[@]}")
elif [ "$INCLUDE_ALL_SOURCE" = true ]; then
    # All known languages
    for lang in "${!LANG_EXT_MAP[@]}"; do
        SELECTED_LANGS+=("$lang")
    done
else
    # Default: Java only (preserve old behavior)
    SELECTED_LANGS=("java")
fi

# Build quick membership maps for ONLY and EXCLUDE
declare -A ONLY_SET
declare -A EXCLUDE_SET

for l in "${ONLY_LANGS[@]}"; do
    ONLY_SET["$l"]=1
done
for l in "${EXCLUDE_LANGS[@]}"; do
    EXCLUDE_SET["$l"]=1
done

# Apply excludes, but positive filter is stronger
FILTERED_LANGS=()
for lang in "${SELECTED_LANGS[@]}"; do
    # Unknown languages (not in map) are ignored with a warning
    if [ -z "${LANG_EXT_MAP[$lang]+x}" ]; then
        if [ "$VERBOSE" = true ]; then
            echo "Warning: language '$lang' has no known extensions; ignoring." >&2
        fi
        continue
    fi
    if [[ -n "${EXCLUDE_SET[$lang]+x}" && -z "${ONLY_SET[$lang]+x}" ]]; then
        # excluded, and not explicitly included via ONLY
        continue
    fi
    FILTERED_LANGS+=("$lang")
done

SELECTED_LANGS=("${FILTERED_LANGS[@]}")

if [ "${#SELECTED_LANGS[@]}" -eq 0 ]; then
    echo "No languages selected after applying filters. Nothing to bundle." >&2
    exit 1
fi

# ---------------------------
# Build find patterns
# ---------------------------

find_patterns=()

add_pattern() {
    local pattern="$1"
    if [ ${#find_patterns[@]} -eq 0 ]; then
        find_patterns+=(-name "$pattern")
    else
        find_patterns+=(-o -name "$pattern")
    fi
}

# Language-based patterns
for lang in "${SELECTED_LANGS[@]}"; do
    exts="${LANG_EXT_MAP[$lang]}"
    for ext in $exts; do
        add_pattern "$ext"
    done
done

# Properties
if [ "$INCLUDE_PROPERTIES" = true ]; then
    add_pattern "*.properties"
fi

# Build files
if [ "$INCLUDE_BUILD_FILES" = true ]; then
    # Java / general build files
    add_pattern "pom.xml"
    add_pattern "build.gradle"
    add_pattern "build.xml"
    add_pattern "*.gradle"
    add_pattern "Makefile"
    # .NET build/project files
    add_pattern "*.csproj"
    add_pattern "*.fsproj"
    add_pattern "*.vbproj"
    add_pattern "*.sln"
    add_pattern "Directory.Build.props"
    add_pattern "Directory.Build.targets"
    add_pattern "*.props"
    add_pattern "*.targets"
fi

if [ ${#find_patterns[@]} -eq 0 ]; then
    echo "No file patterns built (this should not happen). Aborting." >&2
    exit 1
fi

find_command=("find" "." "(" "${find_patterns[@]}" ")" "-type" "f")

# ---------------------------
# Verbose diagnostic
# ---------------------------

if [ "$VERBOSE" = true ]; then
    echo "Output file: $OUTPUT_FILE"
    echo "Line numbers: $SHOW_LINE_NUMBERS"
    echo "Separator style: $SEPARATOR_STYLE"
    echo "Selected languages: ${SELECTED_LANGS[*]}"
    echo "Include properties: $INCLUDE_PROPERTIES"
    echo "Include build files: $INCLUDE_BUILD_FILES"
    echo "Find command: ${find_command[*]}"
    echo "Processing files..."
fi

# Clear output file
> "$OUTPUT_FILE"

# ---------------------------
# Process files
# ---------------------------

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

# ---------------------------
# Final message
# ---------------------------

file_count=$("${find_command[@]}" | wc -l)
echo "Done! Bundled $file_count files into $OUTPUT_FILE"

if [ "$VERBOSE" = true ]; then
    echo "File sizes:"
    ls -lh "$OUTPUT_FILE"
fi
