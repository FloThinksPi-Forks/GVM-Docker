#!/usr/bin/env bash
set -Eeuo pipefail

USERNAME=${USERNAME:-admin}
PASSWORD=${PASSWORD:-admin}
TIMEOUT=${TIMEOUT:-15}
RELAYHOST=${RELAYHOST:-smtp}
SMTPPORT=${SMTPPORT:-25}

HTTPS=${HTTPS:-true}
TZ=${TZ:-UTC}
SSHD=${SSHD:-false}
DB_PASSWORD=${DB_PASSWORD:-none}
AUTO_SYNC=${AUTO_SYNC:-true}


# Setup Data and link into system folders
/config-data-folder.sh

# Setup and start Redis
if [ ! -d "/run/redis" ]; then
	mkdir /run/redis
fi
if  [ -S /run/redis/redis.sock ]; then
        rm /run/redis/redis.sock
fi
redis-server --unixsocket /run/redis/redis.sock --unixsocketperm 700 --timeout 0 --databases 512 --maxclients 4096 --daemonize yes --port 6379 --bind 0.0.0.0

echo "Wait for redis socket to be created..."
while  [ ! -S /run/redis/redis.sock ]; do
        sleep 1
done

echo "Testing redis status..."
X="$(redis-cli -s /run/redis/redis.sock ping)"
while  [ "${X}" != "PONG" ]; do
        echo "Redis not yet ready..."
        sleep 1
        X="$(redis-cli -s /run/redis/redis.sock ping)"
done
echo "Redis ready."

# Setup and start Postgres
if  [ ! -d /data/database ]; then
	echo "Creating Database folder..."
	mkdir /data/database
	chown postgres:postgres -R /data/database
	su -c "/usr/lib/postgresql/12/bin/initdb /data/database" postgres
fi

chown postgres:postgres -R /data/database

echo "Starting PostgreSQL..."
su -c "/usr/lib/postgresql/12/bin/pg_ctl -D /data/database start" postgres

# Set timezone
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Setup Database for GVM
if [ ! -f "/data/firstrun" ]; then
	echo "Creating Greenbone Vulnerability Manager database"
	su -c "createuser -DRS gvm" postgres
	su -c "createdb -O gvm gvmd" postgres
	su -c "psql --dbname=gvmd --command='create role dba with superuser noinherit;'" postgres
	su -c "psql --dbname=gvmd --command='grant dba to gvm;'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"uuid-ossp\";'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"pgcrypto\";'" postgres
	
	echo "listen_addresses = '*'" >> /data/database/postgresql.conf
	echo "port = 5432" >> /data/database/postgresql.conf
	
	echo "host    all             all              0.0.0.0/0                 md5" >> /data/database/pg_hba.conf
	echo "host    all             all              ::/0                      md5" >> /data/database/pg_hba.conf
	
	chown postgres:postgres -R /data/database
	
	su -c "/usr/lib/postgresql/12/bin/pg_ctl -D /data/database restart" postgres
	
	touch /data/firstrun
fi

su -c "gvmd --migrate" gvm

if [ $DB_PASSWORD != "none" ]; then
	su -c "psql --dbname=gvmd --command=\"alter user gvm password '$DB_PASSWORD';\"" postgres
fi


# Only sync when either no sync was done at all or AUTO_SYNC is true(default)
if [[ "${AUTO_SYNC}" == "true" ]] || [ ! -f "/data/firstsync" ]; then
	# Sync NVTs, CERT data, and SCAP data on container start
	/sync-all.sh
	touch /data/firstsync
fi

###########################
#Remove leftover pid files#
###########################

if [ -f /var/run/ospd.pid ]; then
  rm /var/run/ospd.pid
fi

if [ -S /tmp/ospd.sock ]; then
  rm /tmp/ospd.sock
fi

if [ ! -d /var/run/ospd ]; then
  mkdir /var/run/ospd
fi


# Start Postfix, GVM aand OSPD
echo "Starting Postfix for report delivery by email"
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
service postfix start

echo "Starting Open Scanner Protocol daemon for OpenVAS..."
ospd-openvas --log-file /usr/local/var/log/gvm/ospd-openvas.log --unix-socket /var/run/ospd/ospd.sock --log-level INFO

while  [ ! -S /var/run/ospd/ospd.sock ]; do
	sleep 1
done

chmod 666 /var/run/ospd/ospd.sock

echo "Creating OSPd socket link from old location..."
rm -rf /tmp/ospd.sock
ln -s /var/run/ospd/ospd.sock /tmp/ospd.sock

echo "Starting Greenbone Vulnerability Manager..."
su -c "gvmd --listen=0.0.0.0 --port=9390" gvm

echo "Waiting for Greenbone Vulnerability Manager to finish startup..."
until su -c "gvmd --get-users" gvm; do
	sleep 1
done

if [ ! -f "/data/created_gvm_user" ]; then
	echo "Creating Greenbone Vulnerability Manager admin user"
	su -c "gvmd --role=\"Super Admin\" --create-user=\"$USERNAME\" --password=\"$PASSWORD\"" gvm
	
	USERSLIST=$(su -c "gvmd --get-users --verbose" gvm)
	IFS=' '
	read -ra ADDR <<<"$USERSLIST"
	
	echo "${ADDR[1]}"
	
	su -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value ${ADDR[1]}" gvm
	
	touch /data/created_gvm_user
fi

echo "Starting Greenbone Security Assistant..."
if [ $HTTPS == "true" ]; then
	su -c "gsad --verbose --gnutls-priorities=SECURE128:-AES-128-CBC:-CAMELLIA-128-CBC:-VERS-SSL3.0:-VERS-TLS1.0 --timeout=$TIMEOUT --no-redirect --mlisten=127.0.0.1 --mport=9390 --port=9392" gvm
else
	su -c "gsad --verbose --http-only --timeout=$TIMEOUT --no-redirect --mlisten=127.0.0.1 --mport=9390 --port=9392" gvm
fi

# Start SSHD
if [ $SSHD == "true" ]; then
	echo "Starting OpenSSH Server..."
	
	if  [ ! -h /etc/ssh ]; then
		rm -rf /etc/ssh
		ln -s /data/ssh /etc/ssh
	fi
	if  [ ! -d /data/scanner-ssh-keys ]; then
		echo "Creating scanner SSH keys folder..."
		mkdir /data/scanner-ssh-keys
		chown gvm:gvm -R /data/scanner-ssh-keys
	fi
	if [ ! -h /usr/local/share/gvm/.ssh ]; then
		echo "Fixing scanner SSH keys folder..."
		rm -rf /usr/local/share/gvm/.ssh
		ln -s /data/scanner-ssh-keys /usr/local/share/gvm/.ssh
		chown gvm:gvm -R /data/scanner-ssh-keys
		chown gvm:gvm -R /usr/local/share/gvm/.ssh
	fi
	
	if [ ! -d /sockets ]; then
		mkdir /sockets
		chown gvm:gvm -R /sockets
	fi
	
	echo "gvm:gvm" | chpasswd
	
	rm -rf /var/run/sshd
	mkdir -p /var/run/sshd
	
	/usr/sbin/sshd -f /sshd_config -E /usr/local/var/log/gvm/sshd.log
fi

echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo "+ Your GVM 20.04 container is now ready to use! +"
echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "-----------------------------------------------------------"
echo "Server Public key: $(cat /etc/ssh/ssh_host_ed25519_key.pub)"
echo "-----------------------------------------------------------"
echo ""
echo "++++++++++++++++"
echo "+ Tailing logs +"
echo "++++++++++++++++"
tail -F /usr/local/var/log/gvm/*
