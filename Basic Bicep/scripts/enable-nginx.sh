#!/bin/bash

sudo yum update -y --disablerepo='*' --enablerepo='*microsoft*'

# # add repo for nginx
# sudo rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm

# # Install Nginx.
# sudo yum install nginx

sudo yum -y install httpd
sudo systemctl start httpd

# Set the home page.
echo "<html><body><h2>Welcome to Azure! My name is $(hostname).</h2></body></html>" | sudo tee -a /var/www/html/index.html