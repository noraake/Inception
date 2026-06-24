FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl

COPY conf/nginx.conf /etc/nginx/conf.d/default.conf
COPY tools/init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 443

ENTRYPOINT ["/init.sh"]
