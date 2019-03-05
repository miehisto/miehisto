MRuby::Gem::Specification.new('grenadine') do |spec|
  spec.license = 'MIT'
  spec.authors = 'Uchio Kondo'
  spec.bins = ["grenadine"]

  def spec.add_core_dep(name)
    self.add_dependency name, core: name
  end

  def spec.add_github_dep(reponame)
    self.add_dependency reponame.split('/')[-1], github: reponame
  end

  spec.add_core_dep 'mruby-array-ext'
  spec.add_core_dep 'mruby-string-ext'
  spec.add_core_dep 'mruby-io'
  spec.add_core_dep 'mruby-time'
  spec.add_core_dep 'mruby-sprintf'
  spec.add_core_dep 'mruby-print'

  spec.add_dependency 'mruby-process'
  spec.add_dependency 'mruby-env'
  spec.add_dependency 'mruby-linux-namespace'
  spec.add_dependency 'mruby-errno'
  spec.add_dependency 'mruby-sha1'
  spec.add_dependency 'mruby-iijson'
  # spec.add_dependency 'mruby-onig-regexp'
  spec.add_github_dep 'haconiwa/mruby-exec'
  spec.add_github_dep 'haconiwa/mruby-mount'
  spec.add_github_dep 'haconiwa/mruby-procutil'
  spec.add_github_dep 'udzura/mruby-fibered_worker'
  spec.add_github_dep 'matsumotory/mruby-criu'

  spec.add_test_dependency 'mruby-bin-mruby' , :core => 'mruby-bin-mruby'

  spec.build.cc.defines << %(MRB_CRIU_USE_STATIC)
end
