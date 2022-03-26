# frozen_string_literal: true

require 'puppet/util/feature'

Puppet.features.add(:snapd_socket) do
  true if File.exist?('/run/snapd.socket')
end
