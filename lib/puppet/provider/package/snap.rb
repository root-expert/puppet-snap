# frozen_string_literal: true

require 'date'
require 'puppet/provider/package'
require 'puppet_x/snap/api'

Puppet::Type.type(:package).provide :snap, parent: Puppet::Provider::Package do
  desc "Package management via Snap.

    This provider supports the `install_options` attribute, which allows snap's flags to be
    passed to Snap. Namely `classic`, `dangerous`, `devmode`, `jailmode`.

    The 'channel' install option is deprecated and will be removed in a future release.
  "

  commands snap_cmd: '/usr/bin/snap'
  has_feature :installable, :versionable, :install_options, :uninstallable, :purgeable, :upgradeable, :holdable
  confine feature: %i[net_http_unix_lib snapd_socket]

  mk_resource_methods

  def self.instances
    installed_snaps.map do |snap|
      mark = snap['hold'].nil? ? 'none' : 'hold'
      Puppet.info("refresh-inhibit = #{mark}")
      new(name: snap['name'], ensure: snap['tracking-channel'], mark: mark, hold_time: snap['hold'], provider: 'snap')
    end
  end

  def query
    Puppet.info('called query')
    { ensure: @property_hash[:ensure], name: @resource[:name] } unless @property_hash.empty?
  end

  def install
    Puppet.info('called install')
    current_ensure = query&.dig(:ensure)

    # Refresh the snap if we changed the channel
    if current_ensure != @resource[:ensure] && !%i[absent purged].include?(current_ensure)
      modify_snap('refresh') # Refresh will switch the channel AND trigger a refresh immediately. TODO Implement switch?
    else
      modify_snap('install')
    end
  end

  def update
    install
  end

  def latest
    raise Puppet::Error, "Don't use ensure => latest, instead define which channel to use"
  end

  def uninstall
    modify_snap('remove', nil)
  end

  # Purge differs from remove as it doesn't save a snapshot with snap's data.
  def purge
    modify_snap('remove', ['purge'])
  end

  def hold
    Puppet.info('called hold')
    Puppet.info("@property_hash = #{@property_hash}")
    Puppet.info("install_options = #{@resource[:install_options]}")
    modify_snap('hold') unless @property_hash[:mark].equal?('hold') && @property_hash[:hold_time] == self.class.parse_time_from_options(@resource[:install_options])
  end

  def unhold
    Puppet.info('called unhold')
    modify_snap('unhold') unless @property_hash[:mark].equal?('none')
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
    request['hold-level'] = 'general' if action.equal?('hold')

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
      when 'hold'
        time = parse_time_from_options(options)
        request['time'] = time
      end
    elsif action.equal?('hold')
      # If no options defined assume hold time forever
      request['time'] = 'forever'
    end

    Puppet.info("request = #{request}")

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

  def self.parse_time_from_options(options)
    time = options&.find { |opt| %r{hold_time} =~ opt }&.split('=')&.last

    # Assume forever if not hold_time was specified
    return 'forever' if time.nil? || time.equal?('forever')

    begin
      DateTime.parse(time).rfc3339
    rescue Date::Error
      raise Puppet::Error, 'Date not in correct format.'
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

    res['status-code'] == 200 ? res['result'].map { |hash| hash.slice('name', 'tracking-channel', 'hold') } : []
  end
end
