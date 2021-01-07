#!/bin/bash


# Add GVM User
useradd --home-dir /usr/local/share/gvm gvm
# Set GVM folder Permissions
chown gvm:gvm -R /usr/local/share/openvas
chown gvm:gvm -R /usr/local/var/lib/openvas
chown gvm:gvm -R /usr/local/share/gvm
mkdir /usr/local/var/lib/gvm/cert-data
chown gvm:gvm -R /usr/local/var/lib/gvm
chmod 770 -R /usr/local/var/lib/gvm
chown gvm:gvm -R /usr/local/var/log/gvm
chown gvm:gvm -R /usr/local/var/run