module Grenadine
  class Image
    def initialize(process_id)
      @process_id = process_id
    end
    attr_reader :process_id

    def valid?
      File.exist? pid_1_path
    end

    def images_dir_path
      "/var/lib/grenadine/images/#{process_id}"
    end

    def pid_1_path
      "#{images_dir_path}/core-1.img"
    end

    def pid_1_img
      if valid?
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

    HDR_FORMAT = "%3s\t%-32s\t%-25s\t%-10s\t%-8s"
    FORMAT = "%3d\t%-32s\t%-25s\t%-10s\t%-8s"

    def self.find_index(i)
      self.find_all[i]
    end

    def self.find_all
      images = []
      `find /var/lib/grenadine/images/* -type d`.each_line do |path|
        process_id = File.basename(path.chomp)
        images << Image.new(process_id)
      end
      images.select{|i| i.valid? }.sort_by{|i| i.ctime }.reverse
    end

    def self.list(_)
      puts HDR_FORMAT % %w(IDX IMAGE_ID CTIME COMM MEM_SIZE)
      self.find_all.each_with_index do |img, i|
        puts FORMAT % [i, *img.to_fmt_arg]
      end
    end
  end
end
