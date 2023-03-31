#!/bin/bash

# Update packages and install the Apache web server

sudo apt update
sudo apt install apache2 -y

# Start and enable Apache to automatically start at boot time

systemctl start apache2
systemctl enable --now apache2

# Install PHP and several PHP modules required by WordPress

apt install -y php
apt install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,bcmath,json,xml,intl,zip,imap,imagick}

# Install the MySQL client

apt install -y mysql-client-core-8.0

# Add the "ubuntu" user to the "www-data" group, change ownership of the "/var/www" directory to "ubuntu:www-data", and set the directory and file permissions

usermod -a -G www-data ubuntu
chown -R ubuntu:www-data /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

# Download, make executable, and move the WP-CLI to the "/usr/local/bin" directory

curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Download the latest WordPress version to the "/var/www/html" directory

wp core download --path=/var/www/html --allow-root

# Generate a "wp-config.php" file with the database name, username, password, and RDS host, and add some extra configuration to it

wp config create --dbname=${aws_db_instance.name} --dbuser=${aws_db_instance.username} --dbpass=${aws_db_instance.password} --dbhost=${aws_db_instance.db_RDS.ip} --path=/var/www/html --allow-root --extra-php <<PHP
define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '128M');
PHP

# Change the ownership and permissions

chown -R ubuntu:www-data /var/www/html
chmod -R 774 /var/www/html

# Remove the default index.html file

rm /var/www/html/index.html

# Edit the Apache configuration file to allow ".htaccess" files to override Apache settings

sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/apache2/apache2.conf

# Enable the Apache "mod_rewrite" module and restart Apache to apply the changes

a2enmod rewrite
systemctl restart apache2

# Print a message indicating that WordPress has been successfully installed

echo WordPress Installed
