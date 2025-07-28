#!/bin/bash

# Exit on error
set -e

# Update system
sudo apt update -y
sudo apt upgrade -y

# Install Apache, PHP, and required modules
sudo apt install apache2 php php-mysql libapache2-mod-php -y

# Install MySQL (or skip if using managed DB)
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password rootpass'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password rootpass'
sudo apt install mysql-server -y

# Create WordPress DB
mysql -uroot -prootpass -e "CREATE DATABASE wordpress;"

# Download WordPress
cd /var/www/html
sudo rm index.html
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzf latest.tar.gz
sudo mv wordpress/* .
sudo rm -rf wordpress latest.tar.gz

# Set permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Restart Apache
sudo systemctl restart apache2

