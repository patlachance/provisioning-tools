require 'mcollective'

include MCollective::RPC

mc = rpcclient("computenode")
mc.identity_filter "grichards-desktop.youdevise.com"
mc.verbose = true
specs = [
  {
    :networks => [
      :mgmt,
      :prod
    ],
    :hostname => 'dev-tfundsproxy-001-grichards',
    :group => 'dev-tfundsproxy',
    :qualified_hostnames => {
      :prod => 'dev-tfundsproxy-001-grichards.dev.net.local',
      :mgmt => 'dev-tfundsproxy-001-grichards.mgmt.dev.net.local',
    },
    :cnames => {
      :prod => {
        'c.dev.net.local' => 'dev-tfundsproxy-001-grichards.dev.net.local',
      }
    },
    :ram => '2097152',
    :domain => 'dev.net.local',
    :fabric => 'local'
  },
  {
    :networks => [
      :mgmt,
      :prod
    ],
    :hostname => 'dev-tfundsproxy-002-grichards',
    :group => 'dev-tfundsproxy',
    :qualified_hostnames => {
      :prod => 'dev-tfundsproxy-002-grichards.dev.net.local',
      :mgmt => 'dev-tfundsproxy-002-grichards.mgmt.dev.net.local',
    },
    :cnames => {
      :prod => {
        'a.dev.net.local' => 'dev-tfundsproxy-001-grichards.dev.net.local',
        'b.dev.net.local' => 'dev-tfundsproxy-001-grichards.dev.net.local',
      }
    },
    :ram => '2097152',
    :domain => 'dev.net.local',
    :fabric => 'local'
  },
]
printrpc mc.allocate_ips(:specs => specs)
printrpc mc.allocate_cnames(:specs => specs)
#printrpc mc.free_cnames(:specs => specs)
#printrpc mc.allocate_ips(:specs => [
