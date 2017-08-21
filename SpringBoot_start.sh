#!/usr/bin/env bash
export PROJECT_HOME=/home/admin/app
export PROJECT_HOME_SRC=$PROJECT_HOME/src
export PROJECT_HOME_LOGS_O=$PROJECT_HOME/logs/$PROJECT_NAME/${ENV}
export PROJECT_HOME_TARGET=$PROJECT_HOME/target
export PROJECT_HOME_LOGS=$PROJECT_HOME/src/app/logs
export BUILD_LOG=${PROJECT_HOME_LOGS_O}/jetty_stdout.log
if [ -n $SERVER_INDEX ];then
    BUILD_LOG=${PROJECT_HOME_LOGS_O}/jetty_stdout_$SERVER_INDEX.log
fi
export OPT_JETTY=/opt/jetty
export ANTX_PATH=/home/admin/antx-${PROJECT_NAME}.properties
JETTY_HOME=$PROJECT_HOME/.default
export MODULE_NAME=web
JETTY_PID="$JETTY_HOME/logs/jetty_$JETTY_PORT.pid"
JETTY_PS_STR="-Djetty.app."$JETTY_PORT."E"
if [ ! -d "$PROJECT_HOME_LOGS_O" ];then
    mkdir -p ${PROJECT_HOME_LOGS_O}
fi
if [ ! -d "$PROJECT_HOME_TARGET" ];then
    mkdir -p ${PROJECT_HOME_TARGET}
fi
if [ ! -d "$PROJECT_HOME_SRC" ];then
    mkdir -p ${PROJECT_HOME_SRC}
fi
if [ ! -d "$PROJECT_HOME_LOGS" ];then
    mkdir -p ${PROJECT_HOME_LOGS}
fi
if [ ! -f "$BUILD_LOG" ];then
    touch $BUILD_LOG
fi
cd $PROJECT_HOME/src/app
cd $PROJECT_HOME_SRC/app
mvn clean package -Dmaven.test.skip -U
java $JAVA_OPTIONS -jar $PROJECT_HOME_SRC/app/${PROJECT_NAME}-core/target/$PROJECT_NAME.jar --spring.profiles.active=$SPRING_PROFILES_ACTIVE --spring.dubbo.protocol.port=$SPRING_DUBBO_PROTOCOL_PORT --server.port=$JETTY_PORT | tee $BUILD_LOG 
running() {
  local PID=$(cat "$1" 2>/dev/null) || return 1
  kill -0 "$PID" 2>/dev/null
}

start() {
    if [ -f "$JETTY_PID" ]; then
        if running $JETTY_PID; then
            echo "Already Running!"
            exit 1
        else
            rm -f "$JETTY_PID"
        fi
    fi
    if [ -d "$JETTY_HOME" ]; then
        rm -rf $JETTY_HOME
    fi

    cd $PROJECT_HOME/target
    rm -rf $PROJECT_NAME.war
    tar zxf $PROJECT_HOME/target/${PROJECT_NAME}.tar.gz
    mkdir -p $JETTY_HOME
    cp -drf $OPT_JETTY/* $JETTY_HOME/.

    cd $JETTY_HOME/target
    echo $JETTY_HOME/target
    ln -s $PROJECT_HOME/target/${PROJECT_NAME}.war .
    if [ ! -z ${JETTY_DEBUG_PORT} ]; then
        JAVA_OPTIONS="$JAVA_OPTIONS -Xdebug -XX:PermSize=96m -XX:MaxPermSize=384m -agentlib:jdwp=transport=dt_socket,address=${JETTY_DEBUG_PORT},server=y,suspend=n"
    fi
    sed -i "s/name=\"jetty.port\"\s\+default=\"[[:digit:]]\{2,5\}\"/name=\"jetty.port\" default=\"$JETTY_PORT\"/g" $JETTY_HOME/etc/jetty.xml
    pid=`ps -C java  | grep -- "$JETTY_PS_STR" | awk '{print $2}'`
    touch "$JETTY_PID"
    echo "$pid" > "$JETTY_PID"
}

stop() {
    echo -n "Stopping Jetty: "
    PID=$(cat "$JETTY_PID" 2>/dev/null)
    kill "$PID" 2>/dev/null
    rm -f "$JETTY_PID"
    echo OK

    STR=`ps -C java  | grep -- "$JETTY_PS_STR"`
    if [ ! -z "$STR" ]; then
        echo ""
    else
        echo ""
    fi

    for i in `seq 1 5`
    do
        STR=`ps -C java  | grep -- "$JETTY_PS_STR"`
        if [ -z "$STR" ]; then
            echo
            break
        fi
        echo -ne "\r"
        sleep 1
    done
    echo "remove .default dir"
    rm -rf $PROJECT_HOME/.default
}
