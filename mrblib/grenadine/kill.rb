module Grenadine
  class Kill
    def initialize(argv)
      @sig = nil
      _sig = argv[0]
      case _sig
      when nil
        @sig = :TERM
      when /^\d+$/
        @sig = _sig.chomp.to_i
      else
        @sig = _sig.chomp.to_sym
      end
    end

    def kill
      Process.kill @sig, Util.detect_target_pid
      puts "Kill sent."
    end
  end
end
