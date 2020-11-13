# frozen_string_literal: true

module Miehisto
  # MHCtl: mhctl command entrypoint
  class MHCtl
    def self.__main__(argv)
      service = argv.shift
      case service
      when "service", "s"
        comm = argv.shift
        case comm
        when "list"
          o = JSON.parse `curl -s http://127.0.0.1:14444/v1/services/index`
          fmt = "%-32s %-5s %-5s %s"
          puts fmt % %w(OBJECT_ID PID PPID ARGS)
          puts o.map { |i|
            fmt %
              [i["object_id"], i["pid"].to_s ,i["ppid"].to_s, i["args"].join(" ")]
          }.join("\n")
        when "create"
          argv.shift if argv[0] == '--'
          o = JSON.parse `curl -s -d '{"args": #{argv.inspect}}' http://127.0.0.1:14444/v1/services/create`
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
          o = JSON.parse `curl -s -d '{"pid": #{pid}}' http://127.0.0.1:14444/v1/services/dumps/create`
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
          o = JSON.parse `curl -s -d '{"object_id": "#{object_id}"}' http://127.0.0.1:14444/v1/services/restore`
          if o["message"]
            puts "Error: #{o["message"]}"
          else
            puts o["object_id"]
          end
        end
      when "image", "i"
        comm = argv.shift
        case comm
        when "list"
          o = JSON.parse `curl -s http://127.0.0.1:14444/v1/images/index`
          fmt = "%-32s %-12s %-10s %-28s"
          puts fmt % %w(OBJECT_ID COMM PAGE_SIZE CTIME)
          puts o.map { |i|
            fmt %
              [i["object_id"],
               i["comm"],
               i["page_size"],
               i["ctime"]]
          }.join("\n")
        end
      else
        puts "Usage: mhctl service subcommand"
      end
    end
  end
end
