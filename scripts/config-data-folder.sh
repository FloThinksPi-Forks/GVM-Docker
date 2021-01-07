#!/usr/bin/env bash
set -Eeuo pipefail

if  [ ! -d /data ]; then
	echo "Creating Data folder..."
        mkdir /data
fi


if  [ ! -d /data/gvmd ]; then
	echo "Creating gvmd folder..."
	mkdir /data/gvmd
	cp -r /report_formats /data/gvmd/
fi

if  [ ! -d /data/ssh ]; then
	echo "Creating SSH folder..."
	mkdir /data/ssh
	
	rm -rf /etc/ssh/ssh_host_*
	
	dpkg-reconfigure openssh-server
	
	mv /etc/ssh/ssh_host_* /data/ssh/
fi

if  [ ! -h /usr/local/var/lib/gvm/gvmd ]; then
	echo "Fixing gvmd folder..."
	rm -rf /usr/local/var/lib/gvm/gvmd
	ln -s /data/gvmd /usr/local/var/lib/gvm/gvmd
	
	chown gvm:gvm -R /data/gvmd
	chown gvm:gvm -R /usr/local/var/lib/gvm/gvmd
fi

if  [ ! -d /data/certs ]; then
	echo "Creating certs folder..."
	mkdir -p /data/certs/CA
	mkdir -p /data/certs/private
	
	echo "Generating certs..."
	gvm-manage-certs -a
	
	cp /usr/local/var/lib/gvm/CA/* /data/certs/CA/
	
	cp -r /usr/local/var/lib/gvm/private/* /data/certs/private/
	
	chown gvm:gvm -R /data/certs
fi

if [ ! -h /usr/local/var/lib/gvm/CA ]; then
	echo "Fixing certs CA folder..."
	rm -rf /usr/local/var/lib/gvm/CA
	ln -s /data/certs/CA /usr/local/var/lib/gvm/CA
	
	chown gvm:gvm -R /data/certs
	chown gvm:gvm -R /usr/local/var/lib/gvm/CA
fi

if [ ! -h /usr/local/var/lib/gvm/private ]; then
	echo "Fixing certs private folder..."
	rm -rf /usr/local/var/lib/gvm/private
	ln -s /data/certs/private /usr/local/var/lib/gvm/private
	chown gvm:gvm -R /data/certs
	chown gvm:gvm -R /usr/local/var/lib/gvm/private
fi

if  [ ! -d /data/plugins ]; then
	echo "Creating NVT Plugins folder..."
	mkdir /data/plugins
fi

if [ ! -h /usr/local/var/lib/openvas/plugins ]; then
	echo "Fixing NVT Plugins folder..."
	rm -rf /usr/local/var/lib/openvas/plugins
	ln -s /data/plugins /usr/local/var/lib/openvas/plugins
	chown gvm:gvm -R /data/plugins
	chown gvm:gvm -R /usr/local/var/lib/openvas/plugins
fi

#!/usr/bin/env bash

if  [ ! -d /data/cert-data ]; then
	echo "Creating CERT Feed folder..."
	mkdir /data/cert-data
fi

if [ ! -h /usr/local/var/lib/gvm/cert-data ]; then
	echo "Fixing CERT Feed folder..."
	rm -rf /usr/local/var/lib/gvm/cert-data
	ln -s /data/cert-data /usr/local/var/lib/gvm/cert-data
	chown gvm:gvm -R /data/cert-data
	chown gvm:gvm -R /usr/local/var/lib/gvm/cert-data
fi

if  [ ! -d /data/scap-data ]; then
	echo "Creating SCAP Feed folder..."
	
	mkdir /data/scap-data
fi

if [ ! -h /usr/local/var/lib/gvm/scap-data ]; then
	echo "Fixing SCAP Feed folder..."
	
	rm -rf /usr/local/var/lib/gvm/scap-data
	
	ln -s /data/scap-data /usr/local/var/lib/gvm/scap-data
	
	chown gvm:gvm -R /data/scap-data
	chown gvm:gvm -R /usr/local/var/lib/gvm/scap-data
fi

if  [ ! -d /data/data-objects/gvmd ]; then
	echo "Creating GVMd Data Objects folder..."
	
	mkdir -p /data/data-objects/gvmd
fi

if [ ! -h /usr/local/var/lib/gvm/data-objects ]; then
	echo "Fixing GVMd Data Objects folder..."
	
	rm -rf /usr/local/var/lib/gvm/data-objects
	
	ln -s /data/data-objects /usr/local/var/lib/gvm/data-objects
	
	chown gvm:gvm -R /data/data-objects
	chown gvm:gvm -R /usr/local/var/lib/gvm/data-objects
fi