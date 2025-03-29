#!/bin/bash

# Function to display help
show_help() {
    cat <<EOF
Usage: $0 <project-name>

Generates a Java console application project with:
- Standard Java project structure
- Ant build system (build.xml)
- Build directory for distribution files
- Main class template
- .gitignore for Java projects

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

PROJECT_NAME="$1"
PROJECT_DIR="${PROJECT_NAME}"
PACKAGE_NAME=$(echo "${PROJECT_NAME}" | tr '[:upper:]' '[:lower:]')
MAIN_CLASS="Main"

echo "Creating Java console application project: ${PROJECT_NAME}..."

# Create directory structure
mkdir -p "${PROJECT_DIR}/src/main/java/${PACKAGE_NAME}"
mkdir -p "${PROJECT_DIR}/src/test/java/${PACKAGE_NAME}"
mkdir -p "${PROJECT_DIR}/lib"
mkdir -p "${PROJECT_DIR}/build/classes"
mkdir -p "${PROJECT_DIR}/dist"

# Create README.md
cat > "${PROJECT_DIR}/README.md" <<EOF
# ${PROJECT_NAME}

A Java console application.

## Building the Project

1. Compile and package:
   \`\`\`bash
   ant build
   \`\`\`

2. Run the application:
   \`\`\`bash
   ant run
   \`\`\`

3. Create distributable JAR:
   \`\`\`bash
   ant jar
   \`\`\`

## Project Structure

- \`src/main/java/\` - Application source code
- \`src/test/java/\` - Test cases
- \`lib/\` - Third-party libraries
- \`build/\` - Compiled classes
- \`dist/\` - Output JAR files
EOF

# Create build.xml
cat > "${PROJECT_DIR}/build.xml" <<EOF
<project name="${PROJECT_NAME}" default="build" basedir=".">
    <property name="src.dir" location="src/main/java"/>
    <property name="test.src.dir" location="src/test/java"/>
    <property name="build.dir" location="build/classes"/>
    <property name="dist.dir" location="dist"/>
    <property name="lib.dir" location="lib"/>
    <property name="main.class" value="${PACKAGE_NAME}.${MAIN_CLASS}"/>

    <path id="classpath">
        <fileset dir="\${lib.dir}" includes="**/*.jar"/>
    </path>

    <target name="clean">
        <delete dir="\${build.dir}"/>
        <delete dir="\${dist.dir}"/>
    </target>

    <target name="init">
        <mkdir dir="\${build.dir}"/>
        <mkdir dir="\${dist.dir}"/>
    </target>

    <target name="compile" depends="init">
        <javac srcdir="\${src.dir}" destdir="\${build.dir}" includeantruntime="false">
            <classpath refid="classpath"/>
        </javac>
    </target>

    <target name="build" depends="compile">
        <echo message="Project built successfully!"/>
    </target>

    <target name="run" depends="compile">
        <java classname="\${main.class}" fork="true">
            <classpath>
                <path refid="classpath"/>
                <pathelement location="\${build.dir}"/>
            </classpath>
        </java>
    </target>

    <target name="jar" depends="compile">
        <jar destfile="\${dist.dir}/\${ant.project.name}.jar" basedir="\${build.dir}">
            <manifest>
                <attribute name="Main-Class" value="\${main.class}"/>
            </manifest>
        </jar>
    </target>

    <target name="test" depends="compile">
        <javac srcdir="\${test.src.dir}" destdir="\${build.dir}" includeantruntime="false">
            <classpath refid="classpath"/>
        </javac>
        <echo message="Run your test classes manually or add junit tasks here"/>
    </target>
</project>
EOF

# Create main Java class
cat > "${PROJECT_DIR}/src/main/java/${PACKAGE_NAME}/${MAIN_CLASS}.java" <<EOF
package ${PACKAGE_NAME};

public class ${MAIN_CLASS} {
    public static void main(String[] args) {
        System.out.println("Hello from ${PROJECT_NAME}!");
        
        // Your application logic here
        for (int i = 0; i < 3; i++) {
            System.out.println("Counting: " + (i + 1));
        }
    }
}
EOF

# Create .gitignore
cat > "${PROJECT_DIR}/.gitignore" <<EOF
# Build artifacts
/build/
/dist/

# IDE files
*.class
*.jar
*.war
*.ear
*.iml
.idea/
*.ipr
*.iws
*.swp
.DS_Store

# Log files
*.log
EOF

# Create simple test example
mkdir -p "${PROJECT_DIR}/src/test/java/${PACKAGE_NAME}"
cat > "${PROJECT_DIR}/src/test/java/${PACKAGE_NAME}/${MAIN_CLASS}Test.java" <<EOF
package ${PACKAGE_NAME};

import org.junit.Test;
import static org.junit.Assert.*;

public class ${MAIN_CLASS}Test {
    @Test
    public void sampleTest() {
        assertTrue("Example test case", true);
    }
}
EOF

echo "Java project ${PROJECT_NAME} created in ${PROJECT_DIR}/"
echo "To build and run:"
echo "1. cd ${PROJECT_DIR}"
echo "2. ant build   # Compiles the project"
echo "3. ant run     # Runs the application"
echo "4. ant jar     # Creates executable JAR in dist/"
echo ""
echo "Note: Ensure you have Ant installed (sudo apt-get install ant)"
