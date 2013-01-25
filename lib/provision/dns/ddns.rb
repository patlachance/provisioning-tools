require 'ipaddr'
require 'rubygems'
require 'tempfile'
require 'provision/dns'
require 'resolv'

class Provision::DNS::DDNS < Provision::DNS
end

module Provision::DNS::DDNS::Exception
    class BadKey < Exception
    end
    class Timeout < Exception
    end
    class UnknownError < Exception
    end
end

class Provision::DNS::DDNSNetwork < Provision::DNSNetwork
  def initialize(name, range, start, options={})
    super(name, range, start, options)
    @debug = true
    parts = range.split('/')
    if parts.size != 2
      raise(":network_range must be of the format X.X.X.X/Y")
    end
    broadcast_mask = (IPAddr::IN4MASK >> parts[1].to_i)
    @subnet_mask = IPAddr.new(IPAddr::IN4MASK ^ broadcast_mask, Socket::AF_INET)
    @network = IPAddr.new(parts[0]).mask(parts[1])
    @broadcast = @network | IPAddr.new(broadcast_mask, Socket::AF_INET)
    @max_allocation = IPAddr.new(@broadcast.to_i - 1, Socket::AF_INET)
    min_allocation = options[:min_allocation] || 10
    @min_allocation = IPAddr.new(min_allocation.to_i + @network.to_i, Socket::AF_INET)
    @rndc_key = options[:rndc_key] || raise("No :rndc_key supplied")
  end

  def reverse_zone
    parts = @network.to_s.split('.').reverse
    while parts[0] == "0"
      parts.shift
    end
    "#{parts.join('.')}.in-addr.arpa"
  end

  def write_rndc_key
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "key \"rndc-key\" {"
    tmp_file.puts "algorithm hmac-md5;"
    tmp_file.puts "secret \"#{@rndc_key}\";"
    tmp_file.puts "};"
    tmp_file.close
    tmp_file
  end

  def get_primary_nameserver
    '172.19.0.5'
  end

  def remove_ip_for(spec)
    # we need to know *which* IP, so we need the name of the network too
    # this can't be done purely on the basis of the spec
    puts "Not ability to remove DNS for #{spec[:hostname]}, not removing"
    return false
  end

  def try_add_reverse_lookup(ip, fqdn)
    ip_rev = ip.to_s.split('.').reverse.join('.')
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{get_primary_nameserver}"
    tmp_file.puts "zone #{reverse_zone}"
    tmp_file.puts "prereq nxdomain #{ip_rev}.in-addr.arpa"
    tmp_file.puts "update add #{ip_rev}.in-addr.arpa. 86400 PTR #{fqdn}."
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Add reverse from #{ip.to_s} to #{fqdn}")
  end

  def exec_nsupdate(update_file)
    rndc_tmp = write_rndc_key
    out = `cat #{update_file.path} | nsupdate -k #{rndc_tmp.path} 2>&1`
    logger.info("nsupdate OUT #{out}") if @debug
    update_file.unlink
    rndc_tmp.unlink
    out
  end

  def nsupdate(update_file, txt)
    logger.info("about to nsupdate for #{txt}") if @debug
    out = exec_nsupdate(update_file)
    check_nsupdate_output(out, txt)
  end

  def check_nsupdate_output(out, txt)
    failure = "#{txt} failed: '#{out}'"
    case out
    when /update failed: YXDOMAIN/
      puts "FAILED TO ADD #{txt} - IP already used"
      return false
    when /update failed: NOTAUTH\(BADKEY\)/
      raise(Provision::DNS::DDNS::Exception::BadKey.new(failure))
    when /Communication with server failed: timed out/
      raise(Provision::DNS::DDNS::Exception::Timeout.new(failure))
    when /^$/
      puts "ADD OK #{txt}"
      return true
    else
      raise(Provision::DNS::DDNS::Exception::UnknownError.new(failure))
    end
  end

  def get_hostname(fqdn)
    fqdn_s = fqdn.split "."
    zone_s = fqdn_s.clone
    hn = zone_s.shift
    return hn
  end

  def get_zone(fqdn)
    fqdn_s = fqdn.split "."
    zone_s = fqdn_s.clone
    hn = zone_s.shift
    zone = zone_s.join('.')
    return zone
  end

  def add_forward_lookup(ip, fqdn)
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{get_primary_nameserver}"
    tmp_file.puts "zone #{get_zone(fqdn)}"
    tmp_file.puts "update add #{fqdn}. 86400 A #{ip}"
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Add forward from #{fqdn} to #{ip}")
  end

  def remove_forward_lookup(fqdn)
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{get_primary_nameserver}"
    tmp_file.puts "zone #{get_zone(fqdn)}"
    tmp_file.puts "update delete #{get_hostname(fqdn)}"
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Remove forward from #{fqdn} to #{ip}")
  end

  def lookup_ip_for(fqdn)
    resolver = Resolv.new(:resolvers => [DNS.new(
      :nameserver => get_primary_nameserver,
      :search => [],
      :ndots => 1
    )])

    begin
      IPAddr.new(resolver.getaddress(fqdn))
    rescue Resolv::ResolvError
      puts "Could not find #{fqdn}"
      false
    end
  end

  def allocate_ip_for(spec)
    hostname = spec.hostname_on(@name)
    ip = nil

    if lookup_ip_for(hostname)
      puts "No new allocation for #{hostname}, already allocated"
      return {
        :netmask => @subnet_mask.to_s,
        :address => lookup_ip_for(hostname)
      }
    else

      max_ip = @max_allocation
      ip = @min_allocation
      while !try_add_reverse_lookup(ip, hostname)
        ip = IPAddr.new(ip.to_i + 1, Socket::AF_INET)
        if ip >= max_ip
          raise("Ran out of ips")
        end
      end
      add_forward_lookup(ip, hostname)
    end
    {
      :netmask => @subnet_mask.to_s,
      :address => ip
    }
  end

  def unallocate_ip_for(hostname)
    ip = nil

    if lookup_ip_for(hostname)
      forward_lookup_moved = remove_forward_lookup(fqdn)
      if forward_lookup_removed

      end

      return {
        :netmask => @subnet_mask.to_s,
        :address => lookup_ip_for(hostname)
      }
    else
      puts "No allocation for #{hostname}, nothing to remove"
      max_ip = @max_allocation
      ip = @min_allocation
      while !try_add_reverse_lookup(ip, hostname)
        ip = IPAddr.new(ip.to_i + 1, Socket::AF_INET)
        if ip >= max_ip
          raise("Ran out of ips")
        end
      end
      add_forward_lookup(ip, hostname)
    end
    {
      :netmask => @subnet_mask.to_s,
      :address => ip
    }
    return true
  end

end


