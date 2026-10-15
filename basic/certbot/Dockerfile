FROM certbot/certbot:v5.8.0

COPY certbot-entrypoint.sh /usr/local/bin/certbot-entrypoint.sh

RUN chmod +x /usr/local/bin/certbot-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/certbot-entrypoint.sh"]
