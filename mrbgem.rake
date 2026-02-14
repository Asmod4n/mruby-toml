MRuby::Gem::Specification.new('mruby-toml') do |spec|
  spec.license = 'MIT'
  spec.author  = 'Hendrik Beskow'
  spec.summary = 'toml11 binding for mruby'

  spec.add_dependency 'mruby-time'
  spec.add_dependency 'mruby-c-ext-helpers'
  spec.add_dependency 'mruby-string-ext'
  spec.add_dependency 'mruby-sprintf'
  spec.add_dependency 'mruby-errno'
  spec.add_test_dependency 'mruby-io'
  spec.add_test_dependency 'mruby-dir'
  spec.add_test_dependency 'mruby-fast-json'

  spec.cxx.include_paths << File.join(spec.dir, "vendor/toml11/include")

  spec.cxx.flags << "-std=c++17"
end
