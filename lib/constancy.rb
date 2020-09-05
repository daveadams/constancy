# This software is public domain. No rights are reserved. See LICENSE for more information.

require 'erb'
require 'imperium'
require 'fileutils'
require 'ostruct'
require 'vault'
require 'yaml'

require_relative 'constancy/version'
require_relative 'constancy/config'
require_relative 'constancy/token_source'
require_relative 'constancy/diff'
require_relative 'constancy/sync_target'

class Constancy
  class InternalError < RuntimeError; end

  class << self
    @@config = nil

    def config
      @@config ||= Constancy::Config.new
    end

    def configure(path: nil, targets: nil, call_external_apis: true)
      @@config = Constancy::Config.new(path: path, targets: targets, call_external_apis: call_external_apis)
    end

    def configured?
      not @@config.nil?
    end
  end

  class Util
    class << self
      # https://stackoverflow.com/questions/9647997/converting-a-nested-hash-into-a-flat-hash
      def flatten_hash(h,f=[],g={})
        return g.update({ f=>h }) unless h.is_a? Hash
        h.each { |k,r| flatten_hash(r,f+[k],g) }
        g
      end
    end
  end
end

# monkeypatch String for display prettiness
class String
  # trim_path replaces the HOME directory on an absolute path with '~'
  def trim_path
    self.sub(%r(^#{ENV['HOME']}), '~')
  end

  def colorize(s,e=0)
    Constancy.config.color? ? "\e[#{s}m#{self}\e[#{e}m" : self
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def blue
    colorize(34)
  end

  def magenta
    colorize(35)
  end

  def cyan
    colorize(36)
  end

  def gray
    colorize(37)
  end

  def bold
    colorize(1,22)
  end
end
