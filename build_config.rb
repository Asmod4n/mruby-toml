MRuby::Build.new do |conf|
  toolchain :gcc
  enable_debug
  conf.enable_debug
  #conf.enable_sanitizer "address,undefined,leak"
  conf.enable_test
  conf.cc.defines  << 'MRB_UTF8_STRING'
  conf.cxx.defines << 'MRB_UTF8_STRING'
  conf.gem :core => "mruby-bin-mirb"
  conf.gem File.expand_path(File.dirname(__FILE__))
  conf.gem github: 'Asmod4n/mruby-fast-json', branch: 'main'
end
