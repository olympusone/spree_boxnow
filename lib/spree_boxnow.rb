require 'spree_core'
require 'spree_extension'
require 'spree_boxnow/engine'
require 'spree_boxnow/version'
require 'spree_boxnow/configuration'

module SpreeBoxnow
  def self.queue
    'default'
  end
end
