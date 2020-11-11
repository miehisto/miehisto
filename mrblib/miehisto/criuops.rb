# frozen_string_literal: true

module Miehisto
  # CRIUOps: CRIU operation wrapper
  class CRIUOps
    class << self
      def address
        @address ||= '/var/run/criu_service.socket'
      end

      def bin_path
        @bin_path ||= `which criu`.chomp
      end
      attr_writer :address, :bin_path

      def images_dir_root
        ENV['GREN_IMAGES_DIR'] || "/var/lib/grenadine/images"
      end

      def images_dir
        "#{images_dir_root}/#{process_id}"
      end

      def run_root_of_root
        ENV['GREN_RESTORE_ROOT'] || "/var/run/grenadine/restored"
      end

      def run_root
        "#{run_root_of_root}/#{process_id}"
      end

      def service_address
        ENV['CRIU_SERVICE_ADDRESS'] || "/var/run/criu_service.socket"
      end

      def log_file
        ENV['CRIU_LOG_FILE'] || "-"
      end

      BIND_DIRS = %w(/dev /dev/pts /dev/shm /dev/mqueue /tmp /sys /sys/fs/cgroup)
      def external_bind_targets
        @external_bind_targets ||= begin
                                     bind_dirs = BIND_DIRS.dup
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
    end



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

    class Lib
    end
  end
end
