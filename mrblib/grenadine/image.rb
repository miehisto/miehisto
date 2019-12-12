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
      "#{self.class.images_dir}/#{process_id}"
    end

    def self.images_dir
      ENV['GREN_IMAGES_DIR'] || "/var/lib/grenadine/images"
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

    def self.find_all(limit=nil)
      if `ls #{self.images_dir} | wc -l`.to_i == 0
        return []
      end
      images = []
      `find #{self.images_dir}/* -type d`.each_line do |path|
        process_id = File.basename(path.chomp)
        images << Image.new(process_id)
      end
      if limit
        images.select{|i| i.valid? }.sort_by{|i| i.ctime }.reverse[0, limit]
      else
        images.select{|i| i.valid? }.sort_by{|i| i.ctime }.reverse
      end
    end

    def self.list(argv)
      @limit = 10
      o = GetoptLong.new(
        ['-h', '--help', GetoptLong::NO_ARGUMENT],
        ['-l', '--limit', GetoptLong::OPTIONAL_ARGUMENT],
      )
      o.ARGV = argv
      o.each do |optname, optarg| # run parse
        case optname
        when '-l'
          @limit = optarg.to_i
        when '-h'
          help_list
          exit
        end
      end

      puts HDR_FORMAT % %w(IDX IMAGE_ID CTIME COMM MEM_SIZE)
      self.find_all(@limit).each_with_index do |img, i|
        puts FORMAT % [i, *img.to_fmt_arg]
      end
    end

    def self.help_list
      puts <<-HELP
grenadine list: List available process images

Usage:
  grenadine list [OPTIONS]
Options
  -h, --help      Show this help
  -l, --limit NUM Limit images to show. Default to -l=10
      HELP
    end
  end
end
