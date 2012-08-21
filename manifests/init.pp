# == Class: rocci
#
# === Parameters
#
# === Variables
#
# === Examples
#
# === Authors
#
# Florian Feldhaus <florian.feldhaus@gwdg.de>
#
# === Copyright
#
# Copyright 2012 GWDG
#
class rocci(
    $user = 'occi',
    $group = 'occi',
    $ruby = '1.9.3-p194',
    $passenger_version = '3.0.15',
    $home = '/home',
    $server = 'apache'
  ) {   
  group { $group:
    ensure => present,
  }
  
  user { $user:
    require => Group[$group],
    ensure => present,
    gid => $group,
    home       => "${home}/${user}",
    managehome => true,
  }
  
  include rvm
  
  rvm_system_ruby {
    $ruby :
      ensure => 'present',
  }

  rvm_gem {
    'bundler':
      name => 'bundler',
      ruby_version => $ruby,
      ensure => latest,
      require => Rvm_gemset["${ruby}@rocci"],
  }
  
  rvm_gemset {
    "${ruby}@rocci":
      ensure => present,
      require => Rvm_system_ruby[$ruby];
  }

  class {
    'rvm::passenger::apache' :
      require => Rvm_gem['bundler'],
      version => $passenger_version,
      ruby_version => $ruby,
  }
  
  vcsrepo { 'rocci':
    path => "${home}/${user}/rocci",
    require => User[$user],
    ensure => latest,
    provider => git,
    owner    => occi,
    group    => occi,
    source => 'git://github.com/gwdg/rOCCI-server.git',
    revision => 'master',
  }
  
  exec { 'bundle install':
    require => Vcsrepo['rocci'],
    command => "/usr/local/rvm/bin/rvm ${ruby}@rocci do bundle install",
    cwd => "${home}/${user}/rocci",
    logoutput => true,
  }
  
  file { '/etc/apache2/sites-available/occi-ssl':
   ensure => 'file',
  }

  file { '/etc/apache2/sites-enabled/occi-ssl':
   ensure => 'link',
   target => '/etc/apache2/sites-available/occi-ssl',
  }
  
  augeas { 'apache-config':
    require => [File["/etc/apache2/sites-enabled/occi-ssl"],Class['rvm::passenger::apache']],
    context => "/files/etc/apache2/sites-available/occi-ssl",
    notify => Service['apache2'],
    changes => [
      "set VirtualHost/arg *:443",
      "set VirtualHost/directive[. = 'SSLEngine'] SSLEngine",
      "set VirtualHost/directive[. = 'SSLEngine']/arg on",
      "set VirtualHost/directive[. = 'SSLCertificateFile'] SSLCertificateFile",
      "set VirtualHost/directive[. = 'SSLCertificateFile']/arg /etc/ssl/certs/server.crt",
      "set VirtualHost/directive[. = 'SSLCertificateKeyFile'] SSLCertificateKeyFile",
      "set VirtualHost/directive[. = 'SSLCertificateKeyFile']/arg /etc/ssl/private/server.key",
      "set VirtualHost/directive[. = 'SSLCACertificatePath'] SSLCACertificatePath",
      "set VirtualHost/directive[. = 'SSLCACertificatePath']/arg /etc/ssl/certs",
      "set VirtualHost/directive[. = 'SSLVerifyClient'] SSLVerifyClient",
      "set VirtualHost/directive[. = 'SSLVerifyClient']/arg optional",
      "set VirtualHost/directive[. = 'SSLVerifyDepth'] SSLVerifyDepth",
      "set VirtualHost/directive[. = 'SSLVerifyDepth']/arg 10",
      "set VirtualHost/directive[. = 'SSLOptions'] SSLOptions",
      "set VirtualHost/directive[. = 'SSLOptions']/arg +StdEnvVars",
      "set VirtualHost/directive[. = 'ServerName'] ServerName",
      "set VirtualHost/directive[. = 'ServerName']/arg 10.211.55.4",
      "set VirtualHost/directive[. = 'DocumentRoot'] DocumentRoot",
      "set VirtualHost/directive[. = 'DocumentRoot']/arg ${home}/occi/rocci/public",
      "set VirtualHost/Directory/arg /webapps/rack_example/public",
      "set VirtualHost/Directory/directive[. = 'Allow'] Allow",
      "rm VirtualHost/Directory/directive[. = 'Allow']/arg 'from all'",
      "set VirtualHost/Directory/directive[. = 'Allow']/arg[1] from",
      "set VirtualHost/Directory/directive[. = 'Allow']/arg[2] all",
      "set VirtualHost/Directory/directive[. = 'Options'] Options",
      "set VirtualHost/Directory/directive[. = 'Options']/arg '-MultiViews'",
    ],
  }
  
  service { 'apache2':
    ensure => running,
    hasrestart => true,
  }
}