class mcollective::service {
  service { 'mcollective':
     ensure  => running,
     enable  => true,
     require => [Class['mcollective::install'], Exec['waitfor_puppetmaster']];
  }
}
