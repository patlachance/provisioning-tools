$: << File.join(File.dirname(__FILE__), "..", "../lib")
require 'rubygems'
require 'rspec'
require 'provision/core/machine_spec'

class XYZ
end

describe XYZ do
  before do
    @commands = double()
    MockFunctions.commands=@commands
  end

  module MockFunctions
    def self.commands=(commands)
      @@commands = commands
    end

    def action(args=nil)
      @@commands.action(args)
    end

    def die(args=nil)
      raise "I was asked to die"
    end

    def returns_something
      return "something"
    end

    def blah

    end
  end

  it 'has access to the config object' do
    require 'provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") {
        action(config[:item])
      }
      cleanup {
        action(config[:item2])
      }
   end

    build = Provision::Image::Catalogue::build("vanillavm", Provision::Core::MachineSpec.new({:hostname=>"myfirstmachine"}), {:item=>"run", :item2 => "clean"})

    @commands.should_receive(:action).with("run")
    @commands.should_receive(:action).with("clean")

    build.execute()
  end


  it 'cleanup blocks run after run blocks' do
    require 'provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") {
        action("1")
        action("2")
        action("3")
      }
      cleanup {
        action("6")
        action("7")
      }
      run("do more stuff") {
        action("4")
        action("5")
      }
    end

    build = Provision::Image::Catalogue::build("vanillavm", Provision::Core::MachineSpec.new({:hostname=>"myfirstmachine"}), {})

    @commands.should_receive(:action).with("1")
    @commands.should_receive(:action).with("2")
    @commands.should_receive(:action).with("3")
    @commands.should_receive(:action).with("4")
    @commands.should_receive(:action).with("5")
    @commands.should_receive(:action).with("6")
    @commands.should_receive(:action).with("7")

    build.execute()
  end

  it 'cleanup blocks run in reverse order' do
    require 'provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      cleanup {
        action("2")
        action("1")
      }
      cleanup {
        action("4")
        action("3")
      }
      cleanup {
        action("6")
        action("5")
      }
    end

    build = Provision::Image::Catalogue::build("vanillavm", Provision::Core::MachineSpec.new({:hostname=>"myfirstmachine"}), {})

    @commands.should_receive(:action).with("6").ordered
    @commands.should_receive(:action).with("5").ordered
    @commands.should_receive(:action).with("4").ordered
    @commands.should_receive(:action).with("3").ordered
    @commands.should_receive(:action).with("2").ordered
    @commands.should_receive(:action).with("1").ordered

    build.execute()
  end

  it 'cleanup blocks ignore exceptions' do
    require 'provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      cleanup {
        die("6")
        action("5")
      }
    end

    build = Provision::Image::Catalogue::build("vanillavm", Provision::Core::MachineSpec.new({:hostname=>"myfirstmachine"}), {})
    @commands.should_receive(:action).with("5")
    build.execute()
  end

  it 'can ignore exceptions if chosen to' do
    require 'provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") {
        suppress_error.die("6")
        action("5")
      }
    end

    build = Provision::Image::Catalogue::build("vanillavm", Provision::Core::MachineSpec.new({:hostname=>"myfirstmachine"}), {})
    @commands.should_receive(:action).with("5")
    build.execute()
  end

  it 'stops executing run commands after a failure' do
    require 'provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") {
        action("1")
        die("2")
        action("3")
      }
    end
    build = Provision::Image::Catalogue::build("vanillavm", Provision::Core::MachineSpec.new({:hostname=>"myfirstmachine"}), {})
    @commands.should_receive(:action).with("1")
    @commands.should_not_receive(:action).with("3")

    lambda {  build.execute() }.should raise_error
  end

  it 'I can pass options through to my build' do
    require 'provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("configure hostname") {
        hostname = self.spec[:hostname]
        action(hostname)
      }
    end

    build = Provision::Image::Catalogue::build("vanillavm",Provision::Core::MachineSpec.new({:hostname=>"myfirstmachine"}), {})

    @commands.should_receive(:action).with("myfirstmachine")

    build.execute()
  end

  it 'I can provide defaults' do
    require 'provision/image/catalogue'
    define "defaults" do
      run("configure defaults") {
        spec[:disksize] = '3G'
      }
    end
    define "vanillavm" do
      extend MockFunctions
      defaults()

      run("configure disk") {
        disksize = spec[:disksize]
        action(disksize)
      }
    end

    build = Provision::Image::Catalogue::build("vanillavm", Provision::Core::MachineSpec.new({}), {})
    @commands.should_receive(:action).with("3G")
    build.execute()
  end

  it 'can load files from a specified directory' do
    Provision::Image::Catalogue::loadconfig('home/image_builders')
  end

  it 'fails with a good error message' do
    require 'provision/image/catalogue'
    define "defaults" do
      run("configure defaults") {
        bing
      }
    end


    build = Provision::Image::Catalogue::build("defaults", {}, {})
    expect {
      build.execute()
    }.to raise_error NameError

  end

  it 'passes through the result when using suppress_error' do
    require 'provision/image/catalogue'
    something = nil
    define "defaults" do
      extend MockFunctions
      run("configure defaults") {
        something = suppress_error.returns_something()
      }
    end

    build = Provision::Image::Catalogue::build("defaults", Provision::Core::MachineSpec.new({}), {})
    build.execute()

    something.should eql("something")
  end
  it 'CCCCCc' do
    require 'provision/image/catalogue'
    something = nil
    define "defaults" do
      extend Provision::Image::Commands
      extend MockFunctions
      run("configure defaults") {
      }
      cleanup {
        keep_doing {
        suppress_error.die("this line should throw an error and be swallowed")
        something = returns_something()
        print "something = #{something} \n"
      }.until {something=="something"}
      }
    end

    build = Provision::Image::Catalogue::build("defaults", Provision::Core::MachineSpec.new({}), {})
    build.execute()

    something.should eql("something")
  end

  it 'raises a meaningful error when a non-existent template is defined' do
    require 'provision/image/catalogue'
    expect {
      Provision::Image::Catalogue::build("noexist", Provision::Core::MachineSpec.new({}), {})
    }.to raise_error("attempt to execute a template that is not in the catalogue: noexist")
  end

end
