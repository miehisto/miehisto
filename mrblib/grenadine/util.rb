module Grenadine
  module Util
    def self.ppid_to_pid(ppid)
      status = `find /proc -maxdepth 2 -regextype posix-basic -regex '/proc/[0-9]\\+/status'`.
               split.
               find {|f| ::File.read(f).include? "PPid:\t#{ppid}\n" rescue false }
      return nil unless status
      status.split('/')[2].to_i
    end

    def self.self_exe
      File.readlink "/proc/self/exe"
    end
  end
end
