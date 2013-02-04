#/bin/sh!
PW=`pwd`;


prepare()
{
#create workdir
WDIR=`mktemp -d`
chmod 755 $WDIR/
cd  $WDIR

# Packages:
## Repositories:

cat << EOF > /etc/yum.repos.d/ext.repo
[extrnal-zar]
name=external repo
failovermethod=priority
baseurl=file://$PW/external.repo/
enabled=1
gpgcheck=0
EOF

cat << EOF > /etc/yum.repos.d/airtime.repo
[denis-lc]
name=airtime (denis linuxcenter)  
failovermethod=priority 
baseurl=file://$PW/airtime/x86_64/
enabled=1
gpgcheck=0
EOF

## Instalation:
yum -y install epel-release
#yum -y update
yum -y install tar gzip curl php-pear postgresql python patch lsof sudo  postgresql-server httpd php-pgsql php-gd php wget make redhat-lsb python-configobj  erlang rabbitmq-server liquidsoap ocaml ocaml-findlib.x86_64 libao libao-devel libmad  taglib taglib-devel  libvorbis libvorbis-devel libtheora libtheora-devel pcre ocaml-camlp4  ocaml-camlp4-devel pcre pcre-devel gcc-c++ libX11 libX11-devel flac vorbis-tools  monit php-bcmath icecast php-process php-ZendFramework-Db-Adapter-Pdo-Pgsql python-virtualenv






# External PHP and PYTHON librory
## Installing PHP Zend package"
#pear channel-discover zend.googlecode.com/svn
#pear install zend/zend

## Installing python-pip
#wget  http://python-distribute.org/distribute_setup.py
#wget --no-check-certificate  https://raw.github.com/pypa/pip/master/contrib/get-pip.py
#python distribute_setup.py
#python get-pip.py

## Install virtualenv
#pip install virtualenv

cd;
rm -rf $WDIR

}


