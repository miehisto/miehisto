# frozen_string_literal: true

module Miehisto
  # CRIUOps: CRIU operation wrapper
  class CRIUOps
    class Command
      def initialize(bin_path:, subcommand: "restore")
        @bin_path = bin_path
        @subcommand = subcommand
        @root = "/"
        @options = []
        @externals = []
        @run_exec_cmd = true
        @exec_cmd = nil
      end
      attr_accessor :options, :externals, :exec_cmd, :root

      def to_execve_arg
        [
          @bin_path,
          "restore"
        ] + rest_arguments
      end
      alias inspect to_execve_arg

      def rest_arguments
        a = ["--root", self.root]
        a.concat @options.dup
        @externals.each do |opt|
          a.concat(["--external", opt])
        end
        if @exec_cmd
          a.concat(["--exec-cmd", "--"])
          a.concat(@exec_cmd.dup)
        end
        a
      end
    end

    def initialize(process_id)
      @process_id = process_id
    end
    attr_reader :process_id

    def address
      @address ||= '/var/run/criu_service.socket'
    end

    def bin_path
      @bin_path ||= `which criu`.chomp
    end
    attr_writer :address, :bin_path

    def images_dir_root
      ENV['GREN_IMAGES_DIR'] || "/var/lib/miehisto/images"
    end

    def images_dir
      "#{images_dir_root}/#{process_id}"
    end

    def run_root_of_root
      ENV['GREN_RESTORE_ROOT'] || "/var/run/miehisto/restored"
    end

    def run_root(process_id)
      "#{run_root_of_root}/#{process_id}"
    end

    def service_address
      ENV['CRIU_SERVICE_ADDRESS'] || "/var/run/criu_service.socket"
    end

    def log_file
      ENV['CRIU_LOG_FILE'] || "-"
    end

    def external_bind_targets
      @external_bind_targets ||= begin
                                   bind_dirs = Consts::BIND_DIRS.dup
                                   `cat /proc/mounts | grep '^cgroup '`.each_line do |ln|
                                     if ln.split[2] == "cgroup"
                                       bind_dirs << ln.split[1]
                                     end
                                   end
                                   bind_dirs
                                 end
    end

    def external_mount_points
      @external_mount_points ||= external_bind_targets.map do |path|
        parts = path.split('/')
        prefix = parts.size == 1 ? parts.join : [parts[0], parts[-1]].join('__')
        [path, "#{prefix}-#{process_id}"]
      end
    end

    def make_criu_request
      system "mkdir -p #{images_dir}"

      c = CRIU.new
      c.set_images_dir images_dir
      c.set_service_address service_address
      c.set_log_file log_file
      c.set_shell_job true
      c.set_tcp_established true

      c.add_external "mnt[]:"
      external_mount_points.each do |mp|
        c.add_external "mnt[#{mp[0]}]:#{mp[1]}"
      end
      return c
    end

    def make_criu_command_obj
      # Force resetting PATH for super-clean environment
      if !ENV['PATH'] || ENV['PATH'] == ""
        ENV['PATH'] = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      end

      c = Command.new(bin_path: bin_path, subcommand: "restore")
      c.options << "--shell-job"
      c.options.concat ["--log-file", log_file]
      c.options.concat ["-D", images_dir]
      c.options << "--tcp-established"

      c.externals << "mnt[]:"
      external_mount_points.each do |mp|
        c.externals << "mnt[#{mp[1]}]:#{mp[0]}"
      end

      c.root = run_root
      # TODO: setting exec_cmd
      # TODO: cleanup run_root on container finished - this is exec_cmd's due
      return c
    end
  end
end
