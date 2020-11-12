# frozen_string_literal: true

module Miehisto
  class Dumper
    def initialize(pid:, leave_running: false, object_id: nil)
      @pid = pid
      @leave_running = leave_running

      @object_id = object_id || SHA1.sha1_hex("#{@pid}|#{Time.now.to_i}")
    end
    attr_reader :pid, :criu

    def dump
      @ops = CRIUOps.new(@object_id)
      @criu = @ops.make_criu_request
      @criu.set_pid @pid.to_i
      if @leave_running
        @criu.set_leave_running true
      end
      @criu.dump
      puts "Dumped into: #{@ops.images_dir}"
    end
    alias run dump

    def images_dir
      @ops.images_dir
    end
  end
end
