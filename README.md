mruby-toml
==========

TOML for mruby

Features:
- TOML parsing and dumping
- Tables -> Hash
- Arrays -> Array
- Strings, ints, floats, bools
- TOML date, time or datetime -> mruby TOML::Date, TOML::Time and TOML::DateTime.

Usage:
```ruby
  cfg = TOML.load("config.toml")
  puts cfg["server"]["port"]
  cfg.dump("config_copy.toml")
  TOML.dump({server: {addr: "127.0.0.1", port: 8080}}, "dump.toml")
```
Installation:

Add this gem to your build_config.rb:

  conf.gem :github => "Asmod4n/mruby-toml"
