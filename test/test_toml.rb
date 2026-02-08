# test_toml.rb

# Directory of this test file
TEST_DIR = File.dirname(File.expand_path(__FILE__))

# Write → yield → delete
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
  data = TOML.parse("a = 0")
  assert_equal 0, data["a"]

  data = TOML.parse("a = 42")
  assert_equal 42, data["a"]

  data = TOML.parse("a = -42")
  assert_equal(-42, data["a"])

  data = TOML.parse("a = 1_000_000")
  assert_equal 1000000, data["a"]
end

assert("TOML: floats") do
  data = TOML.parse("f = 3.14")
  assert_equal 3.14, data["f"]

  data = TOML.parse("f = -0.5")
  assert_equal(-0.5, data["f"])

  data = TOML.parse("f = 1e3")
  assert_equal 1000.0, data["f"]

  data = TOML.parse("f = 1_000.5")
  assert_equal 1000.5, data["f"]
end

assert("TOML: booleans") do
  data = TOML.parse("b = true")
  assert_equal true, data["b"]

  data = TOML.parse("b = false")
  assert_equal false, data["b"]
end

# -------------------------------------------------------------------
# 2. Arrays
# -------------------------------------------------------------------

assert("TOML: arrays basic") do
  data = TOML.parse("a = [1, 2, 3]")
  assert_equal [1,2,3], data["a"]

  data = TOML.parse('a = ["a", "b", "c"]')
  assert_equal ["a","b","c"], data["a"]
end

assert("TOML: arrays mixed") do
  data = TOML.parse('a = [1, "two", 3.0, true]')
  assert_equal [1, "two", 3.0, true], data["a"]
end

assert("TOML: nested arrays") do
  data = TOML.parse('a = [[1,2], [3,4]]')
  assert_equal [[1,2],[3,4]], data["a"]
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
  assert_equal 8080,        data["server"]["port"]
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
  assert_equal "apple",  fruits[0]["name"]
  assert_equal "red",    fruits[0]["color"]
  assert_equal "banana", fruits[1]["name"]
  assert_equal "yellow", fruits[1]["color"]
end

# -------------------------------------------------------------------
# 5. Date / Time / DateTime
# -------------------------------------------------------------------

assert("TOML: local date") do
  data = TOML.parse("d = 2024-01-02")
  d = data["d"]
  assert_equal TOML::Date, d.class
  assert_equal 2024, d.year
  assert_equal 1,    d.month
  assert_equal 2,    d.day
end

assert("TOML: local time") do
  data = TOML.parse("t = 12:34:56")
  t = data["t"]
  assert_equal TOML::Time, t.class
  assert_equal 12, t.hour
  assert_equal 34, t.min
  assert_equal 56, t.sec
end

assert("TOML: local datetime") do
  data = TOML.parse("dt = 2024-01-02T12:34:56")
  dt = data["dt"]
  assert_equal TOML::DateTime, dt.class
  assert_equal 2024, dt.year
  assert_equal 1,    dt.month
  assert_equal 2,    dt.day
  assert_equal 12,   dt.hour
  assert_equal 34,   dt.min
  assert_equal 56,   dt.sec
end

assert("TOML: offset datetime Z") do
  data = TOML.parse("z = 2024-01-02T12:34:56Z")
  z = data["z"]
  assert_equal TOML::DateTime, z.class
  assert_equal 0, z.utc_offset
end

assert("TOML: offset datetime +02:00") do
  data = TOML.parse("o = 2024-01-02T12:34:56+02:00")
  o = data["o"]
  assert_equal TOML::DateTime, o.class
  assert_equal 0, o.utc_offset
end

assert("TOML: offset datetime -05:30") do
  data = TOML.parse("o = 2024-01-02T12:34:56-05:30")
  o = data["o"]
  assert_equal TOML::DateTime, o.class
  assert_equal 0, o.utc_offset
end

# -------------------------------------------------------------------
# 6. Basic load + dump round-trip
# -------------------------------------------------------------------

assert("TOML: basic load") do
  with_temp_toml("basic.toml", <<~T) do |path|
    title = "Example"
    count = 42
    pi = 3.14
    active = true

    [server]
    host = "localhost"
    port = 8080

    nums = [1, 2, 3]
  T
    data = TOML.load(path)

    assert_equal "Example", data["title"]
    assert_equal 42,        data["count"]
    assert_equal 3.14,      data["pi"]
    assert_equal true,      data["active"]

    assert_equal "localhost", data["server"]["host"]
    assert_equal 8080,        data["server"]["port"]

    assert_equal [1,2,3], data["server"]["nums"]
  end
end

assert("TOML: dumping round-trip scalars") do
  h = { bool: true, int: 1, float: 1.0, str: "hello" }

  with_temp_toml("round_scalars.toml", "") do |path|
    TOML.dump(h, path)
    data = TOML.load(path)

    assert_equal true,    data["bool"]
    assert_equal 1,       data["int"]
    assert_equal 1.0,     data["float"]
    assert_equal "hello", data["str"]
  end
end

assert("TOML: dumping round-trip arrays") do
  h = { nums: [1,2,3], mix: [1,"two",3.0,true] }

  with_temp_toml("round_arrays.toml", "") do |path|
    TOML.dump(h, path)
    data = TOML.load(path)

    assert_equal [1,2,3], data["nums"]
    assert_equal [1,"two",3.0,true], data["mix"]
  end
end

assert("TOML: dumping round-trip Time (UTC, seconds only)") do
  now = Time.at(Time.now.to_i).utc
  h = { time: now }

  with_temp_toml("round_time.toml", "") do |path|
    TOML.dump(h, path)
    data = TOML.load(path)
    assert_equal now, data["time"]
  end
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
# 8. Many keys
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
    total_minutes = h * 60 + m
    offset_seconds = total_minutes * 60
    local - offset_seconds
  end

  cases = [
    [ 0,  0 ],
    [ 2,  0 ],
    [ 2, 30 ],
    [-5,  0 ],
    [-5, 30 ],
    [12, 59 ],
    [-12,59 ]
  ]

  cases.each do |h, m|
    toml = "dt = 2024-01-02T12:34:56#{format("%+03d:%02d", h, m)}"
    data = TOML.parse(toml)
    dt   = data["dt"]

    local = Time.utc(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec).to_i

    assert_equal 0, dt.utc_offset
    assert_equal expected_utc(local, h, m), local - ((h * 60 + m) * 60)
  end
end

# -------------------------------------------------------------------
# 10. Round-trip UTC normalization
# -------------------------------------------------------------------

assert("TOML: round‑trip DateTime always normalizes to UTC") do
  t_local = Time.local(2024, 1, 2, 12, 34, 56)
  t_utc   = t_local.getutc

  h = { dt: t_local }

  with_temp_toml("round_trip_datetime.toml", "") do |path|
    TOML.dump(h, path)
    data = TOML.load(path)
    dt = data["dt"]

    assert_equal(0, dt.utc_offset)
    assert_equal(t_utc.to_i, dt.to_i)
    assert_equal(t_local.to_i, dt.getlocal.to_i)
  end
end