airtime_install()
{

#create workdir
WDIR=`mktemp -d`
chmod 755 $WDIR/
cd  $WDIR

# Airtime install:
##Download:
wget http://sourceforge.net/projects/airtime/files/2.2.1/airtime-2.2.1.tar.gz
tar -xvf airtime-2.2.1.tar.gz
$WDIR/airtime-2.2.1/python_apps/python-virtualenv/virtualenv-install.sh

#configure web files
cp $WDIR/airtime-2.2.1/install_full/apache/airtime-vhost /etc/httpd/conf.d/airtime.conf
sed -i 's#DocumentRoot.*$#DocumentRoot /var/www/html/airtime/public#g' /etc/httpd/conf.d/airtime.conf
sed -i 's#<Directory .*$#<Directory /var/www/html/airtime/public>#g' /etc/httpd/conf.d/airtime.conf

echo "* Copying Airtime web files"
mkdir -p /var/www/html/airtime
cp -R $WDIR/airtime-2.2.1/airtime_mvc/* /var/www/html/airtime/


##Configure AirTime:
adduser --system --user-group airtime
adduser --system --user-group pypo

mkdir -p /etc/airtime
mkdir -p /srv/airtime/stor
mkdir -p /var/log/airtime
mkdir -p /etc/monit/conf.d
echo "include /etc/monit/conf.d/*" > /etc/monit.d/monit

cp $WDIR/airtime-2.2.1/airtime_mvc/build/airtime.conf /etc/airtime/airtime.conf

CHAR="[:alnum:]"
rand=`cat /dev/urandom | tr -cd "$CHAR" | head -c ${1:-32}`
sed -i "s/api_key = .*$/api_key = $rand/g" /etc/airtime/airtime.conf

python $WDIR/airtime-2.2.1/python_apps/api_clients/install/api_client_install.py
cp -R $WDIR/airtime-2.2.1/python_apps/std_err_override /usr/lib/airtime
python $WDIR/airtime-2.2.1/python_apps/media-monitor/install/media-monitor-copy-files.py
python $WDIR/airtime-2.2.1/python_apps/media-monitor/install/media-monitor-initialize.py
python $WDIR/airtime-2.2.1/python_apps/pypo/install/pypo-copy-files.py
python $WDIR/airtime-2.2.1/python_apps/pypo/install/pypo-initialize.py

sed -i "s/api_key = .*$/api_key = \'$rand\'/g"   /etc/airtime/api_client.cfg
touch  /var/log/airtime/zendphp.log
chown apache:  /var/log/airtime/zendphp.log
chown -R  apache: /srv/airtime/stor

cp -r $WDIR/airtime-2.2.1/utils /usr/lib/airtime/utils/


if [ "AA$DEBUG" != "AAdebug" ]; then
	cd;
	rm -rf $WDIR;
else
	echo "workdir :  $WDIR"
fi

}

configure()
{

##Configure external packages:

#Monit:
#mkdir -p /etc/monit/conf.d
#    echo "include /etc/monit/conf.d/*" > /etc/monit.d/monit
#!!! Not need!! (may be)


#PHP
echo "date.timezone = \"Europe/Moscow\"
upload_tmp_dir = /tmp
phar.readonly = Off" >> /etc/php.ini


#Configure (create databases) postgres:

echo "psotgres configure"

service postgresql initdb

mv /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.save

echo "
local   all         all                               ident
host    all         all         127.0.0.1/32          md5
host    all         all         ::1/128               md5
" > /var/lib/pgsql/data/pg_hba.conf

service postgresql stop

service postgresql start

chkconfig postgresql on

sudo -u postgres psql -c "CREATE USER airtime ENCRYPTED PASSWORD 'airtime' LOGIN CREATEDB NOCREATEUSER;"

sudo -u postgres createdb -O airtime --encoding UTF8 airtime

cd $WDIR/airtime-2.2.1/airtime_mvc/build/sql/

sudo -u airtime psql --file schema.sql airtime

    sudo -u airtime psql --file sequences.sql airtime
    sudo -u airtime psql --file views.sql airtime
    sudo -u airtime psql --file triggers.sql airtime
    sudo -u airtime psql --file defaultdata.sql airtime
    sudo -u airtime psql -c "INSERT INTO cc_pref (keystr, valstr) VALUES ('system_version', '2.2.1');"
    sudo -u airtime psql -c "INSERT INTO cc_music_dirs (directory, type) VALUES ('/srv/airtime/stor', 'stor');"
    sudo -u airtime psql -c "INSERT INTO cc_pref (keystr, valstr) VALUES ('timezone', 'UTC')"
    unique_id=`php -r "echo md5(uniqid('', true));"`
    sudo -u airtime psql -c "INSERT INTO cc_pref (keystr, valstr) VALUES ('uniqueId', '$unique_id')"
    sudo -u airtime psql -c "INSERT INTO cc_pref (keystr, valstr) VALUES ('import_timestamp', '0')"


service httpd start
chkconfig httpd on

service icecast start
chkconfig icecast on

service rabbitmq-server start
chkconfig rabbitmq-server on

echo "LANG=en_US.UTF-8" > /etc/default/locale


echo "Startup scripts configure";
echo "remove drbian scripts"

rm -f /etc/init.d/airtime-*

echo "write rhel scripts airtime-liquidsoap";

cat << EOF > /etc/init.d/airtime-liquidsoap
#!/bin/bash

# airtime  liquidsoap        Start up the airtime-liquidsoap server daemon
#
# chkconfig: 2345 97 24
# description: airtiime liquidsoap
#
#
# processname: airtime-liquidsoap
#


### BEGIN INIT INFO
# Provides:          airtime-liquidsoap
# Required-Start:    \$local_fs \$remote_fs \$network \$syslog
# Required-Stop:     \$local_fs \$remote_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Liquidsoap daemon
### END INIT INFO

USERID=pypo
GROUPID=pypo
NAME="Liquidsoap Playout Engine"

DAEMON=/usr/lib/airtime/pypo/bin/airtime-liquidsoap
PIDFILE=/var/run/airtime-liquidsoap.pid

start () {
        chown pypo:pypo /var/log/airtime/pypo
        chown pypo:pypo /var/log/airtime/pypo-liquidsoap
	setenforce 0
	

        PID=\`su  pypo -c \$DAEMON > /dev/null 2>&1 & echo \$!\`
        echo "PID=\$PID"
        if [ -z \$PID ]; then
            printf "%s\n" "Fail"
        else
            echo \$PID > \$PIDFILE
            printf "%s\n" "Ok"
        fi

        monit monitor airtime-liquidsoap >/dev/null 2>&1
}

stop () {
        monit unmonitor airtime-liquidsoap >/dev/null 2>&1
        /usr/lib/airtime/airtime_virtualenv/bin/python /usr/lib/airtime/pypo/bin/liquidsoap_scripts/liquidsoap_prepare_terminate.py
        printf "\n %-50s" "Stopping \$NAME"
        if [ -f \$PIDFILE ]; then
            PID=\`cat \$PIDFILE\`
            kill  \$PID
            printf "%s\n" "Ok"
            rm -f \$PIDFILE
        else
                    printf "%s\n" "pidfile not found"
        fi
        rm -f \$PIDFILE



}

start_no_monit() {
        chown pypo:pypo /etc/airtime
        chown pypo:pypo /etc/airtime/liquidsoap.cfg
        PID=\`su  pypo -c \$DAEMON > /dev/null 2>&1 & echo \$!\`
        echo "PID=\$PID"
        if [ -z \$PID ]; then
            printf "%s\n" "Fail"
        else
            echo \$PID > \$PIDFILE
            printf "%s\n" "Ok"
        fi
}


case "\${1:-''}" in
  'stop')
           echo -n "Stopping Liquidsoap: "
           stop
           echo "Done."
        ;;
  'start')
           echo -n "Starting Liquidsoap: "
           start
           echo "Done."
        ;;
  'restart')
           # restart commands here
           echo -n "Restarting Liquidsoap: "
           stop
           start
           echo "Done."
        ;;

  'status')
        if [ -f "\$PIDFILE" ]; then
            pid=\`cat /var/run/airtime-liquidsoap.pid\`
            if [ -d "/proc/\$pid" ]; then
                echo "Liquidsoap is running"
                exit 0
            fi
        fi
        echo "Liquidsoap is not running"
        exit 1
        ;;
  'start-no-monit')
           # restart commands here
           echo -n "Starting \$NAME: "
           start_no_monit
           echo "Done."
        ;;

  *)      # no parameter specified
        echo "Usage: \$SELF start|stop|restart"
        exit 1
        ;;

esac

EOF

echo "write rhel scripts airtime-playout";


cat << EOF > /etc/init.d/airtime-playout
#!/bin/bash

# airtime  playout        Start up the airtime-playout server daemon
#
# chkconfig: 2345 96 24
# description: airtime playout
#
#
# processname: airtime-playout
#

### BEGIN INIT INFO
# Provides:          airtime-playout
# Required-Start:    \$local_fs \$remote_fs \$network \$syslog
# Required-Stop:     \$local_fs \$remote_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Manage airtime-playout daemon
### END INIT INFO

USERID=root
NAME="Airtime Scheduler Engine"

DAEMON=/usr/lib/airtime/pypo/bin/airtime-playout
PIDFILE=/var/run/airtime-playout.pid

start () {
        printf "%-50s" "Starting \$NAME..."
        chown pypo:pypo /etc/airtime
        chown pypo:pypo /etc/airtime/liquidsoap.cfg

	setenforce 0

        PID=\`su  pypo -c \$DAEMON > /dev/null 2>&1 & echo \$!\`
        echo "PID=\$PID"
        if [ -z \$PID ]; then
            printf "%s\n" "Fail"
        else
            echo \$PID > \$PIDFILE
            printf "%s\n" "Ok"
        fi

        monit monitor airtime-playout >/dev/null 2>&1
}

stop () {
        monit unmonitor airtime-playout >/dev/null 2>&1
        printf "\n %-50s" "Stopping \$NAME"
        if [ -f \$PIDFILE ]; then
            PID=\`cat \$PIDFILE\`
            kill  \$PID
            printf "%s\n" "Ok"
            rm -f \$PIDFILE
        else
                    printf "%s\n" "pidfile not found"
        fi
        rm -f \$PIDFILE

}

start_no_monit() {
        chown pypo:pypo /etc/airtime
        chown pypo:pypo /etc/airtime/liquidsoap.cfg
        PID=\`su  pypo -c \$DAEMON > /dev/null 2>&1 & echo \$!\`
        echo "PID=\$PID"
        if [ -z \$PID ]; then
            printf "%s\n" "Fail"
        else
            echo \$PID > \$PIDFILE
            printf "%s\n" "Ok"
        fi
}

case "\${1:-''}" in
  'start')
            # start commands here
            echo -n "Starting \$NAME: "
            start
            echo "Done."
        ;;
  'stop')
            # stop commands here
            echo -n "Stopping \$NAME: "
            stop
            echo "Done."
        ;;
  'restart')
           # restart commands here
           echo -n "Restarting \$NAME: "
           stop
           start
           echo "Done."
        ;;
  'start-no-monit')
           # restart commands here
           echo -n "Starting \$NAME: "
           start_no_monit
           echo "Done."
        ;;
  'status')
           # status commands here
           /usr/lib/airtime/utils/airtime-check-system
        ;;
  *)      # no parameter specified
        echo "Usage: \$SELF start|stop|restart|status"
        exit 1
        ;;

esac
EOF

echo "write rhel scripts media-monitor";

cat << EOF > /etc/init.d/airtime-media-monitor
#!/bin/bash
# airtime-media-monitor          Start up the airtime-media-monitor server daemon
#
# chkconfig: 2345 95 25
# description: airtime media monitor
#
#
# processname: airtime-media-monitor
#
### BEGIN INIT INFO
# Provides:          airtime-media-monitor
# Required-Start:    \$local_fs \$remote_fs \$network \$syslog
# Required-Stop:     \$local_fs \$remote_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Manage airtime-media-monitor daemon
### END INIT INFO

. /etc/init.d/functions

SCRIPTNAME=/etc/init.d/airtime-media-monitor
USERID=root
GROUPID=www-data
NAME=Airtime\ Media\ Monitor

DAEMON=/usr/lib/airtime/media-monitor/airtime-media-monitor
PIDFILE=/var/run/airtime-media-monitor.pid

start () {
        PID=\`\$DAEMON > /dev/null 2>&1 & echo \$!\`
        RETVAL=\$?
        monit monitor airtime-media-monitor >/dev/null 2>&1
#       echo
#        return \$RETVAL
        echo "PID=\$PID"
        if [ -z \$PID ]; then
            printf "%s\n" "Fail"
        else
            echo \$PID > \$PIDFILE
            printf "%s\n" "Ok"
        fi
}

stop () {
        monit unmonitor airtime-media-monitor >/dev/null 2>&1
        printf "%-50s" "Stopping \$NAME"
        if [ -f \$PIDFILE ]; then
            PID=\`cat \$PIDFILE\`
            kill -HUP \$PID
            printf "%s\n" "Ok"
            rm -f \$PIDFILE
        else
                    printf "%s\n" "pidfile not found"
        fi
        rm -f \$PIDFILE
}

start_no_monit() {
        PID=\`su \$USERID:\$GROUPID -c \$DAEMON > /dev/null 2>&1 & echo \$!\`
        RETVAL=\$?
        echo
        return \$RETVAL
        if [ -z \$PID ]; then
            printf "%s\n" "Fail"
        else
            echo \$PID > \$PIDFILE
            printf "%s\n" "Ok"
        fi
}


case "\${1:-''}" in
  'start')
            # start commands here
            echo -n "Starting \$NAME: "
            start
            echo "Done."
        ;;
  'stop')
            # stop commands here
            echo -n "Stopping \$NAME: "
            stop
            echo "Done."
        ;;
  'restart')
           # restart commands here
           echo -n "Restarting \$NAME: "
           stop
           start
           echo "Done."
        ;;
  'start-no-monit')
           # restart commands here
           echo -n "Starting \$NAME: "
           start_no_monit
           echo "Done."
        ;;
  'status')
           # status commands here
           #/usr/bin/airtime-check-system
           /usr/lib/airtime/utils/airtime-check-system
        ;;
  *)      # no parameter specified
        echo "Usage: \$SELF start|stop|restart|status"
        exit 1
        ;;
esac
EOF

echo "start airtime sevices";

for i in airtime-media-monitor airtime-playout airtime-liquidsoap ; do 
	chmod +x /etc/init.d/$i
	service $i start;
	chkconfig $i on;
done



echo "chown -R  apache: /srv/airtime/stor"
chown -R  apache: /srv/airtime/stor

}

command=""

while [ -n "$1" ]; do
  case "$1" in
	--debug|-d)
		echo "DEBUG on";
		DEBUG=debug;
		shift;
	;;
	--prepare)
		command="$command 
prepare";
		shift;
	;;
	--install)
		command="$command 
airtime_install";
		shift;
	;;
	--configure)
		command="$command 
configure";
		shift;
	;;
	--wdir|-w)
		shift;
		WDIR=$1
		echo "Change wdir to $WDIR";
		shift;
		;;
	--all)
		command="$command 
prepare
airtime_install
configure";
		shift;
	;;
	*)
		echo "Usage: 
--debug|-d
--prepare
--install
--configure
--all
--wdir|-w 'dirname'
"
		exit 1
	;;
  esac

done
echo $command

$command;	

