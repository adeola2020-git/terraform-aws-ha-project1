#!/bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
sudo echo "<html><body><h2>Hello World from $(hostname -f)</h2></body></html>" > /var/www/html/index.html


