FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    php8.2 php8.2-fpm php8.2-mysql \
    curl wget mariadb-client

RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

RUN mkdir -p /var/www/html
WORKDIR /var/www/html

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 9000

ENTRYPOINT ["/init.sh"]
