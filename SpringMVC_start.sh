#!/usr/bin/env bash
export PROJECT_HOME=/home/admin/app
export PROJECT_HOME_SRC=$PROJECT_HOME/src
export PROJECT_HOME_LOGS_O=$PROJECT_HOME/logs/$PROJECT_NAME/$ENV
export PROJECT_HOME_TARGET=$PROJECT_HOME/target
export PROJECT_HOME_LOGS=$PROJECT_HOME/src/app/logs
export BUILD_LOG=${PROJECT_HOME_LOGS_O}/${ANTX_PREFIX}jetty_stdout.log
export OPT_JETTY=/opt/jetty
export ANTX_PATH=/home/admin/antx-${PROJECT_NAME}.properties
export RAW_ANTX_PATH=/home/publish/antx/${TEAM_NAME}/${ENV}
if [ -z "$TEAM_NAME" ];then
    RAW_ANTX_PATH=/home/publish/antx-${ENV}
fi 
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
if [ "$ENV" == "dev" ] || [ "$ENV" == "test" ] || [ "$ENV" == "daily" ];then
    sshpass -p 'taobao1234' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null publish@172.21.10.70:${RAW_ANTX_PATH}/${ANTX_PREFIX}${ANTX}-${PROJECT_NAME}.properties /home/admin/${ANTX}-${PROJECT_NAME}.properties
else      
    sshpass -p 'Us5603ldJz80mHs258' scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null publish@publish.dawanju.net:/home/publish/antx/${ANTX}-${PROJECT_NAME}-${ENV}.properties /home/admin/${ANTX}-${PROJECT_NAME}.properties
fi

cd $PROJECT_HOME/src/app
cd $PROJECT_HOME_SRC
sed -i "s/dubbo.protocol.port  = [[:digit:]]\{2,5\}/dubbo.protocol.port  = ${#SPRING_DUBBO_PROTOCOL_PORT}/g" $ANTX_PATH
cd $PROJECT_HOME_SRC/app
mvn clean package -Dmaven.test.skip -U
cd $PROJECT_HOME_SRC/app/$PROJECT_NAME-deploy/src/main/assembly
sed -i 's|../${PROJECT_NAME}-web/target/${PROJECT_NAME}-web-1.0-SNAPSHOT|../${PROJECT_NAME}-'${MODULE_NAME}'/target/${PROJECT_NAME}-'${MODULE_NAME}'-1.0-SNAPSHOT|g' assembly.xml

cd $PROJECT_HOME_SRC/app/$PROJECT_NAME-deploy
mvn assembly:assembly
mkdir -p $PROJECT_NAME/target
cp -af  $PROJECT_HOME_SRC/app/$PROJECT_NAME-deploy/target/$PROJECT_NAME.tar.gz $PROJECT_HOME/target/$PROJECT_NAME.tar.gz

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
    $JAVA_HOME/bin/java $JAVA_OPTIONS -Dfile.encoding=UTF8 -Duser.timezone=GMT+08 $JETTY_PS_STR -Djetty.home=$JETTY_HOME -Dproject.name=$PROJECT_NAME -Ddubbo.protocol.port=$SPRING_DUBBO_PROTOCOL_PORT -Dproject.home=$PROJECT_HOME -jar $JETTY_HOME/start.jar --ini=$JETTY_HOME/start.ini 2>&1 | tee $BUILD_LOG
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
stop
start
