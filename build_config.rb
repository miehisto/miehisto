module CRIU
  CRIU_VERSION = "3.14"
end

def gem_config(conf)
  # conf.cc.defines << ...
  conf.gem File.expand_path(File.dirname(__FILE__))
end

MRuby::Build.new do |conf|
  toolchain :gcc

  # conf.enable_bintest
  conf.enable_debug
  conf.enable_test

  conf.cc.flags << '-std=gnu99 -Wno-declaration-after-statement'

  gem_config(conf)
end
