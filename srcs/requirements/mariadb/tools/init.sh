#!/bin/bash

set -e

mkdir -p /run/mysqld  #create directory pour stocker le fichier pid   -p: evite une erreur si le dossier existe.
chown -R mysql:mysql /run/mysqld #donne les dorits au compte systeme mysql.

if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql

    mysqld --user=mysql --datadir=/var/lib/mysql &  # lance mariadb en arriere plan

    until mysqladmin ping --silent; do
        sleep 1
    done

    mysql -u root << EOF   #ouvre un client sql connecte en root
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown  #arrete proprement le mariadb temporaire.
fi

exec mysqld --user=mysql --datadir=/var/lib/mysql
