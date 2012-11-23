class activemq::config {

  $admin_username = 'admin'
  $admin_password = 'admin'

  $mcollective_username = 'mcollective'
  $mcollective_password = 'marionette'

  #$subcollectives = 'mcollective'

  file {
    '/var/log/activemq':
      ensure => directory;

    '/etc/init.d/activemq':
      ensure => link,
      target => '/opt/activemq/bin/activemq';

    '/etc/activemq':
      ensure => link,
      target => '/opt/activemq/conf';

    '/etc/activemq/activemq.xml':
      ensure  => file,
      content => template("activemq/activemq.xml.erb"),
      require => Class['activemq::install'];
  }
}