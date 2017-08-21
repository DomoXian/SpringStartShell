#!/usr/bin/env bash
PROJECT_NAME=moyu
PROJECT_HOME=/home/admin/app/
JAR_DIR=${PROJECT_NAME}-core/target
JAR_NAME=${PROJECT_NAME}.jar
cd ${PROJECT_HOME}
ls
mvn clean install -Dmaven.test.skip&& mvn package -Dmaven.test.skip
cd ${JAR_DIR}
MOYU_PID=`ps -ef | grep "moyu" | grep -v grep | awk '{print $2}'`
echo "Moyu PID = $MOYU_PID"
#kill -9 MOYU_PID
java -jar ${JAR_NAME} --spring.profiles.active=dev
