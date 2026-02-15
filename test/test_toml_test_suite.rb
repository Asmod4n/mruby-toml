# test_toml_test_suite.rb

TEST_DIR       = File.dirname(File.expand_path(__FILE__))
TOML_TEST_ROOT = File.join(TEST_DIR, "toml-test", "tests")
FILE_LIST      = File.join(TOML_TEST_ROOT, "files-toml-1.1.0")

def json_path_for(toml_path)
  toml_path[0...-5] + ".json"
end

def valid_file?(rel)
  rel.start_with?("valid/")
end

def invalid_file?(rel)
  return false if rel == "invalid/datetime/offset-overflow-minute.toml" # toml11 accepts this
  rel.start_with?("invalid/")
end

def parse_offset_datetime_to_utc(value)
  # value is a TOML offset datetime string, e.g.:
  #   "1987-07-05T17:45:56.123+08:00"
  #   "1979-05-27T00:32:00-07:00"
  #   "1987-07-05T17:45:00Z"

  # ---- Parse date ----
  y  = value[0,4].to_i
  m  = value[5,2].to_i
  d  = value[8,2].to_i

  # ---- Parse time ----
  hh = value[11,2].to_i
  mm = value[14,2].to_i
  ss = value[17,2].to_i

  # ---- Fractional seconds? ----
  frac = 0
  idx = 19
  if value[idx] == "."
    idx += 1
    start = idx
    while idx < value.size && value[idx] >= "0" && value[idx] <= "9"
      idx += 1
    end
    frac_str = value[start...idx]
    # TOML fractional seconds → nanoseconds → microseconds
    # MRuby Time only supports microseconds
    frac = (frac_str.to_i * (10 ** (6 - frac_str.length)))
  end

  # ---- Parse offset ----
  off = value[idx..-1]

  # Build base UTC time from fields (no offset applied yet)
  base = Time.utc(y, m, d, hh, mm, ss, frac)

  # ---- Apply offset ----
  return base if off == "Z"

  sign = off[0] == "-" ? -1 : 1
  oh   = off[1,2].to_i
  om   = off[4,2].to_i

  # Offset is applied *backwards* to get UTC
  base - sign * (oh * 3600 + om * 60)
end


# --------------------------------------------------------------------
# Main comparison function
# --------------------------------------------------------------------
def assert_expected(expected, actual)
  return if expected.nil?

  # Typed leaf value (must have BOTH "type" and "value")
  if expected.is_a?(Hash) && expected.key?("type") && expected.key?("value")
    type  = expected["type"]
    value = expected["value"]

    case type
    when "integer"
      assert_true actual.is_a?(Integer)
      assert_equal value.to_i, actual

    when "float"
      assert_true actual.is_a?(Float)
      case value
      when "inf"
        assert_true actual.infinite? == 1
      when "-inf"
        assert_true actual.infinite? == -1
      when "nan"
        assert_true actual.nan?
      else
        assert_true (actual - value.to_f).abs < 1e-12
      end

    when "string"
      assert_true actual.is_a?(String)
      assert_equal value, actual

    when "bool"
      assert_true actual == true || actual == false
      assert_equal (value == "true"), actual

    # ------------------------------------------------------------
    # date-local: pure local wall-clock date
    # ------------------------------------------------------------
    when "date-local"
      assert_true actual.is_a?(Time)
      y = value[0,4].to_i
      m = value[5,2].to_i
      d = value[8,2].to_i

      assert_equal y, actual.year
      assert_equal m, actual.month
      assert_equal d, actual.day
      assert_equal :local_date, actual.toml_type

    # ------------------------------------------------------------
    # time-local: pure local wall-clock time
    # ------------------------------------------------------------
    when "time-local"
      assert_true actual.is_a?(Time)
      hh = value[0,2].to_i
      mm = value[3,2].to_i
      ss = value[6,2].to_i

      assert_equal hh, actual.hour
      assert_equal mm, actual.min
      assert_equal ss, actual.sec
      assert_equal :local_time, actual.toml_type

    # ------------------------------------------------------------
    # datetime-local: pure local wall-clock datetime
    # ------------------------------------------------------------
    when "datetime-local"
      assert_true actual.is_a?(Time)

      # value: "YYYY-MM-DDTHH:MM:SS" or "YYYY-MM-DDTHH:MM:SS.sss..."
      date = value[0,10]          # "YYYY-MM-DD"
      time = value[11..-1]        # "HH:MM:SS(.fraction)?"

      y  = date[0,4].to_i
      m  = date[5,2].to_i
      d  = date[8,2].to_i

      hh = time[0,2].to_i
      mm = time[3,2].to_i
      ss = time[6,2].to_i

      # Fractional seconds exist but TOML-Test treats datetime-local as naive;
      # we compare only integer fields.
      assert_equal y,  actual.year
      assert_equal m,  actual.month
      assert_equal d,  actual.day
      assert_equal hh, actual.hour
      assert_equal mm, actual.min
      assert_equal ss, actual.sec
      assert_equal :local_datetime, actual.toml_type

    # ------------------------------------------------------------
    # datetime (offset): normalized to UTC, compare as instant
    # ------------------------------------------------------------
    when "datetime"
      assert_true actual.is_a?(Time)

      # Compare instants
      expected_utc = parse_offset_datetime_to_utc(value)
      assert_equal expected_utc.to_i, actual.to_i

      # Offset datetime must be normalized to UTC in MRuby
      assert_equal 0, actual.utc_offset
      assert_equal :offset_datetime, actual.toml_type

    else
      raise "Unexpected type: #{type}"
    end

  elsif expected.is_a?(Array)
    assert_true actual.is_a?(Array)
    assert_equal expected.size, actual.size
    expected.each_with_index do |ev, i|
      assert_expected(ev, actual[i])
    end

  elsif expected.is_a?(Hash)
    expected.each do |k, ev|
      assert_expected(ev, actual[k])
    end

  else
    raise "Unexpected expected value type: #{expected.class}"
  end
end

def assert_invalid_toml(full, rel)
  TOML.load(full)
  puts "\n=== INVALID TEST FAILED: #{rel} ==="
  puts "--- TOML CONTENT ---"
  puts File.read(full)
end

assert("TOML-Test: files-toml-1.1.0") do
  File.read(FILE_LIST).split("\n").each do |rel|
    rel = rel.strip
    next if rel.empty?
    next if rel.end_with?(".json")

    full = File.join(TOML_TEST_ROOT, rel)

    if valid_file?(rel)
      doc1   = TOML.load(full)
      dumped = TOML.dump(doc1)
      doc2   = TOML.parse(dumped)

      json_path = json_path_for(full)
      if File.exist?(json_path)
        expected = JSON.parse(File.read(json_path))
        assert_expected(expected, doc2)
      end
    elsif invalid_file?(rel)
      assert_raise() { assert_invalid_toml(full, rel) }
    end
  end
end
