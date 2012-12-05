class rabbitmq::post_config {

  file {
    ['/etc/rabbitmq']:
      ensure => directory;

    '/etc/rabbitmq/rabbitmq.config':
      source => 'puppet:///modules/rabbitmq/rabbitmq.config',
      notify => Class['rabbitmq::service'];

  }

}

