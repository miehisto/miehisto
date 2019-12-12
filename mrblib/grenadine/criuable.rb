module Grenadine
  class RestoreCMD
    def initialize(bin_path)
      @bin_path = bin_path
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

  # Luckily, C is prior to Dump or Restore
  module CRIUAble
    def bin_path
      b = ENV['CRIU_BIN_PATH'] || `which criu`.chomp
      b.empty? ? "/usr/local/sbin/criu" : b
    end

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

    def external_mount_points
      %w(/dev /dev/pts /dev/shm /dev/mqueue /tmp).map do |path|
        [path, "#{path.tr('/', '_')}-#{process_id}"]
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

      c = RestoreCMD.new(bin_path)
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
