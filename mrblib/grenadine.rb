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
  when "status"
    Grenadine::Status.new(argv[1..-1]).kill
  when "kill"
    Grenadine::Kill.new(argv[1..-1]).kill
  when "help"
    if argv[1]
      Exec.execve(ENV.to_hash, Grenadine::Util.self_exe, argv[1], "--help")
    else
      puts <<-HELP
grenadine: A checkpoint/restore manager for generic application services
version v#{Grenadine::VERSION}

Available subcommands:
  grenadine daemon  [OPTIONS] -- [COMMAND...]
  grenadine dump    [OPTIONS]
  grenadine restore [OPTIONS]
  grenadine list    [OPTIONS]
  grenadine version
  grenadine help    [SUBCOMMAND]
      HELP
    end
  else
    raise "Invalid subcommand: #{argv[0]}"
  end
end
