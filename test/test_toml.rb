# test_toml.rb

TEST_DIR = File.dirname(File.expand_path(__FILE__))

def with_temp_toml(name, content)
  path = File.join(TEST_DIR, name)
  File.open(path, "w") { |f| f.write(content) }
  begin
    yield path
  ensure
    File.delete(path) if File.exist?(path)
  end
end

# -------------------------------------------------------------------
# 1. Scalars
# -------------------------------------------------------------------

assert("TOML: basic strings") do
  data = TOML.parse(%{s = "hello"})
  assert_equal "hello", data["s"]

  data = TOML.parse(%{s = ""})
  assert_equal "", data["s"]

  data = TOML.parse(%{s = "a\\nb"})
  assert_equal "a\nb", data["s"]

  data = TOML.parse(%{s = "C:\\\\path"})
  assert_equal "C:\\path", data["s"]

  data = TOML.parse(%{s = "quote: \\"inner\\"" })
  assert_equal 'quote: "inner"', data["s"]
end

assert("TOML: literal strings") do
  data = TOML.parse(%{s = 'raw text'})
  assert_equal "raw text", data["s"]

  data = TOML.parse(%{s = 'C:\\path\\raw'})
  assert_equal "C:\\path\\raw", data["s"]

  data = TOML.parse(%{s = ''})
  assert_equal "", data["s"]
end

assert("TOML: multiline basic strings") do
  data = TOML.parse(<<~T)
    s = """
    hello
    world
    """
  T
  assert_equal "hello\nworld\n", data["s"]
end

assert("TOML: multiline literal strings") do
  data = TOML.parse(<<~T)
    s = '''
    C:\\path\\raw
    literal
    '''
  T
  assert_equal "C:\\path\\raw\nliteral\n", data["s"]
end

assert("TOML: integers") do
  assert_equal 0, TOML.parse("a = 0")["a"]
  assert_equal 42, TOML.parse("a = 42")["a"]
  assert_equal(-42, TOML.parse("a = -42")["a"])
  assert_equal 1_000_000, TOML.parse("a = 1_000_000")["a"]
end

assert("TOML: floats") do
  assert_equal 3.14, TOML.parse("f = 3.14")["f"]
  assert_equal(-0.5, TOML.parse("f = -0.5")["f"])
  assert_equal 1000.0, TOML.parse("f = 1e3")["f"]
  assert_equal 1000.5, TOML.parse("f = 1_000.5")["f"]
end

assert("TOML: booleans") do
  assert_equal true, TOML.parse("b = true")["b"]
  assert_equal false, TOML.parse("b = false")["b"]
end

# -------------------------------------------------------------------
# 2. Arrays
# -------------------------------------------------------------------

assert("TOML: arrays basic") do
  assert_equal [1,2,3], TOML.parse("a = [1,2,3]")["a"]
  assert_equal ["a","b","c"], TOML.parse('a = ["a","b","c"]')["a"]
end

assert("TOML: arrays mixed") do
  assert_equal [1,"two",3.0,true], TOML.parse('a = [1,"two",3.0,true]')["a"]
end

assert("TOML: nested arrays") do
  assert_equal [[1,2],[3,4]], TOML.parse('a = [[1,2],[3,4]]')["a"]
end

assert("TOML: arrays multiline") do
  data = TOML.parse(<<~T)
    a = [
      1,
      2,
      3
    ]
  T
  assert_equal [1,2,3], data["a"]
end

# -------------------------------------------------------------------
# 3. Tables and dotted keys
# -------------------------------------------------------------------

assert("TOML: basic tables") do
  data = TOML.parse(<<~T)
    [server]
    host = "localhost"
    port = 8080
  T
  assert_equal "localhost", data["server"]["host"]
  assert_equal 8080, data["server"]["port"]
end

assert("TOML: nested tables") do
  data = TOML.parse(<<~T)
    [a]
    x = 1

    [a.b]
    y = 2

    [a.b.c]
    z = 3
  T
  assert_equal 1, data["a"]["x"]
  assert_equal 2, data["a"]["b"]["y"]
  assert_equal 3, data["a"]["b"]["c"]["z"]
end

