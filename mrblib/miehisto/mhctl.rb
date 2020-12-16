# frozen_string_literal: true

module Miehisto
  # MHCtl: mhctl command entrypoint
  class MHCtl
    def self.__main__(argv)
      service = argv.shift
      case service
      when "service", "services", "s"
        comm = argv.shift
        case comm
        when "list"
          o = MHCli.service.index
          fmt = "%-32s %-5s %-5s %s"
          puts fmt % %w(OBJECT_ID PID PPID ARGS)
          puts o.map { |i|
            fmt %
              [i["object_id"], i["pid"].to_s ,i["ppid"].to_s, i["args"].join(" ")]
          }.join("\n")
        when "create", "add"
          argv.shift if argv[0] == '--'
          o = MHCli.service.create(body: %Q|{"args": #{argv.inspect}}|)
          if o["message"]
            puts "Error: #{o["message"]}"
          else
            puts o["object_id"]
          end
        when "dump"
          pid = if argv.shift == '-t'
                  argv[0]
                else
                  raise ArgumentError, "invalid: " + ARGV.inspect
                end
          o = MHCli.service.dumps!.create(body: %Q|{"pid": #{pid}}|)
          if o["message"]
            puts "Error: #{o["message"]}"
          else
            puts o["images_dir"]
          end
        when "restore"
          object_id = if argv.shift == '--from'
                        argv[0]
                      else
                        raise ArgumentError, "invalid: " + ARGV.inspect
                      end
          o = MHCli.service.restore(body: %Q|{"object_id": "#{object_id}"}|)
          if o["message"]
            puts "Error: #{o["message"]}"
          else
            puts o["object_id"]
          end
        else
          puts "Usage: mhctl service [list|create|dump|restore]"
        end
      when "image", "images", "i"
        comm = argv.shift
        case comm
        when "list"
          o = MHCli.image.index
          fmt = "%-32s %-12s %-10s %-28s"
          puts fmt % %w(OBJECT_ID COMM PAGE_SIZE CTIME)
          puts o.map { |i|
            fmt %
              [i["object_id"],
               i["comm"],
               i["page_size"],
               i["ctime"]]
          }.join("\n")
        else
          puts "Usage: mhctl image [list|...]"
        end
      else
        puts "Usage: mhctl [service|image] subcommand"
      end
    end
  end

  class MHCli
    def initialize(*path_init)
      @paths = *path_init
    end

    def handle_response(ret)
      if ret.status.include?("200")
        JSON.parse(ret.body)
      else
        raise "API failed: #{ret.body} status = #{ret.status}"
      end
    end

    def method_missing(name, *a)
      if name.to_s.end_with?('!')
        @paths << name.to_s.sub(/\!$/, '')
        return self
      else
        @paths << name.to_s
        if a.empty?
          handle_response(MHCli.http.get("/" + @paths.join("/")))
        elsif a.size == 1 && a[0].is_a?(Hash)
          body = a[0][:body]
          handle_response(MHCli.http.post(
            "/" + @paths.join("/"),
            {'Body' => body}
          ))
        else
          super
        end
      end
    end

    class << self
      def http
        # TODO: tcp socket
        @http ||= begin
                    path = ENV['MIEHISTOD_SOCKET_PATH'] ||
                           ENV['SERVER_URL'] ||
                           '/var/run/miehistod.sock'
                    SimpleHttp.new("unix", path)
                  end
      end

      def service
        new("v1", "services")
      end

      def image
        new("v1", "images")
      end
    end
  end
end
