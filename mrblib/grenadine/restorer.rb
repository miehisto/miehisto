module Grenadine
  class Restorer
    def initialize(argv)
      o = GetoptLong.new(
        ['-h', '--help', GetoptLong::NO_ARGUMENT],
        ['-f', '--from', GetoptLong::OPTIONAL_ARGUMENT],
        ['-D', '--debug-foreground', GetoptLong::NO_ARGUMENT],
      )
      o.ARGV = argv
      o.each do |optname, optarg| # run parse
        case optname
        when '-f'
          @process_id = optarg
        when '-D'
          @foreground = true
        when '-h'
          help
          exit
        end
      end

      if ! @process_id
        image = o.ARGV.empty? ?
                  Image.find_index(0) :
                  Image.find_index(o.ARGV[0].to_i)
        unless image
          help
          raise "Invalid image index: #{o.ARGV[0]}"
        end
        @process_id = image.process_id
      end
    end
    attr_reader :process_id
    include CRIUAble

    def help
      puts <<-HELP
grenadine restore: restore your application from a dumped image
  check out the image index or hash from `grenadine list'

Usage:
  grenadine restore [IMAGE_IDX]
Usage from image hash:
  grenadine restore --from [IMAGE_SHA1]
Options
  -h, --help            Show this help
  -f, --from IMAGE_SHA1 Specify image's sha1 to use for restore
      HELP
    end

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
        ml = FiberedWorker::MainLoop.new(interval: 5)
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
