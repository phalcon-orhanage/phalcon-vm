packagecloud::repo { 'phalcon/stable':
	type => 'deb'
}

package { 'php7.0-phalcon':
	ensure  => 'installed',
	require => Packagecloud::Repo['phalcon/stable'],
}

$poold_www = {
	'www' => {
		'listen.mode'          => '0666',
		'pm.max_requests'      => 100,
		'pm.status_path'       => '/php-status',
		'chdir'                => '/',
		'catch_workers_output' => 'yes',
	}
}

create_ini_settings( $poold_www, {
	path    => '/etc/php/7.0/fpm/pool.d/www.conf',
	require => Package['php7.0-fpm'],
	notify  => Service['php7.0-fpm'],
} )

$php = {
	'PHP' => {
		'short_open_tag'                 => 'Off',
		'allow_call_time_pass_reference' => 'Off',
		'max_execution_time'             => 30,
		'memory_limit'                   => '256M',
		'error_reporting'                => 'E_ALL | E_STRICT',
		'display_errors'                 => 'On',
		'display_startup_errors'         => 'On',
		'log_errors'                     => 'On',
		'log_errors_max_len'             => '1024',
		'ignore_repeated_errors'         => 'Off',
		'ignore_repeated_source'         => 'Off',
		'track_errors'                   => 'Off',
		'html_errors'                    => 1,
		'error_log'                      => '/srv/log/php_errors.log',
		'post_max_size'                  => '1024M',
		'upload_max_filesize'            => '1024M',
		'max_file_uploads'               => 20,
		'default_socket_timeout'         => 60,
	}
}

create_ini_settings( $php, {
	path    => '/etc/php/7.0/fpm/php.ini',
	require => Package['php7.0-fpm'],
	notify  => Service['php7.0-fpm'],
} )

file { '/srv/log/xdebug-remote.log':
	ensure => 'present',
	owner  => 'www-data',
	group  => 'www-data',
}

$xdebug = {
	'XDebug' => {
		'xdebug.collect_params'           => 1,
		'xdebug.idekey'                   => 'PHALCONVMDEBUG',
		'xdebug.profiler_enable_trigger'  => 1,
		'xdebug.profiler_output_name'     => 'cachegrind.out.%t-%s',
		'xdebug.remote_enable'            => 1,
		'xdebug.remote_host'              => '192.168.50.99',
		'xdebug.remote_log'               => '/srv/log/xdebug-remote.log',
		'xdebug.var_display_max_children' => -1,
		'xdebug.var_display_max_data'     => -1,
		'xdebug.var_display_max_depth'    => -1,
	}
}

create_ini_settings( $xdebug, {
	path => '/etc/php/7.0/mods-available/xdebug.ini',
	require => [ Package['php-xdebug'], File['/srv/log/xdebug-remote.log'] ],
	notify  => Service['php7.0-fpm'],
} )

$opcache = {
	'opcache' => {
		'opcache.enable'             => 1,
		'opcache.memory_consumption' => 128,
	}
}

create_ini_settings( $opcache, {
	path => '/etc/php/7.0/mods-available/opcache.ini',
	require => Package['php7.0'],
	notify  => Service['php7.0-fpm'],
} )

service { 'php7.0-fpm':
	ensure => running,
}

# Pecl

exec { 'pecl-install-yaml':
	command => '/usr/bin/pecl install yaml-2.0.0',
	creates => '/usr/lib/php/20151012/yaml.so',
    require => Package['php-pear'],
}

file { '/etc/php/7.0/mods-available/yaml.ini':
	ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    content => 'extension=yaml.so',
    require => Exec['pecl-install-yaml'],
}

file { '/etc/php/7.0/fpm/conf.d/20-yaml.ini':
	ensure  => 'link',
    target  => '/etc/php/7.0/mods-available/yaml.ini',
    owner   => 'root',
    group   => 'root',
    require => File['/etc/php/7.0/mods-available/yaml.ini'],
}

# Composer

exec { 'composer-config':
	command     => '/usr/bin/composer -q global config bin-dir /usr/local/bin',
	environment => 'COMPOSER_HOME=/usr/local/src/composer',
	require     => Package['composer'],
}

$composer_dependency = [ Package['composer'], Exec['composer-config'] ]

exec { 'composer-phalcon-dev-tools':
	command     => '/usr/bin/composer -q global require phalcon/devtools',
	creates     => '/usr/local/src/composer/vendor/phalcon/devtools',
	environment => 'COMPOSER_HOME=/usr/local/src/composer',
	require     => $composer_dependency,
}

exec { 'composer-codeception':
	command     => '/usr/bin/composer -q global require codeception/codeception',
	creates     => '/usr/local/src/composer/vendor/codeception/codeception',
	environment => 'COMPOSER_HOME=/usr/local/src/composer',
	require     => $composer_dependency,
}

exec { 'composer-phpunit':
	command     => '/usr/bin/composer -q global require phpunit/phpunit',
	creates     => '/usr/local/src/composer/vendor/phpunit/phpunit',
	environment => 'COMPOSER_HOME=/usr/local/src/composer',
	require     => $composer_dependency,
}

file { '/usr/bin/phalcon':
	ensure  => 'link',
	target  => '/usr/local/bin/phalcon.php',
	require => Exec['composer-phalcon-dev-tools'],
}