FROM debian:bullseye

# installe le moteur de base de donnee Mariadb . il contient le service de base se donnee, l outil de ligne commande , les fichiers de configuration /etc/mysql/, le script de securisation 
RUN apt-get update && apt-get install -y mariadb-server

COPY conf/my.conf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 3306

ENTRYPOINT ["/init.sh"]
