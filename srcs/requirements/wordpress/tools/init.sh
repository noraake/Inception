#!/bin/bash

set -e

mkdir -p /run/php

until mysql -h mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e "SELECT 1" > /dev/null 2>&1; do
    echo "Waiting for MariaDB..."
    sleep 2
done

cd /var/www/html

if ! wp core is-installed --allow-root 2>/dev/null; then

    wp core download --allow-root

    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost=mariadb:3306 \
        --allow-root

    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASS}" \
        --role=author \
        --allow-root

    chown -R www-data:www-data /var/www/html
fi

exec php-fpm8.2 -F
