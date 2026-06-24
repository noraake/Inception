#!/bin/bash

set -e               #Cette option demande au shell d'arrêter immédiatement le script si une commande retourne une erreur.

mkdir -p /run/mysqld  #create directory pour stocker le fichier pid   -p: evite une erreur si le dossier existe. -p evite une erreur si le dossier existe deja.
chown -R mysql:mysql /run/mysqld #donne les dorits au compte systeme mysql.

if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql # cette commande cree l arborescence interne de mariadb : tables systeme, fichier innodb, structures necessaires au serveur .

    mysqld --user=mysql --datadir=/var/lib/mysql &  # lance mariadb temporairement en arriere plan

    until mysqladmin ping --silent; do  # Le serveur met quelques secondes à démarrer. Je boucle jusqu'à ce qu'il réponde aux requêtes.
        sleep 1
    done

    mysql -u  root << EOF   #ouvre un client sql connecte en root
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown  #arrete proprement le mariadb temporaire.
fi

exec mysqld --user=mysql --datadir=/var/lib/mysql


#ce script initialise Mariadb lors du premier lancement du contener . il cree la base de donnes et l utilisateur wordpress si les donnes n existent pas encore. ensuite il demare mariadb en premier plan pour que le conteneur reste vivant.

#Les données MariaDB sont stockées dans un volume monté sur /var/lib/mysql.

#Au premier lancement, la base n'existe pas, donc on initialise tout.

#Aux démarrages suivants, les données sont déjà présentes dans le volume persistant.

#On saute donc toute l'initialisation pour éviter de recréer la base ou les utilisateurs.