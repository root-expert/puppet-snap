# frozen_string_literal: true

Puppet::Type.newtype(:snap_conf) do
  @doc = 'Manage snap configuration both system wide and snap specific.'

  ensurable do
    defaultvalues
    defaultto :present
    desc 'The desired state of the snap configuration.'
  end

  newparam(:name, namevar: true) do
    desc 'An unique name for this define.'
  end

  newparam(:snap) do
    desc 'The snap to configure the value for. This can be the reserved name system for system wide configurations.'
    defaultto ''

    validate do |value|
      raise ArgumentError, 'snap parameter must not be empty!' if value == ''
    end
  end

  newparam(:conf) do
    desc 'Name of configuration option.'
    defaultto ''

    validate do |value|
      raise ArgumentError, 'conf parameter must not be empty!' if value == ''
    end
  end

  newparam(:value) do
    desc 'Value of configuration option.'
  end
end
