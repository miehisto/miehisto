module Grenadine
  class Kill
    def initialize(argv)
      sig = nil
      _sig = argv[0]
      case _sig.chomp
      when /^\d+$/
        sig = _sig.to_i
      else
        sig = _sig.to_sym
      end

      Process.kill sig, Util.detect_target_pid
      puts "Kill sent."
    end
  end
end
