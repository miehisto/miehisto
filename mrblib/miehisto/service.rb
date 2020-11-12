# frozen_string_literal: true

module Miehisto
  class Service

    def initialize(writer:, service_pid:)
      @writer = writer
      @service_pid = service_pid
    end
    attr_reader :pid, :args, :object_id

    def create(args: [])
      raise("args must be an Array form") unless args.is_a?(Array)
      args.map{|a| a.gsub!("\t", " ") }
      @args = args.join("\t")
      @object_id = SHA1.sha1_hex("#{@args}|#{Time.now.to_i}")
      @writer.write("ADD\t#{@object_id}\t#{@args}\t\t")

      Process.kill :USR1, @service_pid

      @pid = 0 # TODO: get the pid! dummy
    end
  end
end
