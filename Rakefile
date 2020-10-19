MRUBY_CONFIG=File.expand_path(ENV["MRUBY_CONFIG"] || "build_config.rb")
MRUBY_VERSION=ENV["MRUBY_VERSION"] || "2.1.2"

desc "setup packages"
task :packages do
  packages = %w(
    pkg-config python-ipaddress libbsd-dev
    libnftables-dev libcap-dev libnl-3-dev
    libnet-dev libaio-dev
    libprotobuf-dev libprotobuf-c-dev protobuf-c-compiler
    protobuf-compiler python-protobuf
  )
  sh "apt -y install #{packages.join(' ')}"
end

desc "install criu via PPA"
task :installcriu do
  sh "add-apt-repository ppa:criu/ppa"
  sh "apt update"
  sh "apt install criu"
end

file :mruby do
  sh "git clone --depth=1 git://github.com/mruby/mruby.git"
  if MRUBY_VERSION != 'master'
    Dir.chdir 'mruby' do
      sh "git fetch --tags"
      rev = %x{git rev-parse #{MRUBY_VERSION}}
      sh "git checkout #{rev}"
    end
  end
end

desc "compile binary"
task :compile => :mruby do
  if `uname` =~ /Darwin/
    raise "This binary cannot be built on Mac!!"
  end
  sh "cd mruby && rake all MRUBY_CONFIG=#{MRUBY_CONFIG}"
end

desc "test"
task :test => :mruby do
  if `uname` =~ /Darwin/
    raise "This binary cannot be built on Mac!!"
  end
  sh "cd mruby && rake all test MRUBY_CONFIG=#{MRUBY_CONFIG}"
end

desc "cleanup"
task :clean do
  exit 0 unless File.directory?('mruby')
  sh "cd mruby && rake deep_clean"
end

task :default => :compile
