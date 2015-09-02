#!/bin/bash
#
# Init file for Tomcat server
#
# chkconfig: 345 99 15
# description:  Start up the Tomcat servlet engine.
# config: /etc/sysconfig/tomcat
# processname: tomcat
# pidfile: /var/run/tomcat.pid
#

# Source function library.
. /etc/init.d/functions

RUN_AS_USER=app
CATALINA_HOME=/usr/local/tomcat

# Loading the override configuration parameters.
if [ -f /etc/sysconfig/tomcat ]; then
  . /etc/sysconfig/tomcat
fi

# Some functions to make the below more readable
START="$CATALINA_HOME/bin/startup.sh"
STOP="$CATALINA_HOME/bin/shutdown.sh"

if [ -e "$CATALINA_HOME/bin/fmsstart.sh" ]; then
    START="$CATALINA_HOME/bin/fmsstart.sh"
fi

if [ -e "$CATALINA_HOME/bin/fmsstop.sh" ]; then
    STOP="$CATALINA_HOME/bin/fmsstop.sh"
fi

echo "START is $START"
echo "STOP is $STOP"

start() {
        logger -s "Starting Tomcat"
        if [ "x$USER" != "x$RUN_AS_USER" ]; then
          /bin/su -l $RUN_AS_USER -c "$START"
          RETVAL=$?
          [ $RETVAL = 0 ] && touch /var/lock/subsys/tomcat
        else
          $START
          RETVAL=$?
          [ $RETVAL = 0 ] && touch /var/lock/subsys/tomcat
        fi
        echo "done."
}

stop() {
        logger -s "Stopping Tomcat"
        if [ "x$USER" != "x$RUN_AS_USER" ]; then
          /bin/su -l $RUN_AS_USER -c "$STOP"
          RETVAL=$?
          [ $RETVAL = 0 ] && touch /var/lock/subsys/tomcat
        else
          $STOP
          RETVAL=$?
          [ $RETVAL = 0 ] && touch /var/lock/subsys/tomcat
        fi
        echo "done."
}

version() {
        if [ -f $CATALINA_HOME/bin/version.sh ]; then
          logger -s "Display Tomcat Version"
          if [ "x$USER" != "x$RUN_AS_USER" ]; then
              /bin/su -l $RUN_AS_USER -c $CATALINA_HOME/bin/version.sh
              RETVAL=$?
          else
              $CATALINA_HOME/bin/version.sh
              RETVAL=$?
          fi
        fi
}

case "$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  version)
        version
        ;;
  restart)
        stop
        sleep 10
        #echo "Hard killing any remaining threads.."
        #kill -9 `cat $CATALINA_HOME/work/catalina.pid`
        start
        ;;
  *)
        echo "Usage: $0 {start|stop|restart|version}"
esac

exit 0
