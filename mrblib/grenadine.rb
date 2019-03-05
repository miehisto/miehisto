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
  # Implement below!
  when "dump"
    Grenadine::Dumper.new(argv[1..-1]).dump
  when "list", "ls"
    Grenadine::Image.list(argv[1..-1])
  when "version", "-V", "--version"
    puts "grenadine: v#{Grenadine::VERSION}"
  when "restore"
    Grenadine::Restorer.new(argv[1..-1]).restore
  when "help"
    puts "...help"
  else
    raise "Invalid subcommand: #{argv[0]}"
  end
end