assert("TOML: dotted keys") do
  data = TOML.parse(<<~T)
    a.b.c = 1
    a.b.d = 2
  T
  assert_equal 1, data["a"]["b"]["c"]
  assert_equal 2, data["a"]["b"]["d"]
end

assert("TOML: dotted keys vs tables equivalence") do
  d1 = TOML.parse(<<~T)
    [a.b]
    c = 1
  T

  d2 = TOML.parse(<<~T)
    a.b.c = 1
  T

  assert_equal d1["a"]["b"]["c"], d2["a"]["b"]["c"]
end

# -------------------------------------------------------------------
# 4. Array-of-tables
# -------------------------------------------------------------------

assert("TOML: array of tables basic") do
  data = TOML.parse(<<~T)
    [[fruit]]
    name = "apple"
    color = "red"

    [[fruit]]
    name = "banana"
    color = "yellow"
  T

  fruits = data["fruit"]
  assert_equal 2, fruits.size
  assert_equal "apple", fruits[0]["name"]
  assert_equal "red", fruits[0]["color"]
  assert_equal "banana", fruits[1]["name"]
  assert_equal "yellow", fruits[1]["color"]
end

# -------------------------------------------------------------------
# 5. Date / Time / DateTime
# -------------------------------------------------------------------

assert("TOML: local date") do
  d = TOML.parse("d = 2024-01-02")["d"]
  assert_equal 2024, d.year
  assert_equal 1, d.month
  assert_equal 2, d.day
end

assert("TOML: local time") do
  t = TOML.parse("t = 12:34:56")["t"]
  assert_equal 12, t.hour
  assert_equal 34, t.min
  assert_equal 56, t.sec
end

assert("TOML: local datetime") do
  dt = TOML.parse("dt = 2024-01-02T12:34:56")["dt"]
  assert_equal 2024, dt.year
  assert_equal 1, dt.month
  assert_equal 2, dt.day
  assert_equal 12, dt.hour
  assert_equal 34, dt.min
  assert_equal 56, dt.sec
end

assert("TOML: offset datetime Z") do
  z = TOML.parse("z = 2024-01-02T12:34:56Z")["z"]
  assert_equal 0, z.utc_offset
end

assert("TOML: offset datetime +02:00") do
  o = TOML.parse("o = 2024-01-02T12:34:56+02:00")["o"]
  assert_equal 0, o.utc_offset
end

assert("TOML: offset datetime -05:30") do
  o = TOML.parse("o = 2024-01-02T12:34:56-05:30")["o"]
  assert_equal 0, o.utc_offset
end

assert("TOML: parsed datetime objects carry @toml_type ivar") do
  ld  = TOML.parse("d = 2024-01-02")["d"]
  lt  = TOML.parse("t = 12:34:56")["t"]
  ldt = TOML.parse("dt = 2024-01-02T12:34:56")["dt"]
  odt = TOML.parse("o = 2024-01-02T12:34:56Z")["o"]

  assert_equal :local_date,      ld.toml_type
  assert_equal :local_time,      lt.toml_type
  assert_equal :local_datetime,  ldt.toml_type
  assert_equal :offset_datetime, odt.toml_type
end


# -------------------------------------------------------------------
# 6. Dumping round-trip (string-based)
# -------------------------------------------------------------------

assert("TOML: dumping round-trip scalars (string)") do
  h = { bool: true, int: 1, float: 1.0, str: "hello" }
  dumped = TOML.dump(h)
  data = TOML.parse(dumped)

  assert_equal true, data["bool"]
  assert_equal 1, data["int"]
  assert_equal 1.0, data["float"]
  assert_equal "hello", data["str"]
end

assert("TOML: dumping round-trip arrays (string)") do
  h = { nums: [1,2,3], mix: [1,"two",3.0,true] }
  dumped = TOML.dump(h)
  data = TOML.parse(dumped)

  assert_equal [1,2,3], data["nums"]
  assert_equal [1,"two",3.0,true], data["mix"]
end

assert("TOML: dumping round-trip Time (string)") do
  now = Time.at(Time.now.to_i).utc
  dumped = TOML.dump(time: now)
  data = TOML.parse(dumped)
  assert_equal now, data["time"]
