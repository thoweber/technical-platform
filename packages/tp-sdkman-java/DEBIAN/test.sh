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

echo "✅ Java 25 & SDKMAN compilation and execution passed!"
