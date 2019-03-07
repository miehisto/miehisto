module Grenadine
  class Container
    GREN_SV_PIDFILE_PATH = "/var/run/grenadine.pid"

    def initialize(argv)
      @uid = @gid = 0
      @workdir = '/'
      @envvars = {}

      if argv.include? '--'
        o = GetoptLong.new(
          ['-h', '--help', GetoptLong::NO_ARGUMENT],
          ['-u', '--uid', GetoptLong::OPTIONAL_ARGUMENT],
          ['-g', '--gid', GetoptLong::OPTIONAL_ARGUMENT],
          ['-C', '--workdir', GetoptLong::OPTIONAL_ARGUMENT],
          ['-e', '--envvar', GetoptLong::OPTIONAL_ARGUMENT],
        )
        o.ARGV = argv
        o.each do |optname, optarg| # run parse
          case optname
          when '-u'
            if (ug = optarg.split(':')).size == 2
              @uid = wrap_uid(ug[0])
              @gid = wrap_gid(ug[1])
            else
              @uid = wrap_uid(optarg)
            end
          when '-g'
            @gid = wrap_gid(optarg)
          when '-C'
            @workdir = optarg
          when '-e'
            k, v = optarg.split('=')
            @envvars[k] = v
          when '-h'
            help
          end
        end
        @argv = o.unparsed_argv
      else
        help if argv.include?('-h') || argv.include?('--help')
        @argv = argv
      end
    end
    attr_reader :argv, :uid, :gid, :workdir, :envvars

    def help
      puts <<-HELP
grenadine daemon: daemonize and manage your application

Usage:
  grenadine daemon [SERVICE_COMMAND...]
With options:
  grenadine daemon [OPTIONS] -- [SERVICE_COMMAND...]
Options
  -h, --help           Show this help
  -u, --uid UID[:GID]  Specify service's uid (and gid). Both name and numeric ID are available
  -g, --gid GID        Specify service's gid. Both name and numeric ID are available
  -C, --workdir CWD    Specify service's working directory. Default to /
  -e, --envbar FOO=xxx Set environment variables. Can be declared in many times.
      HELP
      exit
    end

    def run
      @pidfile = Pidfile.create GREN_SV_PIDFILE_PATH

      newroot = "/var/run/grenadine/con-#{$$}"
      system "mkdir -p #{newroot}"

      this = self
      pid = Namespace.clone(Namespace::CLONE_NEWNS|Namespace::CLONE_NEWPID) do
        begin
          this.make_isolated_root(newroot)
          GrenadineUtil.pivot_root_to(newroot)
          Mount.mount "proc", "/proc", type: "proc"
          Procutil.setsid
          # TODO set uid/gid here
          Dir.chdir this.workdir
          Process::Sys.setuid(this.uid) if this.uid > 0
          Process::Sys.setgid(this.gid) if this.gid > 0

          Procutil.daemon_fd_reopen # again, TODO: make optional
          Exec.execve ENV.to_hash.merge(this.envvars), *this.argv
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
    ensure
      @pidfile.remove if @pidfile
      system "rmdir -p #{newroot}"
    end

    def spawn
      pid = Process.fork do
        Procutil.daemon_fd_reopen
        self.run
      end
      puts "Spawned: #{pid}"
    end

    def self.run(argv)
      new(argv).run
    end

    def self.spawn(argv)
      new(argv).spawn
    end

    private
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

    def wrap_uid(rawstr)
      if rawstr.is_a?(String) and rawstr !~ /^\d+$/
        ::Process::UID.from_name rawstr
      else
        rawstr.to_i
      end
    end

    def wrap_gid(rawstr)
      if rawstr.is_a?(String) and rawstr !~ /^\d+$/
        ::Process::GID.from_name rawstr
      else
        rawstr.to_i
      end
    end
  end
end
