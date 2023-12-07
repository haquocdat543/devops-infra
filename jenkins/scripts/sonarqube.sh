#!/bin/bash

# Set hostname
hostnamectl set-hostname Sobarqube

# Add sudoers
sed -i "1s/^/sonar\tALL=(ALL)\tNOPASSWD:\tALL\n/" /etc/sudoers
sed -i "1s/^/postgres\tALL=(ALL)\tNOPASSWD:\tALL\n/" /etc/sudoers
# Install Mysql

# Install Docker and Sonarqube
sudo apt-get update
sudo apt-get install docker.io -y
sudo usermod -aG docker ubuntu
newgrp docker
sudo chmod 777 /var/run/docker.sock
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
