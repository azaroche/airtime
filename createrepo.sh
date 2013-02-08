PW=`pwd`;

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

