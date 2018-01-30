wget http://www.redmine.org/releases/redmine-3.4.4.tar.gz
mkdir /usr/local/redmine
echo "Check if the installation succeded"
bundle exec rails server -b 0.0.0.0 webrick -e production
#This dependencies are necessary if passenger is installed via gem install passenger
#dnf -y install httpd curl-devel httpd-devel openssl-devel apr-devel apr-util-devel
dnf -y httpd install mod_passenger
