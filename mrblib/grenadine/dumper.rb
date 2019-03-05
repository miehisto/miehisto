module Grenadine
  class Dumper
    def initialize(argv)
      idx = argv.index("-t") || argv.index("--target")
      # TODO: can be auto-detected when grenadine is a service
      if idx
        @pid = argv[idx + 1]
      end
      if ! @pid
        raise "Target PID must be specified via <--target TAGRET>"
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
  end
end
