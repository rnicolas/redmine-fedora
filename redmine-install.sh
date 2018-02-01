#!/bin/bash
#installing redmine fedora 27 server
dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf -y update
#as root or sudo
#ruby
dnf install -y ruby ruby-devel ImageMagick-devel libxml2-devel gcc redhat-rpm-config
#postgres
dnf install -y postgresql-server postgresql-contrib postgresql-devel
systemctl enable postgresql
postgresql-setup --initdb --unit postgresql
systemctl start postgresql
# make it last after reboot
firewall-cmd --permanent --add-port=5432/tcp
# change runtime configuration
firewall-cmd --add-port=5432/tcp
dnf -y install policycoreutils-python-utils
setsebool -P httpd_can_network_connect_db on
pushd /var/lib/pgsql/data
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" ./postgresql.conf
sed -i "s/host    all             all             127.0.0.1\/32            ident/host    all             all             0.0.0.0\/0            md5/" ./pg_hba.conf
systemctl restart postgresql
popd

PG_REDMINE_PASSWD=$(openssl rand -base64 32)
#echo $PG_REDMINE_PASSWD

pushd /tmp
sudo -u postgres bash << EOF
psql -c "CREATE ROLE redmine LOGIN ENCRYPTED PASSWORD '$PG_REDMINE_PASSWD' NOINHERIT VALID UNTIL 'infinity';"
psql -c "CREATE DATABASE redmine WITH ENCODING='UTF8' OWNER=redmine;"
EOF
popd
setenforce 0
wget http://www.redmine.org/releases/redmine-3.4.4.tar.gz
tar zxf redmine-3.4.4.tar.gz
rm -f redmine-3.4.4.tar.gz
mv -f redmine-3.4.4/ /opt/redmine
cd /opt/redmine
pushd config

touch database.yml
cat > database.yml << EOF
production:
  adapter: postgresql
  database: redmine
  host: localhost
  username: redmine
  password: $PG_REDMINE_PASSWD
EOF

popd
gem install bundler
/usr/local/bin/bundler install --without development test

echo "Check if the installation succeded"
#bundle exec rails server -b 0.0.0.0 webrick -e production
#This dependencies are necessary if passenger is installed via gem install passenger
#dnf -y install httpd curl-devel httpd-devel openssl-devel apr-devel apr-util-devel
dnf -y install httpd mod_passenger

cat > /etc/httpd/conf/httpd.conf << "EOF"
<VirtualHost *:80>
   ServerName redmine.aeinnova.aei

   DocumentRoot /var/www/html

   Alias /redmine /opt/redmine

   <Location /redmine>
      PassengerBaseURI /redmine
      PassengerAppRoot /opt/redmine
   </Location>

   <Directory /opt/redmine/public>
      # This relaxes Apache security settings.
      AllowOverride all
      # MultiViews must be turned off.
      Options -MultiViews
      # Uncomment this if you're on Apache >= 2.4:
      Require all granted
   </Directory>
</VirtualHost>
EOF

setsebool httpd_can_network_connect 1
systemctl restart httpd
setenforce 1

echo "Password database for redmine"
echo $PG_REDMINE_PASSWD
