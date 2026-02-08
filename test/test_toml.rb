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

# Convenience for inline TOML
def toml_from_string(name, content)
  with_temp_toml("#{name}.toml", content) do |path|
    TOML.load(path)
  end
end

# -------------------------------------------------------------------
# 1. Scalars
# -------------------------------------------------------------------

assert("TOML: basic strings") do
  data = toml_from_string("basic_strings_1", %{s = "hello"})
  assert_equal "hello", data["s"]

  data = toml_from_string("basic_strings_2", %{s = ""})
  assert_equal "", data["s"]

  data = toml_from_string("basic_strings_3", %{s = "a\\nb"})
  assert_equal "a\nb", data["s"]

  data = toml_from_string("basic_strings_4", %{s = "C:\\\\path"})
  assert_equal "C:\\path", data["s"]

  data = toml_from_string("basic_strings_5", %{s = "quote: \\"inner\\"" })
  assert_equal 'quote: "inner"', data["s"]
end

assert("TOML: literal strings") do
  data = toml_from_string("literal_strings_1", %{s = 'raw text'})
  assert_equal "raw text", data["s"]

  data = toml_from_string("literal_strings_2", %{s = 'C:\\path\\raw'})
  assert_equal "C:\\path\\raw", data["s"]

  data = toml_from_string("literal_strings_3", %{s = ''})
  assert_equal "", data["s"]
end

assert("TOML: multiline basic strings") do
  with_temp_toml("multi_basic.toml", <<~T) do |path|
    s = """
    hello
    world
    """
  T
    data = TOML.load(path)
    assert_equal "hello\nworld\n", data["s"]
  end
end

assert("TOML: multiline literal strings") do
  with_temp_toml("multi_lit.toml", <<~T) do |path|
    s = '''
    C:\\path\\raw
    literal
    '''
  T
    data = TOML.load(path)
    assert_equal "C:\\path\\raw\nliteral\n", data["s"]
  end
end

assert("TOML: integers") do
  data = toml_from_string("ints_0", "a = 0")
  assert_equal 0, data["a"]

  data = toml_from_string("ints_1", "a = 42")
  assert_equal 42, data["a"]

  data = toml_from_string("ints_2", "a = -42")
  assert_equal(-42, data["a"])

  data = toml_from_string("ints_3", "a = 1_000_000")
  assert_equal 1000000, data["a"]
end

assert("TOML: floats") do
  data = toml_from_string("floats_1", "f = 3.14")
  assert_equal 3.14, data["f"]

  data = toml_from_string("floats_2", "f = -0.5")
  assert_equal(-0.5, data["f"])

  data = toml_from_string("floats_3", "f = 1e3")
  assert_equal 1000.0, data["f"]

  data = toml_from_string("floats_4", "f = 1_000.5")
  assert_equal 1000.5, data["f"]
end

assert("TOML: booleans") do
  data = toml_from_string("bools_1", "b = true")
  assert_equal true, data["b"]

  data = toml_from_string("bools_2", "b = false")
  assert_equal false, data["b"]
end

# -------------------------------------------------------------------
# 2. Arrays
# -------------------------------------------------------------------

assert("TOML: arrays basic") do
  data = toml_from_string("arrays_basic_1", "a = [1, 2, 3]")
  assert_equal [1,2,3], data["a"]

  data = toml_from_string("arrays_basic_2", 'a = ["a", "b", "c"]')
  assert_equal ["a","b","c"], data["a"]
end

assert("TOML: arrays mixed") do
  data = toml_from_string("arrays_mixed", 'a = [1, "two", 3.0, true]')
  assert_equal [1, "two", 3.0, true], data["a"]
end

assert("TOML: nested arrays") do
  data = toml_from_string("arrays_nested", 'a = [[1,2], [3,4]]')
  assert_equal [[1,2],[3,4]], data["a"]
end

assert("TOML: arrays multiline") do
  with_temp_toml("array_multi.toml", <<~T) do |path|
    a = [
      1,
      2,
      3
    ]
  T
    data = TOML.load(path)
    assert_equal [1,2,3], data["a"]
  end
end

# -------------------------------------------------------------------
# 3. Tables and dotted keys
# -------------------------------------------------------------------

assert("TOML: basic tables") do
  with_temp_toml("basic_tables.toml", <<~T) do |path|
    [server]
    host = "localhost"
    port = 8080
  T
    data = TOML.load(path)
    assert_equal "localhost", data["server"]["host"]
    assert_equal 8080,        data["server"]["port"]
  end
end

assert("TOML: nested tables") do
  with_temp_toml("nested_tables.toml", <<~T) do |path|
    [a]
    x = 1

    [a.b]
    y = 2

    [a.b.c]
    z = 3
  T
    data = TOML.load(path)
    assert_equal 1, data["a"]["x"]
    assert_equal 2, data["a"]["b"]["y"]
    assert_equal 3, data["a"]["b"]["c"]["z"]
  end
end

assert("TOML: dotted keys") do
  with_temp_toml("dotted_keys.toml", <<~T) do |path|
    a.b.c = 1
    a.b.d = 2
  T
    data = TOML.load(path)
    assert_equal 1, data["a"]["b"]["c"]
    assert_equal 2, data["a"]["b"]["d"]
  end
end

