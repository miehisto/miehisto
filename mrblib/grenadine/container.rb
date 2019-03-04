module Grenadine
  class Container
    def initialize(argv)
      if argv[0] == '--'
        agrv.shift
      end
      @argv = argv
    end

    def run
      newproc = "/var/run/grenadine/proc-#{$$}"
      system "mkdir -p #{mockproc}"

      this = self
      pid = Namespace.clone(Namespace::CLONE_NEWNS|Namespace::CLONE_NEWPID) do
        Mount.mount "proc2", newproc, type: "proc"
        Mount.bind_mount newproc, "/proc"
        Exec.execve ENV.to_hash, *argv
      end

      puts "Containerized process is starting..."
      ml = FiberedWorker::MainLoop.new
      ml.pid = pid
      ml.run
    end

    def self.run(argv)
      new(argv).run
    end
  end
end
