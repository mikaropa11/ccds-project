# Moodle 5.3 for the atenea stack.
# Moodle HQ's base image: PHP 8.3 and Apache with every PHP extension
# Moodle needs, already compiled.
FROM moodlehq/moodle-php-apache:8.3

# The Moodle release to install. Changing it means a new image version.
ARG MOODLE_URL=https://download.moodle.org/download.php/direct/stable503/moodle-5.3.tgz

# Download Moodle and unpack it where Apache serves from. The code stays
# owned by root, so the web server can read it but never modify it.
RUN curl -fsSL "$MOODLE_URL" -o /tmp/moodle.tgz \
 && tar -xzf /tmp/moodle.tgz -C /var/www/html --strip-components=1 \
 && rm /tmp/moodle.tgz \
 && chown -R root:root /var/www/html

# Settings read from the environment: one file for laptop and Swarm.
COPY --chmod=644 config.php /var/www/html/config.php

# First-start setup, run by the base image's startup hook.
COPY moodle-setup.sh /docker-entrypoint.d/50-moodle-setup.sh

# Main process of the cron container.
COPY moodle-cron.sh /usr/local/bin/moodle-cron

# Make both scripts executable, and give each container a local cache
# folder that Apache's user can write to.
RUN chmod 755 /docker-entrypoint.d/50-moodle-setup.sh /usr/local/bin/moodle-cron \
 && install -d -o www-data -g www-data /var/cache/moodle