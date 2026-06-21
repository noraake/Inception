#!/bin/bash
set -e

mkdir -p /etc/nginx/ssl

openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=MA/ST=Rabat/L=Rabat/O=42/CN=${DOMAIN_NAME}"

exec nginx -g "daemon off;"


# -x509: indique que vous voulez creer directement un certificat auto-signe, au lieu d une simple demande de signature (CSR).
# -nodes: NE DES. la cle privee ne sera pas chiffre par un mot de passe. le serveur web pourra ainsi redemarrer automatiquement sans intervention humaine.
# -days 365: fixe la duree de la valide de certificat a 365 jours. apres cette date il expirera.
# -newkey rsa:2048: Genere dune nouvelle cle privee en utilisant l algorithme RSA avec une taile securisee de 2048 bits.