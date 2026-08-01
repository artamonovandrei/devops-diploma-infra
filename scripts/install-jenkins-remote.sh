#!/bin/bash
set -euo pipefail

sudo mkdir -p /etc/apt/keyrings /usr/share/keyrings
sudo rm -f /etc/apt/sources.list.d/jenkins.list \
  /etc/apt/sources.list.d/pkg_jenkins_io_debian_stable.list \
  /usr/share/keyrings/jenkins-keyring.gpg \
  /usr/share/keyrings/jenkins-keyring.asc \
  /etc/apt/keyrings/jenkins-keyring.asc

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update
sudo apt-get install -y fontconfig openjdk-21-jre jenkins
sudo systemctl enable --now jenkins
sudo systemctl is-active jenkins
echo "JENKINS_OK"
