#!/bin/sh
set -eu

: "${SMTP_RELAY_HOST:?SMTP_RELAY_HOST is required}"
: "${SMTP_RELAY_USER:?SMTP_RELAY_USER is required}"
: "${SMTP_RELAY_PASSWORD_FILE:=/run/secrets/smtp_password}"
: "${SMTP_RELAY_PORT:=587}"
: "${SMTP_RELAY_STARTTLS:=on}"
: "${MAIL_FROM:?MAIL_FROM is required}"
export SMTP_RELAY_HOST SMTP_RELAY_USER SMTP_RELAY_PASSWORD_FILE SMTP_RELAY_PORT SMTP_RELAY_STARTTLS MAIL_FROM

CONF=/tmp/msmtprc
envsubst < /etc/msmtprc.template > "$CONF"
chmod 600 "$CONF"

exec msmtpd --interface=0.0.0.0 --port=2525 --log=/dev/stdout \
     --command="msmtp -C $CONF -f %F --"
