<?php
// Moodle configuration for the atenea stack. Every setting comes from the
// environment, so the same image runs on a laptop and in the Swarm.
unset($CFG);
global $CFG;
$CFG = new stdClass();

// Returns the setting NAME. If NAME_FILE is set, reads the value from that
function atenea_setting(string $name, string $default = ''): string {
    $file = getenv($name . '_FILE');
    if ($file !== false && is_readable($file)) {
        return trim(file_get_contents($file));
    }
    $value = getenv($name);
    return $value === false ? $default : $value;
}

$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = atenea_setting('MOODLE_DB_HOST', 'db');
$CFG->dbname    = atenea_setting('MOODLE_DB_NAME', 'moodle');
$CFG->dbuser    = atenea_setting('MOODLE_DB_USER', 'moodle');
$CFG->dbpass    = atenea_setting('MOODLE_DB_PASSWORD');
$CFG->prefix    = 'mdl_';
$CFG->dboptions = ['dbpersist' => false, 'dbcollation' => 'utf8mb4_unicode_ci'];

$CFG->wwwroot  = atenea_setting('MOODLE_WWWROOT', 'http://localhost:8080');
$CFG->dataroot = atenea_setting('MOODLE_DATAROOT', '/var/www/moodledata');
$CFG->admin    = 'admin';
$CFG->directorypermissions = 02777;

// Each container keeps its own fast cache. The rest of dataroot is shared.
$CFG->localcachedir = '/var/cache/moodle';

// Sessions live in the database, so any replica can serve any user.
$CFG->session_handler_class = '\core\session\database';
$CFG->session_database_acquire_lock = 1;

// In production nginx ends HTTPS and forwards plain HTTP to Apache.
if (atenea_setting('MOODLE_SSLPROXY') === 'true') {
    $CFG->sslproxy = true;
}

require_once(__DIR__ . '/lib/setup.php');