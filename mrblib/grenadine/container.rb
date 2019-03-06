module Grenadine
  class Container
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
              @uid = ug[0].to_i
              @gid = ug[1].to_i
            else
              @uid = optarg.to_i
            end
          when '-g'
            @gid = optarg.to_i
          when '-C'
            @workdir = optarg
          when '-e'
            k, v = optarg.split('=')
            @envvars[k] = v
          else
            raise "Usage: TODO"
          end
        end
        @argv = o.unparsed_argv
      else
        @argv = argv
      end
    end
    attr_reader :argv, :uid, :gid, :workdir, :envvars

    def run
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
