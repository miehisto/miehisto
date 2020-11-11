# frozen_string_literal: true

module Miehisto
  # Container: inplies runmh minimal container
  class Container
    GREN_SV_PIDFILE_PATH = '/var/run/runmh-%d.pid'

    def initialize(uid: 0, gid: 0, workdir: '/', envvars: {}, argv: nil)
      @uid = uid
      @gid = gid
      @workdir = workdir
      @envvars = envvars
      @argv = argv
    end
    attr_reader :argv, :uid, :gid, :workdir, :envvars

    def run
      newroot = "/var/run/grenadine/con-#{$$}"
      @pidfile = Pidfile.create(pidfile_path)

      system "mkdir -p #{newroot}"
      system "mkdir -p /var/log/grenadine"

      comm = File.basename(self.argv[0])
      if self.uid > 0 || self.gid > 0
        system "touch /var/log/grenadine/#{comm}.out && chown #{self.uid}:#{self.gid} /var/log/grenadine/#{comm}.out"
        system "touch /var/log/grenadine/#{comm}.err && chown #{self.uid}:#{self.gid} /var/log/grenadine/#{comm}.err"
      end
      this = self
      pid = Namespace.clone(Namespace::CLONE_NEWNS|Namespace::CLONE_NEWPID) do
        begin
          this.make_isolated_root(newroot)
          MiehistoUtil.pivot_root_to(newroot)
          Mount.mount "proc", "/proc", type: "proc"
          Procutil.setsid
          Dir.chdir this.workdir
          Process::Sys.setuid(this.uid) if this.uid > 0
          Process::Sys.setgid(this.gid) if this.gid > 0


          in_io  = File.open("/dev/null", "r")
          out_io = File.open("/var/log/grenadine/#{comm}.out", "a")
          err_io = File.open("/var/log/grenadine/#{comm}.err", "a")

          Procutil.fd_reopen3(in_io.fileno, out_io.fileno, err_io.fileno)
          Exec.execve ENV.to_hash.merge(this.envvars), *this.argv
        rescue => e
          puts "Error: #{e.inspect}"
          exit 127
        end
      end

      puts "Containerized process (#{pid}:#{@argv.inspect}) is starting..."
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
      system "rmdir #{newroot}"
    end

    def pidfile_path
      GREN_SV_PIDFILE_PATH % $$
    end

    private
    def make_isolated_root(newroot)
      hostroot = if `mount | grep ' on / '`.include?("squashfs") # for snap
                   "/var/lib/snapd/hostfs"
                 else
                   "/"
                 end

      Mount.make_rprivate hostroot
      Mount.bind_mount hostroot, newroot
      # TODO: we cannt dump /run when bind-mounted
      # TODO: duplicated. Extract it from CRIUAble module...
      bind_dirs = %w(/dev /dev/pts /dev/shm /dev/mqueue /tmp /sys /sys/fs/cgroup)
      `cat /proc/mounts | grep '^cgroup '`.each_line do |ln|
        if ln.split[2] == "cgroup"
          bind_dirs << ln.split[1]
        end
      end
      bind_dirs.each do |path|
        Mount.bind_mount path, "#{newroot}#{path}"
      end
    rescue => e
      puts "Error: #{e.inspect}"
      exit 127
    end
  end
end
