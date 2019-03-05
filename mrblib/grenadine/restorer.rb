module Grenadine
  class Restorer
    def initialize(argv)
      idx = argv.index("-f") || argv.index("--from")
      if idx
        @process_id = argv[idx + 1]
      end
      if ! @process_id
        raise "Dump image ID must be specified via <--from IMAGE_SHA>"
      end
      @foreground = argv.include?("--foreground")
    end
    attr_reader :process_id
    include CRIUAble

    def do_restore
      cmd = make_criu_command_obj
      system "mkdir -p #{run_root}"
      Namespace.unshare(Namespace::CLONE_NEWNS)
      Mount.make_rprivate "/"
      Mount.bind_mount "/", run_root
      puts "Command: #{cmd.to_execve_arg.inspect}"
      Exec.execve(ENV.to_hash, *cmd.to_execve_arg)
    rescue => e
      puts "Error: #{e}"
      system "rmdir #{run_root}"
      exit 1
    end

    def restore
      if @foreground
        self.do_restore
        puts "Restored #{process_id}: #{pid}"
        return
      end

      pid = Process.fork do
        Procutil.daemon_fd_reopen
        self.do_restore
      end
      puts "Restored #{process_id}: #{pid}"
    end
  end
end
