# frozen_string_literal: true

module Miehisto
  # Service: managing services
  class Service
    def self.list(service_pid:)
      # Find all of direct children
      servie_pids = Dir.entries('/proc').
                      select{|d| d =~ /^\d+$/ &&
                             File.read("/proc/#{d}/status") =~ /PPid:\s+#{service_pid}/m }
      servie_pids.select! {|d| File.read("/proc/#{d}/comm") != "sleep\n" }
      servie_pids.map {|ppid|
        if pid = Util.ppid_to_pid(ppid)
          Service.from_pid(pid, ppid: ppid)
        end
      }.compact
    end

    def self.from_pid(pid, ppid: nil)
      s = new
      s.pid = pid
      s.ppid = ppid ? ppid.to_i : nil
      s.args = File.read("/proc/#{pid}/cmdline").split("\0")
      envvar = File.read("/proc/#{pid}/environ").split("\0").
                 find {|e| e.start_with?("MIEHISTO_OBJECT_ID=") }
      if envvar
        s.object_id = envvar.split('=')[1]
      end
      s
    end

    def initialize(writer: nil, service_pid: nil)
      @writer = writer
      @service_pid = service_pid
    end
    attr_accessor :pid, :ppid, :args, :object_id

    def to_params
      {
        pid: pid,
        ppid: ppid,
        args: args,
        object_id: object_id
      }
    end

    def create(args: [])
      raise("args must be an Array form") unless args.is_a?(Array)
      args.map{|a| a.gsub!("\t", " ") }
      @args = args.join("\t")
      @object_id = SHA1.sha1_hex("#{@args}|#{Time.now.to_i}")
      @writer.write("ADD\t#{@object_id}\t#{@args}\t\t")

      Process.kill :USR1, @service_pid

      @pid = 0 # TODO: get the pid! dummy
    end

    def restore(object_id:)
      @object_id = object_id
      @writer.write("RESTORE\t#{@object_id}\t\t")
      Process.kill :USR1, @service_pid

      @pid = 0 # TODO: get the pid! dummy
    end
  end
end
