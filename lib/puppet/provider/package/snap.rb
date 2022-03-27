# frozen_string_literal: true

require 'puppet/provider/package'
require 'puppet_x/snap/api'

Puppet::Type.type(:package).provide :snap, parent: Puppet::Provider::Package do
  desc "Package management via Snap.

    This provider supports the `install_options` attribute, which allows snap's flags to be
    passed to Snap. Namely `classic`, `dangerous`, `devmode`, `jailmode`.

    The 'channel' install option is deprecated and will be removed in a future release.
  "

  commands snap_cmd: '/usr/bin/snap'
  has_feature :installable, :versionable, :install_options, :uninstallable, :purgeable
  confine feature: %i[net_http_unix_lib snapd_socket]

  def self.instances
    @installed_snaps ||= installed_snaps
    @installed_snaps.map do |snap|
      new(name: snap['name'], ensure: snap['tracking-channel'], provider: 'snap')
    end
  end

  def query
    installed = self.class.instances.find { |it| it.name == @resource['name'] }
    if installed
      { ensure: installed[:ensure], name: @resource[:name] }
    else
      { ensure: :absent, name: @resource[:name] }
    end
  end

  def latest
    query&.get(:ensure)
  end

  def install
    modify_snap('install')
  end

  def update
    modify_snap('switch')
  end

  def uninstall
    modify_snap('remove', nil)
  end

  # Purge differs from remove as it doesn't save a snapshot with snap's data.
  def purge
    modify_snap('remove', ['purge'])
  end

  def modify_snap(action, options = @resource[:install_options])
    body = self.class.generate_request(action, determine_channel, options)
    response = PuppetX::Snap::API.post("/v2/snaps/#{@resource[:name]}", body)
    change_id = PuppetX::Snap::API.get_id_from_async_req(response)
    PuppetX::Snap::API.complete(change_id)
  end

  def determine_channel
    channel = self.class.channel_from_ensure(@resource[:ensure])
    channel ||= self.class.channel_from_options(@resource[:install_options])
    channel ||= 'latest/stable'
    channel
  end

  def self.generate_request(action, channel, options)
    request = { 'action' => action }
    request['channel'] = channel unless channel.nil?

    if options
      # classic, devmode and jailmode params are only
      # available for install, refresh, revert actions.
      case action
      when 'install', 'refresh', 'revert'
        request['classic'] = true if options.include?('classic')
        request['devmode'] = true if options.include?('devmode')
        request['jailmode'] = true if options.include?('jailmode')
      when 'remove'
        request['purge'] = true if options.include?('purge')
      end
    end

    request
  end

  def self.channel_from_ensure(value)
    value = value.to_s
    case value
    when 'present', 'absent', 'purged', 'installed', 'latest'
      nil
    else
      value
    end
  end

  def self.channel_from_options(options)
    options&.find { |e| %r{channel} =~ e }&.split('=')&.last&.tap do |ch|
      Puppet.warning("Install option 'channel' is deprecated, use ensure => '#{ch}' instead.")
    end
  end

  def self.installed_snaps
    res = PuppetX::Snap::API.get('/v2/snaps')
    raise Puppet::Error, "Could not find installed snaps (code: #{res['status-code']})" unless [200, 404].include?(res['status-code'])

    res['status-code'] == 200 ? res['result'].map { |hash| hash.slice('name', 'tracking-channel') } : []
  end
end
