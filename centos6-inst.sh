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
baseurl=http://alice03.spbu.ru/alice/grid/lcg/soft/external.repo/
enabled=1
gpgcheck=0
EOF

cat << EOF > /etc/yum.repos.d/airtime.repo
[denis-lc]
name=airtime (denis linuxcenter)  
failovermethod=priority 
baseurl=http://alice03.spbu.ru/alice/grid/lcg/soft/airtime/x86_64/
enabled=1
gpgcheck=0
EOF

## Instalation:
yum -y install epel-release
#yum -y update
yum -y install tar gzip curl php-pear postgresql python patch lsof sudo  postgresql-server httpd php-pgsql php-gd php wget make redhat-lsb python-configobj  erlang rabbitmq-server liquidsoap ocaml ocaml-findlib.x86_64 libao libao-devel libmad libmad-devel taglib taglib-devel lame lame-devel libvorbis libvorbis-devel libtheora libtheora-devel pcre ocaml-camlp4  ocaml-camlp4-devel pcre pcre-devel gcc-c++ libX11 libX11-devel flac vorbis-tools  mp3gain monit php-bcmath icecast





# External PHP and PYTHON librory
## Installing PHP Zend package"
pear channel-discover zend.googlecode.com/svn
pear install zend/zend

## Installing python-pip
wget  http://python-distribute.org/distribute_setup.py
wget --no-check-certificate  https://raw.github.com/pypa/pip/master/contrib/get-pip.py
python distribute_setup.py
python get-pip.py

## Install virtualenv
pip install virtualenv


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


##Configure external packages:

#Monit:
mkdir -p /etc/monit/conf.d
    echo "include /etc/monit/conf.d/*" > /etc/monit.d/monit
#!!! Not need!! (may be)


#PHP
echo "date.timezone = \"Europe/Moscow\"
upload_tmp_dir = /tmp
phar.readonly = Off" >> /etc/php.ini


#Configure (create databases) postgres:

echo "psotgres configure"

service postgresql initdb

sed -i 's#host.*$#host    all         all         127.0.0.1/32          md5#g' /var/lib/pgsql/data/pg_hba.conf
#sed -i 's#host.*$#host    all         all         ::1/128               md5#g' /var/lib/pgsql/data/pg_hba.conf

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

cd 
rm -r $WDIR


