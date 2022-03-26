# frozen_string_literal: true

require 'net_http_unix' if Puppet.features.net_http_unix_lib?
require 'socket'
require 'json'

module PuppetX
  module Snap
    module API
      class << self
        %w[post put get].each do |method|
          define_method(method) do |url, data = nil|
            request = Object.const_get("Net::HTTP::#{method.capitalize}").new(url)

            request.body = data.to_json if data

            request['Host'] = 'localhost'
            request['Accept'] = 'application/json'
            request['Content-Type'] = 'application/json'

            call_api(request)
          end
        end

        def call_api(request)
          client = ::NetX::HTTPUnix.new('unix:///run/snapd.socket')

          response = nil
          retried = 0
          max_retries = 5
          # Read timeout can happen while installing core snap. The snap daemon briefly restarts
          # which drops the connection to the socket.
          loop do
            response = client.request(request)
            break unless response.is_a?(Net::HTTPContinue)
          rescue Net::ReadTimeout, Net::OpenTimeout
            raise Puppet::Error, "Got timeout wile calling the api #{retried} times! Giving up..." if retried > max_retries

            Puppet.debug('Got timeout while calling the api, retrying...')
            retried += 1
            retry
          end

          JSON.parse(response.body)
        end

        # Helper method to return the change ID from a asynchronous request response.
        def get_id_from_async_req(request)
          # If the request failed raise an error
          raise Puppet::Error, "Request failed with #{request['result']['message']}" if request['type'] == 'error'

          request['change']
        end

        # Get the status of a change
        #
        # @param id The change ID to search for.
        def get_status(id)
          get("/v2/changes/#{id}")
        end

        # Queries the API for a specific change and waits until it has
        # been completed.
        #
        # @param id The change ID to search for.
        def complete(id)
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
              raise Puppet::Error, "Error while executing the request #{res}"
            when 'Done'
              completed = true
            else
              raise Puppet::Error, "Unknown status #{res}"
            end
          end
        end
      end
    end
  end
end
