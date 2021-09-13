require 'puppet/provider/package'
require 'net/http'
require 'socket'
require 'json'

Puppet::Type.type(:package).provide :snap, parent: Puppet::Provider::Package do
  desc "Package management via Snap.

    This provider supports the `install_options` attribute, which allows snap's flags to be
    passed to Snap. Namely `classic`, `dangerous`, `devmode`, `jailmode`, `channel`."

  has_feature :install_options
  has_feature :purgeable

  def self.instances
    instances = []
    snaps = installed_snaps

    snaps.each do |snap|
      instances << new(name: snap['name'], ensure: snap['version'], provider: 'snap')
    end

    instances
  end

  def query
    instances = self.class.instances
    instances.each do |instance|
      return instance if instance.name == @resource[:name]
    end

    nil
  end

  def install
    self.class.modify_snap('install', @resource[:name], @resource[:install_options])
  end

  def update
    self.class.modify_snap('refresh', @resource[:name], @resource[:install_options])
  end

  def uninstall
    self.class.modify_snap('remove', @resource[:name])
  end

  # Purge differs from remove as it doesn't save snapshot with snap's data.
  def purge
    self.class.modify_snap('remove', @resource[:name], ['purge'])
  end

  def self.call_api(method, url, data = nil)
    socket = Net::BufferedIO.new(UNIXSocket.new('/run/snapd.socket'))

    request = if method == 'POST'
                req = Net::HTTP::Post.new(url)
                req.body = data.to_json
                req
              else
                Net::HTTP::Get.new(url)
              end

    request['Host'] = 'localhost'
    request['Accept'] = 'application/json'
    request['Content-Type'] = 'application/json'
    request.exec(socket, '1.1', url)

    response = nil
    retried = 0
    max_retries = 5
    # Read timeout can happen while installing core snap. The snap daemon briefly restarts
    # which drops the connection to the socket.
    loop do
      begin
        response = Net::HTTPResponse.read_new(socket)
        break unless response.is_a?(Net::HTTPContinue)
      rescue Net::ReadTimeout, Net::OpenTimeout
        raise Puppet::Error, format("Got timeout wile calling the api #{retried} times! Giving up...") if retried > max_retries

        Puppet.debug('Got timeout while calling the api, retrying...')
        retried += 1
        retry
      end
    end
    response.reading_body(socket, request.response_body_permitted?) {}

    JSON.parse(response.body)
  end

  def self.installed_snaps
    res = call_api('GET', '/v2/snaps')

    unless [200, 404].include?(res['status-code'])
      raise Puppet::Error, format('Could not find installed snaps (code: %s)', res['status-code'])
    end

    res['result'].map { |hash| hash.slice('name', 'version') } if res['status-code'] == 200
  end

  # Helper method to return the change ID from a asynchronous request response.
  def self.get_id_from_async_req(request)
    # If the request failed raise an error
    if request['type'] == 'error'
      raise Puppet::Error, format('Request failed with %s', request['result']['message'])
    end

    request['change']
  end

  # Get the status of a change
  #
  # @param id The change ID to search for.
  def self.get_status(id)
    call_api('GET', "/v2/changes/#{id}")
  end

  # Queries the API for a specific change and waits until it has
  # been completed.
  #
  # @param id The change ID to search for.
  def self.complete(id)
    completed = false
    until completed
      res = get_status(id)
      case res['result']['status']
      when 'Do', 'Doing', 'Undoing', 'Undo'
        # Still running
        # Wait a little bit before hitting the API again!
        sleep(1)
        next
      when 'Abort', 'Hold', 'Error'
        raise Puppet::Error, format('Error while executing the request %s', res)
      when 'Done'
        completed = true
      else
        raise Puppet::Error, format('Unknown status %s', res)
      end
    end
  end

  def self.generate_request(action, options)
    request = { 'action' => action }

    if options
      if (channel = options.find { |e| %r{--channel} =~ e })
        request['channel'] = channel.split('=')[1]
      end

      # classic, devmode and jailmode params are only available for install, refresh, revert actions.
      if %w[install refresh revert].include?(action)
        request['classic'] = true if options.include?('--classic')
        request['devmode'] = true if options.include?('--devmode')
        request['jailmode'] = true if options.include?('--jailmode')
      end

      request['purge'] = true if action == 'remove' && options.include?('purge')
    end

    request
  end

  def self.modify_snap(action, name, options = nil)
    req = generate_request(action, options)
    response = call_api('POST', "/v2/snaps/#{name}", req)
    change_id = get_id_from_async_req(response)
    complete(change_id)
  end
end
