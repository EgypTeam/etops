#!/bin/bash

# Function to display help
show_help() {
    cat <<EOF
Usage: $0 <project-name>

Generates a C project with Autotools that:
- Builds executables in ./src/
- Copies binaries to ./build/ on 'make install'
- Creates build directory if missing

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

PROJECT_NAME=$1
PROJECT_DIR="${PROJECT_NAME}"

echo "Creating C project directory structure for $PROJECT_NAME..."

# Create directory structure
mkdir -p "${PROJECT_DIR}/src"
mkdir -p "${PROJECT_DIR}/m4"
mkdir -p "${PROJECT_DIR}/build"

# Create README file
cat > "${PROJECT_DIR}/README" <<EOF
This is the $PROJECT_NAME C application.

Building instructions:
1. ./autogen.sh
2. ./configure
3. make install  (outputs to build/)
EOF

# Create configure.ac
cat > "${PROJECT_DIR}/configure.ac" <<EOF
#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([$PROJECT_NAME], [1.0], [your-email@example.com])
AC_CONFIG_SRCDIR([src/main.c])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIRS([m4])

AM_INIT_AUTOMAKE([foreign subdir-objects])
AM_SILENT_RULES([yes])

# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET

# Custom build directory
AC_ARG_VAR([BUILD_DIR], [Output directory for binaries])
BUILD_DIR=\${BUILD_DIR:-$PROJECT_DIR/build}
AC_SUBST([BUILD_DIR])

# Checks for header files.
AC_CHECK_HEADERS([stdlib.h])

AC_CONFIG_FILES([Makefile
                 src/Makefile])
AC_OUTPUT
EOF

# Create top-level Makefile.am
cat > "${PROJECT_DIR}/Makefile.am" <<EOF
SUBDIRS = src
dist_doc_DATA = README

# Copy executable to build directory
install-exec-local:
	@echo "Installing to \$(BUILD_DIR)"
	@mkdir -p "\$(BUILD_DIR)"
	@cp -v "\$(DESTDIR)\$(bindir)/$PROJECT_NAME" "\$(BUILD_DIR)/"
EOF

# Create src/Makefile.am
cat > "${PROJECT_DIR}/src/Makefile.am" <<EOF
bin_PROGRAMS = $PROJECT_NAME
${PROJECT_NAME}_SOURCES = main.c
EOF

# Create main.c
cat > "${PROJECT_DIR}/src/main.c" <<EOF
#include <stdio.h>
#include <stdlib.h>
#include "config.h"

int main(int argc, char *argv[]) {
    printf("Hello, World!\\n");
    printf("This is %s version %s\\n", PACKAGE_NAME, PACKAGE_VERSION);
    return EXIT_SUCCESS;
}
EOF

# Create .gitignore
cat > "${PROJECT_DIR}/.gitignore" <<EOF
/build/
*.o
*.lo
*.la
.deps
.libs
*.log
Makefile
Makefile.in
aclocal.m4
autom4te.cache/
config.h
config.h.in
config.log
config.status
stamp-h1
EOF

# Create autogen.sh
cat > "${PROJECT_DIR}/autogen.sh" <<EOF
#!/bin/sh
autoreconf -fvi
EOF
chmod +x "${PROJECT_DIR}/autogen.sh"

echo "C project $PROJECT_NAME created in $PROJECT_DIR/"
echo "To build and install:"
echo "1. cd $PROJECT_DIR"
echo "2. ./autogen.sh"
echo "3. ./configure"
echo "4. make install  (outputs to build/)"
echo "5. ./build/$PROJECT_NAME"