module Grenadine
  class Container
    def initialize(argv)
      if argv[0] == '--'
        argv.shift
      end
      @argv = argv
    end

    def run
      newproc = "/var/run/grenadine/proc-#{$$}"
      system "mkdir -p #{newproc}"

      this = self
      argv = @argv
      pid = Namespace.clone(Namespace::CLONE_NEWNS|Namespace::CLONE_NEWPID) do
        begin
          Mount.make_rprivate "/"
          Mount.mount "proc2", newproc, type: "proc"
          Mount.bind_mount newproc, "/proc"
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
    end

    def self.run(argv)
      new(argv).run
    end
  end
end
