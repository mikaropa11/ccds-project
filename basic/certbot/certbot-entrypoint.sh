#!/bin/sh
set -u

DOMAIN="ccds-project.duckdns.org"
EMAIL="mikael.rodriguez@estudiantat.upc.edu"
WEBROOT="/var/www/certbot"

echo "Starting Certbot for ${DOMAIN}..."

# Request the initial certificate, retrying if issuance fails.
until certbot certonly \
    --webroot \
    --webroot-path "${WEBROOT}" \
    --email "${EMAIL}" \
    --agree-tos \
    --no-eff-email \
    --non-interactive \
    --keep-until-expiring \
    --expand \
    -d "${DOMAIN}" \
    -d "app.${DOMAIN}" \
    -d "moodle.${DOMAIN}"
do
    echo "Certificate request failed. Retrying in 5 minutes..."
    sleep 300
done

echo "Certificate obtained successfully."

# Keep the container running and check for renewals every 12 hours.
while true; do
    echo "Checking whether the certificate needs renewal..."

    if certbot renew \
        --webroot \
        --webroot-path "${WEBROOT}" \
        --quiet
    then
        echo "Certbot renewal check completed."
    else
        echo "WARNING: Certbot renewal check failed."
    fi

    sleep 12h
done
