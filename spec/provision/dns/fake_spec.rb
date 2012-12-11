require 'provision/dns'
require 'provision/dns/fake'

describe Provision::DNS::Fake do

  it 'constructs once' do
    thing = Provision::DNS.get_backend("Fake")
    ip = thing.allocate_ip_for({})
    ip.to_s.should eql("192.168.5.2")
    other = thing.allocate_ip_for({})
    other.to_s.should eql("192.168.5.3")
  end

  it 'constructs a second time, from same pool of IPs' do
    thing = Provision::DNS.get_backend("Fake")
    ip = thing.allocate_ip_for({})
    ip.to_s.should eql("192.168.5.4")
    other = thing.allocate_ip_for({})
    other.to_s.should eql("192.168.5.5")
  end
end
