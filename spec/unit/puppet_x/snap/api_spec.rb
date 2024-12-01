# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'puppet_x/snap/api'

module PuppetX::Snap
  describe NetX::HTTPUnix do
    let(:socket_url) { "unix://#{@socket_path}" }
    let(:get_request) { Net::HTTP::Get.new('/') }

    before :all do
      tmpfile = Tempfile.open('socket')
      @socket_path = tmpfile.path
      tmpfile.close
      tmpfile.unlink

      semaphore = Mutex.new
      servers_starting = 2

      @server_thread_tcp = Thread.new do
        TCPServer.open(2000) do |server|
          semaphore.synchronize { servers_starting -= 1 }
          while (conn = server.accept)
            conn.puts 'HTTP/1.1 200 OK'
            conn.puts ''
            conn.puts 'Hello from TCP server'
            conn.close_write
          end
        end
      end

      @server_thread_unix = Thread.new do
        UNIXServer.open(@socket_path) do |server|
          semaphore.synchronize { servers_starting -= 1 }
          while (conn = server.accept)
            conn.puts 'HTTP/1.1 200 OK'
            conn.puts ''
            conn.puts 'Hello from UNIX server'
            conn.close_write
          end
        end
      end

      sleep(0.01) while servers_starting > 0
    end

    after :all do
      Thread.kill(@server_thread_unix)
      Thread.kill(@server_thread_tcp)
    end

    describe '.start' do
      it "accepts '127.0.0.1', 2000 host and port" do
        resp = described_class.start('127.0.0.1', 2000) do |http|
          http.request(get_request)
        end
        expect(resp.body).to eq("Hello from TCP server\n")
      end

      it 'accepts unix:///path/to/socket URI' do
        resp = described_class.start(socket_url) do |http|
          http.request(get_request)
        end
        expect(resp.body).to eq("Hello from UNIX server\n")
      end
    end

    describe '.new' do
      it "accepts '127.0.0.1', 2000 host and port" do
        http = described_class.new('127.0.0.1', 2000)

        resp = http.request(get_request)
        expect(resp.body).to eq("Hello from TCP server\n")
      end

      it 'accepts unix:///path/to/socket URI' do
        http = described_class.new(socket_url)

        resp = http.request(get_request)
        expect(resp.body).to eq("Hello from UNIX server\n")
      end
    end
  end

  describe API do
    async_change_id_res = JSON.parse(File.read('spec/fixtures/responses/async_change_id_res.json'))
    error_res = JSON.parse(File.read('spec/fixtures/responses/error_res.json'))
    change_status_doing = JSON.parse(File.read('spec/fixtures/responses/change_status_doing.json'))
    change_status_done = JSON.parse(File.read('spec/fixtures/responses/change_status_done.json'))
    change_status_error = JSON.parse(File.read('spec/fixtures/responses/change_status_error.json'))

    context 'calling async operations' do
      it 'raises an error if response is an error' do
        expect { described_class.get_id_from_async_req(error_res) }.to raise_error(Puppet::Error)
      end

      it 'gets correct change id from response' do
        id = described_class.get_id_from_async_req(async_change_id_res)
        expect(id).to eq('77')
      end
    end

    context 'completing async operations' do
      it 'raises an error if response is an error' do
        allow(described_class).to receive(:get_status).with('10').and_return(change_status_error)

        expect { described_class.complete('10') }.to raise_error(Puppet::Error)
      end

      it 'sleeps for 1 second if response has not completed' do
        allow(described_class).to receive(:get_status).with('10').and_return(change_status_doing, change_status_done)
        allow(described_class).to receive(:sleep)
        described_class.complete('10')

        expect(described_class).to have_received(:sleep).with(1)
      end
    end
  end
end
