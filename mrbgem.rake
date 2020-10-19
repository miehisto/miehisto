MRuby::Gem::Specification.new('miehisto') do |spec|
  spec.license = 'MIT'
  spec.authors = 'Uchio Kondo'
  spec.bins = %w(miehistod mhctl runmh)

  def spec.add_core_dep(name)
    self.add_dependency name, core: name
  end

  def spec.add_github_dep(reponame)
    self.add_dependency reponame.split('/')[-1], github: reponame
  end

  spec.add_core_dep 'mruby-array-ext'
  spec.add_core_dep 'mruby-string-ext'
  spec.add_core_dep 'mruby-enum-ext'
  spec.add_core_dep 'mruby-io'
  spec.add_core_dep 'mruby-time'
  spec.add_core_dep 'mruby-sprintf'
  spec.add_core_dep 'mruby-print'

  spec.add_dependency 'mruby-dir'
  spec.add_dependency 'mruby-process'
  spec.add_dependency 'mruby-env'
  spec.add_dependency 'mruby-linux-namespace'
  spec.add_dependency 'mruby-errno'
  spec.add_dependency 'mruby-sha1'
  spec.add_dependency 'mruby-iijson'
  spec.add_dependency 'mruby-regexp-pcre'
  spec.add_github_dep 'haconiwa/mruby-exec'
  spec.add_github_dep 'haconiwa/mruby-mount'
  spec.add_github_dep 'haconiwa/mruby-procutil'
  spec.add_github_dep 'haconiwa/mruby-process-sys'
  spec.add_github_dep 'udzura/mruby-fibered_worker'
  spec.add_github_dep 'udzura/mruby-lockfile'
  spec.add_github_dep 'udzura/mruby-criu'

  spec.add_test_dependency 'mruby-bin-mruby' , :core => 'mruby-bin-mruby'
  unless ENV['PRODUCTION_BUILD']
    spec.add_test_dependency 'mruby-bin-mirb' , :core => 'mruby-bin-mirb'
  end

  spec.build.cc.defines << %(MRB_CRIU_USE_STATIC)
end
