module Grenadine
end

def __main__(argv)
  argv = ARGV.dup
  cmdline = argv.shift
  case argv[0]
  when "start"
    Grenadine::Container.run(argv[1..-1])
  end
end
