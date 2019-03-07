module Grenadine
end

def __main__(argv)
  argv = ARGV.dup
  cmdline = argv.shift
  case argv[0]
  when "exec-cmd" # special path after restore
    Grenadine::Restorer::OnExecCmd.rexec(argv[1])
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
    if ENV['GREN_RESTORED_SV']
      Grenadine::Restorer::Supervisor.new.supervise
    else
      Grenadine::Restorer.new(argv[1..-1]).restore
    end
  when "help"
    puts "...help"
  else
    raise "Invalid subcommand: #{argv[0]}"
  end
end
