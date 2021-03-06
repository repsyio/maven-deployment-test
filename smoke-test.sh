#!/usr/bin/env bash
set -e

CURRENT_DIR=$(pwd)
BASE_DIR=$(dirname "$0")

cd "$BASE_DIR"

if [ -z "$REPSY_BASE_URL" ]; then
  export REPSY_BASE_URL="https://repo.repsy.io"
fi

export REPSY_USERNAME="$1"
export REPSY_REPO_NAME="$2"
export REPSY_REPO_PASSWORD="$3"

if [ "$#" != 3 ]; then
  echo 'usage: ./smoke-test.sh username repo_name repo_password'
  exit 1
fi

EXEC_VALUE=""

save_maven_settings() {

  mkdir -p ~/.m2

  if [ -f ~/.m2/settings.xml ]; then
    cp ~/.m2/settings.xml ~/.m2/settings.xml.repsy_backup
  fi

  cat <<EOF >~/.m2/settings.xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
    http://maven.apache.org/xsd/settings-1.0.0.xsd">

    <servers>
        <server>
            <id>repsy</id>
            <username>${REPSY_USERNAME}</username>
            <password>${REPSY_REPO_PASSWORD}</password>
        </server>
    </servers>
</settings>
EOF
}

rollback_maven_settings() {
  if [ -f ~/.m2/settings.xml.repsy_backup ]; then
    cp ~/.m2/settings.xml.repsy_backup ~/.m2/settings.xml
  fi
}

deploy() {
  TEST_VALUE="$1"

  cd test-project-deploy
  mv src/main/java/io/repsy/deploy_test/Secret.java \
    src/main/java/io/repsy/deploy_test/Secret.java.backup
  cat <<EOF >src/main/java/io/repsy/deploy_test/Secret.java
package io.repsy.deploy_test;

public class Secret {

    public static void printSecret() {
        System.out.println("${TEST_VALUE}");
    }
}
EOF
  ./mvnw deploy

  mv src/main/java/io/repsy/deploy_test/Secret.java.backup \
    src/main/java/io/repsy/deploy_test/Secret.java

  cd ../
}

download_and_test() {

  cd test-project-download
  ./mvnw compile dependency:copy-dependencies
  cd target/classes
  EXEC_VALUE=$(java -cp ../dependency/deploy-test-1.0.jar:. io.repsy.download_test.Main)
  cd ../../../
}

save_maven_settings
RANDOM_VALUE=$(openssl rand -base64 12)
deploy "$RANDOM_VALUE"
download_and_test

if [ "$RANDOM_VALUE" != "$EXEC_VALUE" ]; then
  exit 1
fi

# Redeploy
RANDOM_VALUE=$(openssl rand -base64 12)
deploy "$RANDOM_VALUE"
download_and_test

if [ "$RANDOM_VALUE" != "$EXEC_VALUE" ]; then
  exit 1
fi

rollback_maven_settings

cd "$CURRENT_DIR"
