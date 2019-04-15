module Grenadine
  class Dumper
    def initialize(argv)
      o = GetoptLong.new(
        ['-h', '--help', GetoptLong::NO_ARGUMENT],
        ['-t', '--target', GetoptLong::OPTIONAL_ARGUMENT],
        ['-L', '--leave-running', GetoptLong::NO_ARGUMENT],
      )
      o.ARGV = argv
      o.each do |optname, optarg| # run parse
        case optname
        when '-t'
          @pid = optarg.to_i
        when '-L'
          @leave_running = true
        when '-h'
          help
          exit
        end
      end

      if ! @pid
        @pid = Util.detect_target_pid
      end

      @process_id = SHA1.sha1_hex("#{@pid}|#{Time.now.to_i}")
    end
    attr_reader :process_id
    include CRIUAble

    def help
      puts <<-HELP
grenadine dump: Dump running service and make CRIU image into host

Usage:
  grenadine dump [OPTIONS]
Options
  -h, --help          Show this help
  -t, --target PID    Dump service from root pid. Default to auto-detect from grenadine SV
  -L, --leave-running Leave target service running after dump is created
      HELP
    end

    def dump
      criu = make_criu_request
      criu.set_pid @pid.to_i
      if @leave_running
        criu.set_leave_running true
      end
      criu.dump
      puts "Dumped into: #{images_dir}"
    rescue => e
      puts "Error: #{e}"
      exit 3
    end
  end
end
