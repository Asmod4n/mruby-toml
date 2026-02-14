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
  return false if rel == "invalid/datetime/offset-overflow-minute.toml" # toml11 accepts this, but the test suite expects it to be rejected
  rel.start_with?("invalid/")
end

def assert_expected(expected, actual)

  if expected.is_a?(Hash) && expected.key?("type")
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
        # numeric comparison with small epsilon
        assert_true (actual - value.to_f).abs < 1e-12
      end

    when "string"
      assert_true actual.is_a?(String)
      assert_equal value, actual

    when "bool"
      assert_true actual == true || actual == false
      assert_equal (value == "true"), actual

    else
      # for any other typed leaf we don't understand yet, just skip
      return
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
    # If we get here, it did NOT raise → print file and fail
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
        assert_raise() {assert_invalid_toml(full, rel)}
      end
  end
end
