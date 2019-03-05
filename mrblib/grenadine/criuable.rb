module Grenadine
  # Luckily, C is prior to Dump or Restore
  module CRIUAble
    def images_dir
      "/var/lib/grenadine/images/#{process_id}"
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
  end
end
