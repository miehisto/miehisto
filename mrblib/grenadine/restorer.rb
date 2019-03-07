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
      ENV['GREN_PROCESS_ID'] = @process_id

      cmd = make_criu_command_obj
      pidfile = "/var/run/grenadine.tmp-#{process_id}.pid"
      cmd.options.concat ["--pidfile", pidfile]
      cmd.exec_cmd = [Util.self_exe, "exec-cmd", pidfile]
      system "mkdir -p #{run_root}"
      Namespace.unshare(Namespace::CLONE_NEWNS)
      Mount.make_rprivate "/"
      Mount.bind_mount "/", run_root
      puts "Command: #{cmd.to_execve_arg.inspect}"
      Exec.execve(ENV.to_hash, *cmd.to_execve_arg)
    rescue => e
      puts "Error: #{e}"
      Mount.umount run_root
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

    class OnExecCmd
      def self.rexec(pidfile_path)
        ENV['GREN_RESTORED_SV'] = "1"
        ENV['GREN_WAIT_TARGET_PID'] = File.open(pidfile_path, 'r').read
        File.unlink pidfile_path
        Exec.execve(ENV.to_hash, Util.self_exe, "restore")
      end
    end

    class Supervisor
      def initialize
        @pid = ENV['GREN_WAIT_TARGET_PID'].to_i
        @process_id = ENV['GREN_PROCESS_ID']
        ENV['GREN_RESTORED_SV'] = nil
        ENV['GREN_WAIT_TARGET_PID'] = nil
      end
      attr_reader :process_id
      include CRIUAble

      def supervise
        @pidfile = Pidfile.create Container::GREN_SV_PIDFILE_PATH
        ml = FiberedWorker::MainLoop.new
        ml.pid = @pid
        s = ml.run
        puts "exited: #{s.inspect}"
      ensure
        @pidfile.remove if @pidfile
        Mount.umount run_root
        system "rmdir #{run_root}"
      end
    end
  end
end
