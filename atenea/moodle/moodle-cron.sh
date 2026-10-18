#!/bin/bash
# Main process of the cron container: runs Moodle's scheduled tasks every
# minute, as Apache's user, for as long as the container lives.
set -u
cd /var/www/html
while true; do
    runuser -u www-data -- php admin/cli/cron.php --keep-alive=0 || echo "moodle-cron: run failed" >&2
    sleep 60
done
