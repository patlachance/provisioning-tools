node default {
  include puppetmaster::preinstall
  include puppetmaster::install
  include puppetmaster::config
  include puppetmaster::service
}

class puppetmaster::preinstall {
  exec {
    'puppet is crap':
      path    => '/bin:/usr/bin',
      command => "echo -e '#!/bin/sh\nexport JAVA_BIN=/does-not-exist\n' > /etc/default/puppetdb",
      onlyif  => "/usr/bin/test ! -e /etc/default/puppetdb";
  }

  file {
    '/etc/default/puppetmaster':
      ensure  => 'file',
      owner   => 'root',
      path    => '/etc/default/puppetmaster',
      content => template('/seed/default_puppetmaster.erb'),
  }

}

class puppetmaster::install {
  package{[
    'rubygems',
    'rubygem-hiera',
    'rubygem-hiera-puppet',
    'puppetdb',
    'puppetdb-terminus',
    'apache2',
    'libapache2-mod-passenger',
    'puppetmaster',
    'ruby-stomp']:
      ensure  => "latest",
      require => Class['puppetmaster::preinstall']
  }

  package{'git-core':
    ensure => 'latest'
  }

  exec{"reposetup":
    command => "/seed/clonerepo.sh",
    onlyif  => "/usr/bin/test ! -e /etc/puppet/hiera.yaml",
    require => Package['puppetmaster','puppetdb','git-core']
  }
}

class puppetmaster::config {
  File {
    require => Class['puppetmaster::install']
  }

  file{'/etc/puppet/puppet.conf':
    ensure  => 'file',
    owner   => 'root',
    path    => '/etc/puppet/puppet.conf',
    content => template('/seed/puppet.conf.erb');

  '/etc/puppet/puppetdb.conf':
    ensure  => 'file',
    owner   => 'root',
    path    => '/etc/puppet/puppetdb.conf',
    content => template('/seed/puppetdb.conf.erb');

  '/etc/default/puppetdb':
    ensure  => 'file',
    owner   => 'root',
    path    => '/etc/default/puppetdb',
    content => template('/seed/default_puppetdb.erb'),
    require => Exec['reposetup'];

  '/etc/init.d/apache2-puppetmaster':
    ensure      => 'file',
    owner       => 'root',
    mode        => 744,
    path        => '/etc/init.d/apache2-puppetmaster',
    content     => template('/seed/init_apache-puppetmaster.erb'),
    require => Package['libapache2-mod-passenger'];

  '/etc/apache2/puppetmaster.conf':
    ensure  => 'file',
    owner   => 'root',
    path    => '/etc/apache2/puppetmaster.conf',
    require => Package['libapache2-mod-passenger'],
    content => template('/seed/puppetmaster.conf.erb');

  '/etc/puppet/rack':
    ensure  => 'directory',
    require => Class['puppetmaster::install'];

  '/etc/puppet/rack/config.ru':
    ensure  => 'file',
    owner   => 'puppet',
    path    => '/etc/puppet/rack/config.ru',
    require  => File['/etc/puppet/rack'],
    content => template('/seed/config.ru.erb');

  '/var/lib/puppet/ssl':
    ensure => 'directory',
    owner  => 'puppet';

  '/var/lib/puppet/reports':
    ensure => 'directory',
    owner  => 'puppet';
  }



}

class puppetmaster::service {
  service{
    'apache2':
      ensure  => 'stopped',
      require => Package['apache2'];

    'apache2-puppetmaster':
      ensure  => 'running',
      require => File['/etc/init.d/apache2-puppetmaster'];

    'puppetmaster':
      ensure =>'stopped',
      require => Package['puppetmaster'];

    'puppetdb':
      ensure  => 'running',
      require => Class['puppetmaster::config'];
  }

}