# frozen_string_literal: true

module Miehisto
  # Daemon: miehistod command entrypoint
  class Daemon
    class << self
      def __main__(argv)
        case ENV.delete('MIEHISTOD_WORKER_MODE')
        when 'image-worker'
          ImageWorker.new(fd: ENV.delete('MIEHISTOD_FD')).run
        when 'service-worker'
          ServiceWorker.new(fd: ENV.delete('MIEHISTOD_FD')).run
        when 'http-worker'
          HTTPWorker.new().run
        else
          DaemonRoot.new().run
        end
      end
    end
  end

  # DaemonRoot: the root process for miehistod
  class DaemonRoot
    include FiberedWorker # for signal consts

    def initialize(port: 14444)
      @port = port
    end

    def run
      @image_worker = ImageWorker.reexec()
      @service_worker = ServiceWorker.reexec()
      writers = {
        image: @image_worker[:writer],
        service: @service_worker[:writer]
      }
      @http_worker = HTTPWorker.reexec(writers: writers, port: @port, service_pid: @service_worker[:pid])
      writers.values.each{|w| w.close }

      mainloop = FiberedWorker::MainLoop.new
      mainloop.pids = [@image_worker[:pid], @service_worker[:pid], @http_worker[:pid]]

      first_fail = true
      mainloop.register_handler(SIGINT) do |nr|
        first_fail = false
        puts "Accept SIGINT... exitting"
        mainloop.pids.each do |pid|
          Process.kill :TERM, pid
        end
      end

      mainloop.on_worker_exit do |status, rest|
        if first_fail
          puts "Wow, some worker(s) are failed accidentally: #{status.inspect}"
          puts "Kill all of workers and exit"
          first_fail = false
          mainloop.pids.each do |pid|
            Process.kill :TERM, pid
          end
        end
      end

      p mainloop.run
      puts "Miehistöt ovat viimeistelee töitä..."
    end
  end

  # HTTPWorker: This handles API requests
  class HTTPWorker
    def initialize(writers:, service_pid:)
      @writers = writers
      @service_pid = service_pid
    end

    def app
      HTTPApi.new(writers: @writers, service_pid: @service_pid)
    end

    def run
      port = ENV['MIEHISTOD_PORT']
      bind = ENV['MIEHISTOD_ADDR'] || '127.0.0.1'
      MiehistoUtil.sigpipe_ign!
      puts "[#{$$}] Starting server http://#{bind}:#{port}/"
      server = SimpleHttpServer.new(
        server_ip: bind,
        port: port.to_i,
        debug: true,
        app: app,
      )
      server.run
    end

    def self.reexec(writers:, port:, service_pid:)
      pid = Process.fork do
        envv = {
          'MIEHISTOD_WORKER_MODE' => 'http-worker',
          'MIEHISTOD_PORT' => port.to_s
        }
        # Exec.execve_override_procname(
        #   ENV.to_hash.merge(envv),
        #   "miehistod: HTTP worker",
        #   '/proc/self/exe'
        # )
        ENV['MIEHISTOD_PORT'] = port.to_s
        HTTPWorker.new(writers: writers, service_pid: service_pid).run
      end
      {pid: pid}
    end
  end

  # ImageWorker: this is image management loop
  class ImageWorker
    def initialize(reader:)
      @reader = reader
    end

    def run
      # TODO: fill me
      loop { sleep 100 }
    end

    def self.reexec
      r, w = IO.pipe
      pid = Process.fork do
        w.close
        envv = {
          'MIEHISTOD_WORKER_MODE' => 'image-worker',
          'MIEHISTOD_FD' => r.fileno
        }
        # Exec.execve_override_procname(
        #   ENV.to_hash.merge(envv),
        #   "miehistod: image worker",
        #   '/proc/self/exe'
        # )
        ImageWorker.new(reader: r).run
      end
      r.close
      {pid: pid, writer: w}
    end
  end

  # ServiceWorker: this is service worker
  class ServiceWorker
    def initialize(reader:)
      @reader = reader
    end

    RUNMH_PATH = "/usr/local/ghq/github.com/udzura/miehisto/mruby/bin/runmh"
    def run
      mainloop = FiberedWorker::MainLoop.new(interval: 0)
      spawner = fork { loop { sleep 65535 } } # the dummy busyloop
      mainloop.pids = [spawner]
      buf = ''
      mainloop.register_handler(:SIGUSR1) do |signo|
        begin
          loop do
            d = @reader.sysread(8192)
            buf << d
            break if buf.end_with?("\t\t")
          end

          puts "received: #{buf}"
          data = buf.split("\t")
          # only supports inst == "ADD"
          objid = data[1]
          args = data[2..-1]
          pid = fork do
            envvars = {
              'MIEHISTO_OBJECT_ID' => objid
            }
            argv = [RUNMH_PATH, "--"] + args
            puts argv
            Exec.execve ENV.to_hash.merge(envvars), *argv
          end
          mainloop.pids << pid
          puts "Add service: PID=#{pid}"
          buf = ''
        rescue => e
          puts e.inspect
          puts "Skip..."
        end
      end
      mainloop.register_handler(:SIGTERM) do |signo|
        puts "Accept #{signo}... exitting"
        mainloop.pids.each do |pid|
          Process.kill :TERM, pid
        end
        # TODO: force to kill frozen processes
      end
      mainloop.on_worker_exit do |status, rest|
        puts "Termed service! #{status} rest: #{rest}"
      end
      s = mainloop.run
      puts "Service Worker finished: #{s}"
    end

    def self.reexec(fd: nil)
      r, w = IO.pipe
      pid = Process.fork do
        w.close
        envv = {
          'MIEHISTOD_WORKER_MODE' => 'service-worker',
          'MIEHISTOD_FD' => r.fileno
        }
        # Exec.execve_override_procname(
        #   ENV.to_hash.merge(envv),
        #   "miehistod: service worker",
        #   '/proc/self/exe'
        # )
        ServiceWorker.new(reader: r).run
      end
      r.close
      {pid: pid, writer: w}
    end
  end
end
