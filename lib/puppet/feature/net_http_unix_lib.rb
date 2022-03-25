# frozen_string_literal: true

require 'puppet/util/feature'

Puppet.features.add(:net_http_unix_lib, libs: 'net_http_unix')
