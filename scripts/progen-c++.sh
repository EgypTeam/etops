#!/bin/bash

# Function to display help
show_help() {
    cat <<EOF
Usage: $0 <project-name>

This script generates a "Hello World" C++ application with Autoconf, Automake, and proper project directory structure.

What the script creates:
----------------------
project-name/
├── README
├── Makefile.am
├── configure.ac
├── autogen.sh
├── .gitignore
├── m4/
└── src/
    ├── main.cpp
    └── Makefile.am

Building the Project:
-------------------
After running the script, follow these steps to build the project:

1. cd project-name
2. ./autogen.sh
3. ./configure
4. make
5. ./src/project-name

The project includes:
- configure.ac - Autoconf configuration for C++
- Makefile.am files - Automake configuration
- Proper C++ source code organization
- .gitignore file
- Convenience autogen.sh script
- Basic README with build instructions

Options:
  --help    Show this help message and exit
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
    echo "Use $0 --help for more information"
    exit 1
fi

PROJECT_NAME=$1
PROJECT_DIR="${PROJECT_NAME}"

echo "Creating C++ project directory structure for $PROJECT_NAME..."

# Create directory structure
mkdir -p "${PROJECT_DIR}/src"
mkdir -p "${PROJECT_DIR}/m4"

# Create README file
cat > "${PROJECT_DIR}/README" <<EOF
This is the $PROJECT_NAME C++ application.

Building instructions:
1. autoreconf -fvi
2. ./configure
3. make
4. ./src/$PROJECT_NAME

This project is configured for C++ development using Autotools.
EOF

# Create configure.ac with C++ support
cat > "${PROJECT_DIR}/configure.ac" <<EOF
#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([$PROJECT_NAME], [1.0], [your-email@example.com])
AC_CONFIG_SRCDIR([src/main.cpp])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIRS([m4])

AM_INIT_AUTOMAKE([foreign subdir-objects])
AM_SILENT_RULES([yes])

# Check for C++ compiler
AC_LANG([C++])
AC_PROG_CXX
AC_PROG_INSTALL
AC_PROG_MAKE_SET

# Check for C++ standard library headers
AC_CHECK_HEADERS([iostream cstdlib])

# Check for C++11 support
AX_CXX_COMPILE_STDCXX_11([noext], [mandatory])

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

AC_CONFIG_FILES([Makefile
                 src/Makefile])
AC_OUTPUT
EOF

# Create Makefile.am for top directory
cat > "${PROJECT_DIR}/Makefile.am" <<EOF
SUBDIRS = src
dist_doc_DATA = README
ACLOCAL_AMFLAGS = -I m4
EOF

# Create src/Makefile.am
cat > "${PROJECT_DIR}/src/Makefile.am" <<EOF
bin_PROGRAMS = $PROJECT_NAME
${PROJECT_NAME}_SOURCES = main.cpp
${PROJECT_NAME}_CPPFLAGS = -I\$(top_srcdir)
EOF

# Create main.cpp
cat > "${PROJECT_DIR}/src/main.cpp" <<EOF
#include <iostream>
#include <config.h>

int main(int argc, char *argv[]) {
    std::cout << "Hello, C++ World!" << std::endl;
    std::cout << "This is " << PACKAGE_NAME << " version " << PACKAGE_VERSION << std::endl;
    return EXIT_SUCCESS;
}
EOF

# Create .gitignore
cat > "${PROJECT_DIR}/.gitignore" <<EOF
*.o
*.lo
*.la
.deps
.libs
*.log
*.scan
Makefile
Makefile.in
aclocal.m4
autom4te.cache/
compile
config.guess
config.h
config.h.in
config.log
config.status
config.sub
configure
depcomp
install-sh
ltmain.sh
missing
stamp-h1
src/$PROJECT_NAME
EOF

# Create autogen.sh for convenience
cat > "${PROJECT_DIR}/autogen.sh" <<EOF
#!/bin/sh
autoreconf -fvi
EOF
chmod +x "${PROJECT_DIR}/autogen.sh"

# Create m4 directory for C++11 macro
mkdir -p "${PROJECT_DIR}/m4"
cat > "${PROJECT_DIR}/m4/ax_cxx_compile_stdcxx_11.m4" <<'EOF'
# ===========================================================================
#   https://www.gnu.org/software/autoconf-archive/ax_cxx_compile_stdcxx_11.html
# ===========================================================================
#
# SYNOPSIS
#
#   AX_CXX_COMPILE_STDCXX_11([ext|noext],[mandatory|optional])
#
# DESCRIPTION
#
#   Check for baseline language coverage in the compiler for the C++11
#   standard; if necessary, add switches to CXXFLAGS to enable support.
#
#   The first argument, if specified, indicates whether you insist on an
#   extended mode (e.g. -std=gnu++11) or a strict conformance mode (e.g.
#   -std=c++11).  If neither is specified, you get whatever works, with
#   preference for an extended mode.
#
#   The second argument, if specified 'mandatory' or if left unspecified,
#   indicates that baseline C++11 support is required and that the macro
#   should error out if no mode with that support is found.  If specified
#   'optional', then configuration proceeds regardless, after defining
#   HAVE_CXX11 if and only if a supporting mode is found.
#
# LICENSE
#
#   Copyright (c) 2008 Benjamin Kosnik <bkoz@redhat.com>
#   Copyright (c) 2012 Zack Weinberg <zackw@panix.com>
#   Copyright (c) 2013 Roy Stogner <roystgnr@ices.utexas.edu>
#   Copyright (c) 2014, 2015 Google Inc.; contributed by Alexey Sokolov <sokolov@google.com>
#   Copyright (c) 2015 Paul Norman <penorman@mac.com>
#   Copyright (c) 2015 Moritz Klammler <moritz@klammler.eu>
#
#   Copying and distribution of this file, with or without modification, are
#   permitted in any medium without royalty provided the copyright notice
#   and this notice are preserved. This file is offered as-is, without any
#   warranty.
#serial 18

AC_DEFUN([AX_CXX_COMPILE_STDCXX_11], [dnl
  m4_if([$1], [], [],
        [$1], [ext], [],
        [$1], [noext], [],
        [m4_fatal([invalid argument `$1' to AX_CXX_COMPILE_STDCXX_11])])dnl
  m4_if([$2], [], [ax_cxx_compile_cxx11_required=true],
        [$2], [mandatory], [ax_cxx_compile_cxx11_required=true],
        [$2], [optional], [ax_cxx_compile_cxx11_required=false],
        [m4_fatal([invalid second argument `$2' to AX_CXX_COMPILE_STDCXX_11])])
  AC_LANG_PUSH([C++])dnl
  ac_success=no

  m4_if([$1], [noext], [], [dnl
  if test x$ac_success = xno; then
    for switch in -std=gnu++11 -std=gnu++0x; do
      cachevar=AS_TR_SH([ax_cv_cxx_compile_cxx11_$switch])
      AC_CACHE_CHECK([whether $CXX supports C++11 features with $switch],
                     [$cachevar],
        [ac_save_CXXFLAGS="$CXXFLAGS"
         CXXFLAGS="$CXXFLAGS $switch"
         AC_COMPILE_IFELSE([AC_LANG_SOURCE([_AX_CXX_COMPILE_STDCXX_11_test_body])],
          [$cachevar=yes],
          [$cachevar=no])
         CXXFLAGS="$ac_save_CXXFLAGS"])
      if test x$$cachevar = xyes; then
        CXXFLAGS="$CXXFLAGS $switch"
        ac_success=yes
        break
      fi
    done
  fi])

  m4_if([$1], [ext], [], [dnl
  if test x$ac_success = xno; then
    for switch in -std=c++11 -std=c++0x; do
      cachevar=AS_TR_SH([ax_cv_cxx_compile_cxx11_$switch])
      AC_CACHE_CHECK([whether $CXX supports C++11 features with $switch],
                     [$cachevar],
        [ac_save_CXXFLAGS="$CXXFLAGS"
         CXXFLAGS="$CXXFLAGS $switch"
         AC_COMPILE_IFELSE([AC_LANG_SOURCE([_AX_CXX_COMPILE_STDCXX_11_test_body])],
          [$cachevar=yes],
          [$cachevar=no])
         CXXFLAGS="$ac_save_CXXFLAGS"])
      if test x$$cachevar = xyes; then
        CXXFLAGS="$CXXFLAGS $switch"
        ac_success=yes
        break
      fi
    done
  fi])
  AC_LANG_POP([C++])
  if test x$ax_cxx_compile_cxx11_required = xtrue; then
    if test x$ac_success = xno; then
      AC_MSG_ERROR([*** A compiler with support for C++11 language features is required.])
    fi
  else
    if test x$ac_success = xno; then
      HAVE_CXX11=0
      AC_MSG_NOTICE([No compiler with C++11 support was found])
    else
      HAVE_CXX11=1
      AC_DEFINE(HAVE_CXX11,1,
                [define if the compiler supports basic C++11 syntax])
    fi

    AC_SUBST(HAVE_CXX11)
  fi
])

dnl Test body for checking C++11 support

m4_define([_AX_CXX_COMPILE_STDCXX_11_test_body],
[_AX_CXX_COMPILE_STDCXX_11_test_body_1
_AX_CXX_COMPILE_STDCXX_11_test_body_2
])

m4_define([_AX_CXX_COMPILE_STDCXX_11_test_body_1], [dnl
  template <typename T>
    struct check
    {
      static_assert(sizeof(int) <= sizeof(T), "not big enough");
    };

    typedef check<check<bool>> right_angle_brackets;

    int a;
    decltype(a) b;

    typedef check<int> check_type;
    check_type c;
    check_type&& cr = static_cast<check_type&&>(c);

    auto d = a;
])

m4_define([_AX_CXX_COMPILE_STDCXX_11_test_body_2], [dnl
    // Check for C++11 initializer lists
    struct initlist {
      int x;
      int y;
    };
    initlist il = { 1, 2 };
])
EOF

echo "C++ project $PROJECT_NAME created in $PROJECT_DIR/"
echo "To build:"
echo "1. cd $PROJECT_DIR"
echo "2. ./autogen.sh"
echo "3. ./configure"
echo "4. make"
echo "5. ./src/$PROJECT_NAME"
