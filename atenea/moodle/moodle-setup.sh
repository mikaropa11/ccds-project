#!/bin/bash
# Runs as root at every container start, before Apache or the cron loop,
# through the base image's startup hook. The cron container installs or
# upgrades Moodle's database; web containers wait until it is ready.
set -euo pipefail
cd /var/www/html

ROLE="${MOODLE_ROLE:-web}"
DATAROOT="${MOODLE_DATAROOT:-/var/www/moodledata}"
MARKER="$DATAROOT/.atenea-installed"

# The data folder must belong to Apache's user, www-data.
mkdir -p "$DATAROOT"
chown www-data "$DATAROOT" 2>/dev/null || true
if ! runuser -u www-data -- test -w "$DATAROOT"; then
    echo "moodle-setup: www-data cannot write to $DATAROOT" >&2
    exit 1
fi

# Exit code: 0 = Moodle's tables exist, 1 = empty database, 2 = unreachable.
db_state() {
    php -r '
        $file = getenv("MOODLE_DB_PASSWORD_FILE");
        $pass = $file ? trim(file_get_contents($file)) : (string) getenv("MOODLE_DB_PASSWORD");
        mysqli_report(MYSQLI_REPORT_OFF);
        $db = @new mysqli(getenv("MOODLE_DB_HOST") ?: "db", getenv("MOODLE_DB_USER") ?: "moodle",
                          $pass, getenv("MOODLE_DB_NAME") ?: "moodle");
        if ($db->connect_errno) { exit(2); }
        $result = $db->query("SHOW TABLES LIKE \"mdl_config\"");
        exit($result && $result->num_rows > 0 ? 0 : 1);'
}

echo "moodle-setup: waiting for the database"
for attempt in $(seq 1 90); do
    rc=0; db_state || rc=$?
    [ "$rc" -ne 2 ] && break
    [ "$attempt" -eq 90 ] && { echo "moodle-setup: database unreachable" >&2; exit 1; }
    sleep 2
done

if [ "$ROLE" = cron ]; then
    if [ "$rc" -eq 1 ]; then
        echo "moodle-setup: installing Moodle's database, this takes a few minutes"
        runuser -u www-data -- php admin/cli/install_database.php --agree-license \
            --lang=en --adminuser=admin \
            --adminpass="$(cat "$MOODLE_ADMIN_PASSWORD_FILE")" \
            --adminemail="${MOODLE_ADMIN_EMAIL:-admin@example.com}" \
            --fullname="${MOODLE_SITE_NAME:-Atenea}" --shortname=atenea
    else
        echo "moodle-setup: upgrading Moodle's database if the code is newer"
        runuser -u www-data -- php admin/cli/upgrade.php --non-interactive
    fi
    runuser -u www-data -- touch "$MARKER"
else
    echo "moodle-setup: waiting until the cron container has installed Moodle"
    until [ -f "$MARKER" ] && db_state; do sleep 5; done
fi
echo "moodle-setup: ready"