assert("TOML: dotted keys vs tables equivalence") do
  with_temp_toml("dotted_vs_tables_1.toml", <<~T) do |path1|
    [a.b]
    c = 1
  T
    with_temp_toml("dotted_vs_tables_2.toml", <<~T) do |path2|
      a.b.c = 1
    T
      d1 = TOML.load(path1)
      d2 = TOML.load(path2)
      assert_equal d1["a"]["b"]["c"], d2["a"]["b"]["c"]
    end
  end
end

# -------------------------------------------------------------------
# 4. Array-of-tables
# -------------------------------------------------------------------

assert("TOML: array of tables basic") do
  with_temp_toml("aot.toml", <<~T) do |path|
    [[fruit]]
    name = "apple"
    color = "red"

    [[fruit]]
    name = "banana"
    color = "yellow"
  T
    data = TOML.load(path)
    fruits = data["fruit"]
    assert_equal 2, fruits.size
    assert_equal "apple",  fruits[0]["name"]
    assert_equal "red",    fruits[0]["color"]
    assert_equal "banana", fruits[1]["name"]
    assert_equal "yellow", fruits[1]["color"]
  end
end

# -------------------------------------------------------------------
# 5. Date / Time / DateTime
# -------------------------------------------------------------------

assert("TOML: local date") do
  data = toml_from_string("local_date", "d = 2024-01-02")
  d = data["d"]
  assert_equal TOML::Date, d.class
  assert_equal 2024, d.year
  assert_equal 1,    d.month
  assert_equal 2,    d.day
end

assert("TOML: local time") do
  data = toml_from_string("local_time", "t = 12:34:56")
  t = data["t"]
  assert_equal TOML::Time, t.class
  assert_equal 12, t.hour
  assert_equal 34, t.min
  assert_equal 56, t.sec
end

assert("TOML: local datetime") do
  data = toml_from_string("local_datetime", "dt = 2024-01-02T12:34:56")
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
  data = toml_from_string("offset_z", "z = 2024-01-02T12:34:56Z")
  z = data["z"]
  assert_equal TOML::DateTime, z.class
  assert_equal 0, z.utc_offset
end

assert("TOML: offset datetime +02:00") do
  data = toml_from_string("offset_plus_2", "o = 2024-01-02T12:34:56+02:00")
  o = data["o"]
  assert_equal TOML::DateTime, o.class
  assert_equal 0, o.utc_offset
end

assert("TOML: offset datetime -05:30") do
  data = toml_from_string("offset_minus_530", "o = 2024-01-02T12:34:56-05:30")
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
  begin
    toml_from_string("invalid_int", "a = 1_")
    assert(false)
  rescue
    assert_true true
  end
end

assert("TOML: invalid date") do
  begin
    toml_from_string("invalid_date", "d = 2024-13-01")
    assert(false)
  rescue
    assert_true true
  end
end

assert("TOML: invalid time") do
  begin
    toml_from_string("invalid_time", "t = 25:00:00")
    assert(false)
  rescue
    assert_true true
  end
end

assert("TOML: duplicate keys") do
  begin
    toml_from_string("dup_keys", "a = 1\na = 2")
    assert(false)
  rescue
    assert_true true
  end
end

assert("TOML: invalid table redefinition") do
  begin
    toml_from_string("bad_tables", "[a]\n[b]\n[a]\n")
    assert(false)
  rescue
    assert_true true
  end
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

assert("TOML: offset datetime UTC conversion") do
  # Helper: compute expected UTC from hour/minute offset
  def expected_utc(local, h, m)
    total_minutes = h * 60 + m
    offset_seconds = total_minutes * 60
    local - offset_seconds
  end

  # Table of test cases: [offset hour, offset minute]
  cases = [
    [ 0,   0   ],
    [ 2,   0   ],
    [ 2,  30   ],
    [-5,   0   ],
    [-5, 30   ],
    [12,  59   ],
    [-12, 59  ]
  ]

  cases.each do |h, m|
    toml = "dt = 2024-01-02T12:34:56#{format("%+03d:%02d", h, m)}"
    data = toml_from_string("offset_case_#{h}_#{m}", toml)
    dt   = data["dt"]

    # Local timestamp (as seconds)
    local = Time.utc(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec).to_i

    # The parser should already have applied the offset, so dt.utc_offset == 0
    assert_equal 0, dt.utc_offset

    # Now verify the math:
    assert_equal expected_utc(local, h, m), local - ((h * 60 + m) * 60)
  end
end

assert("TOML: round‑trip DateTime always normalizes to UTC") do
  # Create a local time that is definitely NOT UTC
  t_local = Time.local(2024, 1, 2, 12, 34, 56)

  # Convert to UTC for comparison
  t_utc = t_local.getutc

  h = { dt: t_local }

  with_temp_toml("round_trip_datetime.toml", "") do |path|
    # Dump MRuby → TOML (always UTC)
    TOML.dump(h, path)

    # Load TOML → MRuby (respect offset, convert to UTC)
    data = TOML.load(path)
    dt = data["dt"]

    # Loaded value must be UTC
    assert_equal(0, dt.utc_offset)

    # Must represent the same instant in time
    assert_equal(t_utc.to_i, dt.to_i)

    # And converting back to local must match original local time
    assert_equal(t_local.to_i, dt.getlocal.to_i)
  end
end
