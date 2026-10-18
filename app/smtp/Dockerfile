FROM alpine:3.22

RUN apk add --no-cache msmtp ca-certificates gettext \
 && adduser -S -u 1000 msmtp

COPY msmtprc.template /etc/msmtprc.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER msmtp
EXPOSE 2525
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD pgrep msmtpd >/dev/null || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
