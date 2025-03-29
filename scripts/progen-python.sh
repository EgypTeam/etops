#!/bin/bash

# Function to display help
show_help() {
    cat <<EOF
Usage: $0 <project-name>

Generates a Python console application project with:
- Standard Python project structure
- Autotools-like build system
- Build directory for distribution files
- setup.py integration

Options:
  --help    Show this help message
EOF
    exit 0
}

# Check for help option
if [ "$1" = "--help" ]; then
    show_help
fi

# Check if project name was provided
if [ -z "$1" ]; then
    echo "Error: No project name specified."
    echo "Usage: $0 <project-name>"
    exit 1
fi

PROJECT_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
PROJECT_DIR="${PROJECT_NAME}"

echo "Creating Python console application project: $PROJECT_NAME..."

# Create directory structure
mkdir -p "${PROJECT_DIR}/src/${PROJECT_NAME}"
mkdir -p "${PROJECT_DIR}/tests"
mkdir -p "${PROJECT_DIR}/build"
mkdir -p "${PROJECT_DIR}/m4"

# Create README.md
cat > "${PROJECT_DIR}/README.md" <<EOF
# ${PROJECT_NAME}

A Python console application.

## Installation

1. Build the project:
   \`\`\`bash
   ./autogen.sh
   ./configure
   make install
   \`\`\`

2. Run the application:
   \`\`\`bash
   ./build/${PROJECT_NAME}
   \`\`\`

## Development

To install in development mode:
\`\`\`bash
pip install -e .
\`\`\`
EOF

# Create configure.ac
cat > "${PROJECT_DIR}/configure.ac" <<EOF
#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([${PROJECT_NAME}], [1.0], [your-email@example.com])
AC_CONFIG_SRCDIR([src/${PROJECT_NAME}/__init__.py])
AC_CONFIG_MACRO_DIRS([m4])

AM_INIT_AUTOMAKE([foreign])
AM_SILENT_RULES([yes])

# Check for Python
AC_ARG_VAR([PYTHON], [The Python interpreter])
AC_CHECK_PROGS([PYTHON], [python3 python], [none])
AS_IF([test "$PYTHON" = none],
      [AC_MSG_ERROR([Python interpreter not found])])

# Custom build directory
AC_ARG_VAR([BUILD_DIR], [Output directory for binaries])
BUILD_DIR=\${BUILD_DIR:-${PROJECT_DIR}/build}
AC_SUBST([BUILD_DIR])

AC_CONFIG_FILES([Makefile
                 src/Makefile])
AC_OUTPUT
EOF

# Create top-level Makefile.am
cat > "${PROJECT_DIR}/Makefile.am" <<EOF
SUBDIRS = src

dist_doc_DATA = README.md

install-exec-local:
	@echo "Installing to \$(BUILD_DIR)"
	@mkdir -p "\$(BUILD_DIR)"
	@echo '#!/bin/sh' > "\$(BUILD_DIR)/${PROJECT_NAME}"
	@echo 'exec \$(PYTHON) -m ${PROJECT_NAME} "\$$@"' >> "\$(BUILD_DIR)/${PROJECT_NAME}"
	@chmod +x "\$(BUILD_DIR)/${PROJECT_NAME}"
EOF

# Create src/Makefile.am
cat > "${PROJECT_DIR}/src/Makefile.am" <<EOF
pkgpython_PYTHON = \\
	${PROJECT_NAME}/__init__.py \\
	${PROJECT_NAME}/main.py

dist_bin_SCRIPTS = ${PROJECT_NAME}/__main__.py
EOF

# Create Python package files
cat > "${PROJECT_DIR}/src/${PROJECT_NAME}/__init__.py" <<EOF
"""${PROJECT_NAME} - A Python console application"""

__version__ = '1.0.0'
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}/main.py" <<EOF
import argparse

def main():
    """Main entry point for the console application"""
    parser = argparse.ArgumentParser(description='${PROJECT_NAME}')
    parser.add_argument('--version', action='version', version=f'%(prog)s {__version__}')
    args = parser.parse_args()
    
    print(f"Hello from {__name__}!")
    print(f"Running version {__version__}")

if __name__ == '__main__':
    main()
EOF

cat > "${PROJECT_DIR}/src/${PROJECT_NAME}/__main__.py" <<EOF
from ${PROJECT_NAME}.main import main

if __name__ == '__main__':
    main()
EOF

# Create setup.py
cat > "${PROJECT_DIR}/setup.py" <<EOF
from setuptools import setup, find_packages

setup(
    name='${PROJECT_NAME}',
    version='1.0.0',
    packages=find_packages(where='src'),
    package_dir={'': 'src'},
    entry_points={
        'console_scripts': [
            '${PROJECT_NAME}=${PROJECT_NAME}.main:main',
        ],
    },
    python_requires='>=3.6',
)
EOF

# Create autogen.sh
cat > "${PROJECT_DIR}/autogen.sh" <<EOF
#!/bin/sh
autoreconf -fvi
EOF
chmod +x "${PROJECT_DIR}/autogen.sh"

# Create .gitignore
cat > "${PROJECT_DIR}/.gitignore" <<EOF
/build/
/dist/
/*.egg-info/
/__pycache__/
*.pyc
*.pyo
*.pyd
*.so
Makefile
Makefile.in
aclocal.m4
autom4te.cache/
config.log
config.status
EOF

echo "Python project ${PROJECT_NAME} created in ${PROJECT_DIR}/"
echo "To build and install:"
echo "1. cd ${PROJECT_DIR}"
echo "2. ./autogen.sh"
echo "3. ./configure"
echo "4. make install  (creates executable in build/)"
echo "5. ./build/${PROJECT_NAME}"
echo ""
echo "For development mode:"
echo "  pip install -e ."
