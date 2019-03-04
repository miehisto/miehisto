module Grenadine
end

def __main__(argv)
  argv = ARGV.dup
  cmdline = argv.shift
  case argv[0]
  when "start", "run"
    Grenadine::Container.run(argv[1..-1])
  when "daemon"
    Grenadine::Container.spawn(argv[1..-1])
  else
    raise "Invalid subcommand: #{argv[0]}"
  end
end
