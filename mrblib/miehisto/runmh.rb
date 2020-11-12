# frozen_string_literal: true

module Miehisto
  # RunMH: rumh command entrypoint
  class RunMH
    class << self
      def __main__(argv)
        options = {}
        if argv[0] == '--restore'
          @restorer = Restorer.new(object_id: argv[1])
          @restorer.run
          exit
        elsif argv[0] == '--restored'
          @restorer = Restorer.new(object_id: ENV['MIEHISTO_OBJECT_ID'])
          @restorer.supervise
          exit
        elsif argv[0] == '--exec-cmd'
          @restorer = Restorer::OnExecCmd.rexec(argv[1])
          exit
        elsif argv.include? '--'
          options[:envvars] = {}
          o = GetoptLong.new(
            ['-h', '--help', GetoptLong::NO_ARGUMENT],
            ['-u', '--uid', GetoptLong::OPTIONAL_ARGUMENT],
            ['-g', '--gid', GetoptLong::OPTIONAL_ARGUMENT],
            ['-C', '--workdir', GetoptLong::OPTIONAL_ARGUMENT],
            ['-e', '--envvar', GetoptLong::OPTIONAL_ARGUMENT],
          )

          o.ARGV = argv
          o.each do |optname, optarg| # run parse
            case optname
            when '-u'
              if (ug = optarg.split(':')).size == 2
                options[:uid] = wrap_uid(ug[0])
                options[:gid] = wrap_gid(ug[1])
              else
                options[:uid] = wrap_uid(optarg)
              end
            when '-g'
              options[:gid] = wrap_gid(optarg)
            when '-C'
              options[:workdir] = optarg
            when '-e'
              k, v = optarg.split('=')
              options[:envvars][k] = v
            when '-h'
              help
            end
          end
          options[:argv] = o.unparsed_argv
        else
          help if argv.include?('-h') || argv.include?('--help')
          options[:argv] = argv
        end

        @container = Container.new(**options)
        @container.run
      end

      def help
        puts <<-HELP
runmh: serving your application with criu ready environment
Usage:
  runmh [SERVICE_COMMAND...]
With options:
  runmh [OPTIONS] -- [SERVICE_COMMAND...]
Options
  -h, --help           Show this help
  -u, --uid UID[:GID]  Specify service's uid (and gid). Both name and numeric ID are available
  -g, --gid GID        Specify service's gid. Both name and numeric ID are available
  -C, --workdir CWD    Specify service's working directory. Default to /
  -e, --envbar FOO=xxx Set environment variables. Can be declared in many times.
        HELP
        exit
      end

      def wrap_uid(rawstr)
        if rawstr.is_a?(String) and rawstr !~ /^\d+$/
          ::Process::UID.from_name rawstr
        else
          rawstr.to_i
        end
      end

      def wrap_gid(rawstr)
        if rawstr.is_a?(String) and rawstr !~ /^\d+$/
          ::Process::GID.from_name rawstr
        else
          rawstr.to_i
        end
      end
    end
  end
end
