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
        when "dump"
        when "restore"

        end
      when "image", "i"
        comm = argv.shift
        case comm
        when "list"
          o = JSON.parse `curl -s http://127.0.0.1:14444/v1/images/index`
          fmt = "%-32s %-12s %-8s %24s"
          puts fmt % %w(OBJECT_ID COMM PAGE_SIZE CTIME)
          puts o.map { |i|
            fmt %
              [i["object_id"], i["comm"] ,i["page_size"], i["ctime"]]
          }.join("\n")
        end
      else
        puts "Usage: mhctl service subcommand"
      end
    end
  end
end
