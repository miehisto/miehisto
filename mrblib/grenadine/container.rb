module Grenadine
  class Container
    def initialize(argv)
      if argv[0] == '--'
        argv.shift
      end
      @argv = argv
    end

    def run
      newroot = "/var/run/grenadine/con-#{$$}"
      system "mkdir -p #{newroot}"

      this = self
      argv = @argv
      pid = Namespace.clone(Namespace::CLONE_NEWNS|Namespace::CLONE_NEWPID) do
        begin
          this.make_isolated_root(newroot)
          Grenadine.pivot_root_to(newroot)
          Mount.mount "proc", "/proc", type: "proc"
          Procutil.setsid
          Procutil.daemon_fd_reopen # again, TODO: make optional
          Exec.execve ENV.to_hash, *argv
        rescue => e
          puts "Error: #{e.inspect}"
          exit 127
        end
      end

      puts "Containerized process (#{pid}:#{@argv.inspect}) is starting..."
      ml = FiberedWorker::MainLoop.new
      ml.pid = pid
      s = ml.run
      puts "exited: #{s.inspect}"
      # system "rmdir -p #{newroot}"
    end

    def spawn
      pid = Process.fork do
        Procutil.daemon_fd_reopen
        self.run
      end
      puts "Spawned: #{pid}"
    end

    def make_isolated_root(newroot)
      Mount.make_rprivate "/"
      Mount.bind_mount "/", newroot
      # TODO: we cannt dump /run when bind-mounted
      # TODO: automate exporting all of these subfolders as --external
      %w(/dev /dev/pts /dev/shm /dev/mqueue /tmp).each do |path|
        Mount.bind_mount path, "#{newroot}#{path}"
      end
    rescue => e
      puts "Error: #{e.inspect}"
      exit 127
    end

    def self.run(argv)
      new(argv).run
    end

    def self.spawn(argv)
      new(argv).spawn
    end
  end
end
