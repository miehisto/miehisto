module Grenadine
  class Dumper
    def initialize(argv)
      idx = argv.index("-t") || argv.index("--target")
      if idx
        @pid = argv[idx + 1]
      end
      if ! @pid
        @pid = detect_target_pid
      end

      @criu = nil
      @process_id = SHA1.sha1_hex("#{@pid}|#{Time.now.to_i}")
    end
    attr_reader :process_id
    include CRIUAble

    def dump
      criu = make_criu_request
      criu.set_pid @pid.to_i
      criu.dump
      puts "Dumped into: #{images_dir}"
    rescue => e
      puts "Error: #{e}"
      exit 3
    end

    def detect_target_pid
      ppid = Pidfile.pidof(Container::GREN_SV_PIDFILE_PATH)
      unless ppid
        raise "Grenadine supervisor process does not exist"
      end
      pid = Util.ppid_to_pid(ppid)
      unless pid
        raise "Managed service does not exist"
      end
      return pid
    end
  end
end
