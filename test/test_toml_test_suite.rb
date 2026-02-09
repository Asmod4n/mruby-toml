# test_toml_test_suite.rb

TEST_DIR = File.dirname(File.expand_path(__FILE__))
TOML_TEST_ROOT = File.join(TEST_DIR, "toml-test", "tests")
FILE_LIST = File.join(TOML_TEST_ROOT, "files-toml-1.1.0")

def with_temp_toml(name, content)
  path = File.join(TEST_DIR, name)
  File.open(path, "w") { |f| f.write(content) }
  begin
    yield path
  ensure
    File.delete(path) if File.exist?(path)
  end
end

def run_toml_test_file(path)
  content = File.read(path)
  with_temp_toml(File.basename(path), content) do |tmp|
    TOML.load(tmp)
  end
end

def expect_parse_ok(path)
    run_toml_test_file(path)
    true
end

def expect_parse_fail(path)
    run_toml_test_file(path)
end

assert("TOML-Test: files-toml-1.1.0") do
  lines = File.read(FILE_LIST).split("\n")

  lines.each do |rel|
    rel = rel.strip
    next if rel.empty?
    next if rel.end_with?(".json")   # skip semantic JSON files

    full = File.join(TOML_TEST_ROOT, rel)

    if rel.start_with?("valid/")
      assert_true expect_parse_ok(full)
    #elsif rel.start_with?("invalid/")
     # assert_raise(RuntimeError) { expect_parse_fail(full) }

    end
  end
end
