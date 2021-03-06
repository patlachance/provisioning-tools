require 'provision/vm/namespace'
require 'provision'
require 'erb'
require 'ostruct'

class Provision::VM::Virsh
  def initialize(config)
    @template = "#{Provision.base}/templates/kvm.template"
    @config = config
  end

  def safe_system(cli)
    if system(cli) != true
      raise("Failed to run: #{cli}")
    end
  end

  def is_defined(spec)
    is_in_virsh_list(spec, '--all')
  end

  def is_running(spec)
    is_in_virsh_list(spec)
  end

  def is_in_virsh_list(spec, extra = '')
    vm_name=spec[:hostname]
    result=`virsh list #{extra} | grep ' #{vm_name} ' | wc -l`
    return result.match(/1/)
  end

  def undefine_vm(spec)
    safe_system("virsh undefine #{spec[:hostname]} > /dev/null 2>&1")
  end

  def destroy_vm(spec)
    safe_system("virsh destroy #{spec[:hostname]} > /dev/null 2>&1")
  end

  def start_vm(spec)
    return if is_running(spec)
    safe_system("virsh start #{spec[:hostname]} > /dev/null 2>&1")
  end

  def wait_for_shutdown(spec)
    120.times do
      if not is_running(spec)
        return
      end
      sleep 1
    end

    raise "giving up waiting for #{spec[:hostname]} to shutdown"
  end


  def write_virsh_xml(spec)
    template = ERB.new(File.read(@template))
    to = "#{spec[:libvirt_dir]}/#{spec[:hostname]}.xml"
    binding = VirshBinding.new(spec, @config)
    begin
      template.result(binding.get_binding())
    rescue Exception=>e
      print e
      print e.backtrace
    end
    File.open to, 'w' do |f|
      f.write template.result(binding.get_binding())
    end
    to
  end

  def define_vm(spec)
    to = write_virsh_xml(spec)
    safe_system("virsh define #{to} > /dev/null 2>&1")
  end
end

class VirshBinding

  attr_accessor :spec, :config

  def initialize(spec, config)
    @spec = spec
    @config = config
  end

  def get_binding
    return binding()
  end
end



