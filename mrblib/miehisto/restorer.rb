# frozen_string_literal: true

module Miehisto
  class Restorer
    # TODO: dup
    GREN_SV_PIDFILE_PATH = '/var/run/runmh-%d.pid'
    GREN_RES_PIDFILE_PATH = '/var/run/runmh-tmp.%s.%d.pid'
    def initialize(object_id:)
      @object_id = object_id
    end

    def run
      ENV['MIEHISTO_OBJECT_ID'] = @object_id
      ops = CRIUOps.new(@object_id)
      cmd = ops.make_criu_command_obj
      cmd.options.concat ["--pidfile", pidfile_path]
      cmd.exec_cmd = [Restorer.self_exe, "--exec-cmd", pidfile_path]
      system "mkdir -p #{ops.run_root(@object_id)}"
      Namespace.unshare(Namespace::CLONE_NEWNS)
      Mount.make_rprivate "/"
      Mount.bind_mount "/", ops.run_root(@object_id)
      puts "Command: #{cmd.to_execve_arg.inspect}"
      Exec.execve(ENV.to_hash, *cmd.to_execve_arg)
    rescue => e
      Mount.umount ops.run_root(@object_id)
      system "rmdir #{ops.run_root(@object_id)}"
      raise e
    end

    def supervise
      ops = CRIUOps.new(@object_id)
      pid = ENV['MIEHISTO_WAIT_TARGET_PID'].to_i
      @pidfile = Pidfile.create real_pidfile_path
      ml = FiberedWorker::MainLoop.new(interval: 5)
      ml.pid = pid
      ml.register_handler(FiberedWorker::SIGINT) do |signo|
        # Ensure kill process when supervisor is interrupted
        Process.kill :TERM, pid
      end
      s = ml.run
      puts "exited: #{s.inspect}"
    ensure
      @pidfile.remove if @pidfile
      if @object_id
        Mount.umount ops.run_root(@object_id)
        system "rmdir #{ops.run_root(@object_id)}"
      end
    end

    def pidfile_path
      GREN_RES_PIDFILE_PATH % [@object_id, $$]
    end

    def real_pidfile_path
      GREN_SV_PIDFILE_PATH % $$
    end

    def self.self_exe
      File.readlink "/proc/self/exe"
    end

    class OnExecCmd
      def self.rexec(pidfile_path)
        ENV['MIEHISTO_WAIT_TARGET_PID'] = File.open(pidfile_path, 'r').read
        File.unlink pidfile_path
        Exec.execve(ENV.to_hash, Restorer.self_exe, "--restored")
      end
    end
  end
end
