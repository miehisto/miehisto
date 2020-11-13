# frozen_string_literal: true

module Miehisto
  class Image
    def initialize(object_id)
      @object_id = object_id
    end
    attr_reader :object_id

    def valid?
      File.exist? pid_1_path
    end

    def images_dir_path
      "#{self.class.images_dir}/#{object_id}"
    end

    # FIXME: move to const or global config
    def self.images_dir
      ENV['GREN_IMAGES_DIR'] || "/var/lib/miehisto/images"
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
        Time.at(MiehistoUtil.get_ctime(pid_1_img.fileno))
      end
    end

    def page_size
      files = `find #{images_dir_path}/pages*.img -type f`.lines.map{|l| l.chomp}
      raw = MiehistoUtil.get_page_size(files)
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

    def to_params
      {
        object_id: object_id,
        # ctime: ctime.strftime("%Y-%m-%dT%H:%M:%S%:z") but not supported %:z
        ctime: ctime.to_s,
        comm: comm,
        page_size: page_size
      }
    end

    def self.find_index(i)
      self.find_all[i]
    end

    def self.find_all(limit=nil)
      if `ls #{self.images_dir} | wc -l`.to_i == 0
        return []
      end
      images = []
      `find #{self.images_dir}/* -type d`.each_line do |path|
        object_id = File.basename(path.chomp)
        images << Image.new(object_id)
      end
      if limit
        images.select{|i| i.valid? }.sort_by{|i| i.ctime }.reverse[0, limit]
      else
        images.select{|i| i.valid? }.sort_by{|i| i.ctime }.reverse
      end
    end
  end
end
