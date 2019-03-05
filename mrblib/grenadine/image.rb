module Grenadine
  class Image
    def initialize(process_id)
      @process_id = process_id
    end
    attr_reader :process_id

    def valid?
      !! pid_1_img
    end

    def images_dir_path
      "/var/lib/grenadine/images/#{process_id}"
    end

    def pid_1_path
      "#{images_dir_path}/core-1.img"
    end

    def pid_1_img
      if File.exist? pid_1_path
        @img ||= File.open(pid_1_path, 'r')
      end
    end

    def json_from_crit
      @data ||= JSON.parse(`crit decode -i #{pid_1_path}`)
    end

    def comm
      json_from_crit["entries"][0]["tc"]["comm"]
    rescue
      "<unknown>"
    end

    def ctime
      if pid_1_img
        Time.at(GrenadineUtil.get_ctime(pid_1_img.fileno))
      end
    end

    def page_size
      files = `find #{images_dir_path}/pages*.img -type f`.lines.map{|l| l.chomp}
      raw = GrenadineUtil.get_page_size(files)
      if raw >= 1024 * 1024 * 1024
        "%.2fGiB" % (raw.to_f / (1024 * 1024 * 1024))
      elsif raw >= 1024 * 1024
        "%.2fMiB" % (raw.to_f / (1024 * 1024))
      elsif raw >= 1024
        "%.2fKiB" % (raw.to_f / 1024)
      else
        raw
      end
    end

    def to_fmt_arg
      [process_id, ctime, comm[0..9], page_size]
    end

    FORMAT = "%-32s\t%-25s\t%-10s\t%-8s"

    def self.list(_)
      images = []
      `find /var/lib/grenadine/images/* -type d`.each_line do |path|
        process_id = File.basename(path.chomp)
        images << Image.new(process_id)
      end
      puts FORMAT % %w(IMAGE_ID CTIME COMM MEM_SIZE)
      images.select{|i| i.valid? }.sort_by{|i| i.ctime }.reverse.each do |img|
        puts FORMAT % img.to_fmt_arg
      end
    end
  end
end
