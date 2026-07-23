#!/bin/bash
set -e

echo "Installing tp-sdkman-java and verifying Java/SDKMAN..."
apt-get update
apt-get install -y tp-sdkman-java

echo "Testing SDKMAN & JAVA_HOME environment as developer user..."
su - developer << 'EOF'
set -e
source /etc/profile
java -version
javac -version

mkdir -p /tmp/java-test && cd /tmp/java-test
cat > HelloWorld.java << 'JAVA_EOF'
public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
    }
}
JAVA_EOF
javac HelloWorld.java
output=$(java HelloWorld)
echo "Java Execution Output: $output"
if [ "$output" != "Hello, World!" ]; then
  echo "Java output mismatch!"
  exit 1
fi
EOF

# Test package uninstallation teardown
echo "Testing tp-sdkman-java removal and teardown..."
apt-get remove -y tp-sdkman-java
if [ -d "/opt/sdkman" ] || [ -f "/etc/profile.d/sdkman.sh" ]; then
    echo "Error: /opt/sdkman or sdkman.sh was not completely removed on apt-get remove!"
    exit 1
fi
echo "Verified: /opt/sdkman and all managed SDKs were cleanly removed."

# Reinstall for subsequent package tests in pipeline
apt-get install -y tp-sdkman-java
echo "✅ Java 25 & SDKMAN compilation, execution, and uninstallation teardown passed!"