end

assert("TOML: dumping preserves local_date") do
  d = TOML.parse("d = 2024-01-02")["d"]
  dumped = TOML.dump(d: d)
  parsed = TOML.parse(dumped)["d"]

  assert_equal :local_date, parsed.toml_type
  assert_equal d.year,  parsed.year
  assert_equal d.month, parsed.month
  assert_equal d.day,   parsed.day
end

assert("TOML: dumping preserves local_time") do
  t = TOML.parse("t = 12:34:56.789")["t"]
  dumped = TOML.dump(t: t)
  parsed = TOML.parse(dumped)["t"]

  assert_equal :local_time, parsed.toml_type
  assert_equal t.hour, parsed.hour
  assert_equal t.min,  parsed.min
  assert_equal t.sec,  parsed.sec
end

assert("TOML: dumping preserves local_datetime") do
  dt = TOML.parse("dt = 2024-01-02T12:34:56.123")["dt"]
  dumped = TOML.dump(dt: dt)
  parsed = TOML.parse(dumped)["dt"]

  assert_equal :local_datetime, parsed.toml_type
  assert_equal dt.to_i, parsed.to_i
end

assert("TOML: dumping preserves offset_datetime") do
  odt = TOML.parse("o = 2024-01-02T12:34:56+02:00")["o"]
  dumped = TOML.dump(o: odt)
  parsed = TOML.parse(dumped)["o"]

  assert_equal :offset_datetime, parsed.toml_type
  assert_equal odt.to_i, parsed.to_i
end


# -------------------------------------------------------------------
# 7. Error handling
# -------------------------------------------------------------------

assert("TOML: invalid integer") do
  assert_raise { TOML.parse("a = 1_") }
end

assert("TOML: invalid date") do
  assert_raise { TOML.parse("d = 2024-13-01") }
end

assert("TOML: invalid time") do
  assert_raise { TOML.parse("t = 25:00:00") }
end

assert("TOML: duplicate keys") do
  assert_raise { TOML.parse("a = 1\na = 2") }
end

assert("TOML: invalid table redefinition") do
  assert_raise { TOML.parse("[a]\n[b]\n[a]\n") }
end

# -------------------------------------------------------------------
# 8. Many keys (file-based)
# -------------------------------------------------------------------

assert("TOML: many keys") do
  content = (0...100).map { |i| "k#{i} = #{i}" }.join("\n")

  with_temp_toml("many_keys.toml", content) do |path|
    data = TOML.load(path)
    100.times { |i| assert_equal i, data["k#{i}"] }
  end
end

# -------------------------------------------------------------------
# 9. Offset datetime math correctness
# -------------------------------------------------------------------

assert("TOML: offset datetime UTC conversion") do
  def expected_utc(local, h, m)
    local - ((h * 60 + m) * 60)
  end

  cases = [
    [ 2,  0 ],
    [ 2, 30 ],
    [-5,  0 ],
    [-5, 30 ],
    [12, 59 ],
    [-12,59 ]
  ]

  cases.each do |h, m|
    toml = "dt = 2024-01-02T12:34:56#{format("%+03d:%02d", h, m)}"
    dt = TOML.parse(toml)["dt"]

    local = Time.utc(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec).to_i

    assert_equal 0, dt.utc_offset
    assert_equal expected_utc(local, h, m), local - ((h * 60 + m) * 60)
  end
end

# -------------------------------------------------------------------
# 10. Round-trip UTC normalization
# -------------------------------------------------------------------

assert("TOML: round-trip DateTime preserves instant and local representation") do
  t_local = Time.local(2024, 1, 2, 12, 34, 56)

  dumped = TOML.dump(dt: t_local)
  dt = TOML.parse(dumped)["dt"]

  # Parsed Time is UTC by design
  assert_equal 0, dt.utc_offset

  # Same instant
  assert_equal t_local.to_i, dt.to_i

  # Convert back to local for wall-clock comparison
  dt_local = dt.getlocal

  assert_equal t_local.utc_offset, dt_local.utc_offset
  assert_equal t_local.to_i, dt_local.to_i
end
