lib = File.expand_path('../../vendor/czmq/bindings/ruby/lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'czmq/ffi'
require 'forwardable'

CZMQ::FFI.available? or raise LoadError, "libczmq is not available"

module CZTop
  class InitializationError < ::FFI::NullPointerError; end

  module NativeDelegate
    attr_reader :delegate

    def to_ptr
      @delegate.to_ptr
    end

    def delegate=(delegate)
      raise CZTop::InitializationError if delegate.null?
      @delegate = delegate
    end

    module ClassMethods
      def native_delegate(*methods)
        def_delegators(:@delegate, *methods)
      end
    end

    def self.included(m)
      m.class_eval do
        extend Forwardable
        extend ClassMethods
      end
    end
  end
end

require_relative 'cztop/actor'
require_relative 'cztop/certificate'
require_relative 'cztop/certificate_store'
require_relative 'cztop/config'
require_relative 'cztop/frame'
require_relative 'cztop/message'
require_relative 'cztop/proxy'
require_relative 'cztop/socket'
require_relative 'cztop/loop'
require_relative 'cztop/z85'


##
# Probably useless in this Ruby binding.
#
#  class Poller; end
#  class UUID; end
#  class Dir; end
#  class DirPatch; end
#  class File; end
#  class HashX; end
#  class String; end
#  class Trie; end
#  class Hash; end
#  class List; end