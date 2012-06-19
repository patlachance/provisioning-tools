module Provision
  class Build
    def initialize(name, options)
      @name = name
      @options = options
      @commands = []
      @cleanups = []
    end

    def run(txt, &block)
      @commands << {:txt=>txt, :block=>block}
    end

    def cleanup(&block)
      @cleanups << block
    end

    def execute()
      begin
        @commands.each {|command|
          error = nil
          begin
            command[:block].call()
          rescue Exception=>e
            error = e
            raise e
          ensure
            if (not error.nil?)
              print "[\e[0;31mFAILED\e[0m]\n"
              raise error
            else
              print "[\e[0;32mDONE\e[0m]\n"
            end

          end
        }
      rescue

      end

      @cleanups.each {|command|
        begin
          command.call()
        rescue Exception=>e
        end
      }
    end

  end

  module Catalogue
    @@catalogue = {}

    def define(name, &block)
      @@catalogue[name] = block
    end

    def build(name, options)
      build = Provision::Build.new(name, options)
      closure = @@catalogue[name]
      build.instance_eval(&closure)
      return build
    end
  end
end

include Provision::Catalogue