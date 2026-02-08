# mruby-toml
TOML for mruby (https://toml.io/)

A lightweight, standards-aligned TOML implementation for mruby.
Designed to feel natural in Ruby while staying fast, small, and compatible with the TOML 1.0 specification.

## Features
- TOML parsing and dumping
- Tables → `Hash`
- Arrays → `Array`
- Strings, integers, floats, booleans
- TOML date, time, and datetime values mapped to Ruby `Time` objects with TOML-aware metadata
- Round-trip safe: parsed values dump back to valid TOML
- Built on top of **[toml11](https://github.com/ToruNiina/toml11)**, a mature and well-tested MIT-licensed TOML library

## Usage
```ruby
cfg = TOML.load("config.toml")
puts cfg["server"]["port"]

cfg.dump("config_copy.toml")

TOML.dump({server: {addr: "127.0.0.1", port: 8080}}, "dump.toml")
```

## Installation
Add this gem to your `build_config.rb`:

```ruby
conf.gem github: "Asmod4n/mruby-toml"
```

## Acknowledgements
This project uses the excellent **toml11** library by Toru Niina,
licensed under the MIT License: https://github.com/ToruNiina/toml11
