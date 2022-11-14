require "test_helper"
require "minitest/mock"

class Tailwindcss::CommandsTest < ActiveSupport::TestCase
  setup do
    @orig_path = ENV["PATH"]
    ENV["PATH"] = ""
  end

  teardown do
    ENV["PATH"] = @orig_path
  end

  def mock_exe_directory(platform)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir(File.join(dir, platform))
      path = File.join(dir, platform, "tailwindcss")
      FileUtils.touch(path)
      Gem::Platform.stub(:match, true) do
        yield(dir, path)
      end
    end
  end

  def mock_path_binary(shim: false)
    Dir.mktmpdir do |dir|
      orig_path = ENV["PATH"]
      ENV["PATH"] = [dir, ENV["PATH"]].join(File::PATH_SEPARATOR)
      filepath = File.join(dir, "tailwindcss")
      FileUtils.touch(filepath)
      FileUtils.chmod("ugo+x", filepath)
      File.write(filepath, "#!/usr/bin/env ruby") if shim 
      yield(dir)
    ensure
      ENV["PATH"] = orig_path
    end
  end

  test ".platform is a string containing just the cpu and os (not the version)" do
    expected = "#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}"
    assert_equal(expected, Tailwindcss::Commands.platform)
  end

  test ".executable returns the absolute path to the binary" do
    mock_exe_directory("sparc-solaris2.8") do |dir, executable|
      expected = File.expand_path(File.join(dir, "sparc-solaris2.8", "tailwindcss"))
      assert_equal(expected, executable, "assert on setup")
      assert_equal(expected, Tailwindcss::Commands.executable(exe_path: dir))
    end
  end

  test "when a packaged exe is not found, .executable returns the absolute path to `tailwindcss` that is in PATH" do
    mock_path_binary do |installed|
      expected = File.join(installed, "tailwindcss")
      assert_equal(expected, Tailwindcss::Commands.executable(exe_path: "/blurgh"))
    end
  end

  test "when a packaged exe is not found, .executable ignores shims found in PATH" do
    mock_path_binary(shim: true) do |installed|
      assert_raises(Tailwindcss::Commands::ExecutableNotFoundException) do
        Tailwindcss::Commands.executable(exe_path: "/blurgh")
      end
    end
  end

  test "when a packaged exe is found, .executable ignores what's in PATH" do
    mock_exe_directory("sparc-solaris2.8") do |dir, executable|
      mock_path_binary do |installed|
        expected = File.expand_path(File.join(dir, "sparc-solaris2.8", "tailwindcss"))
        assert_equal(expected, executable, "assert on setup")
        assert_equal(expected, Tailwindcss::Commands.executable(exe_path: dir))
      end
    end
  end

  test ".executable raises UnsupportedPlatformException when we're not on a supported platform" do
    Gem::Platform.stub(:match, false) do # nothing is supported
      assert_raises(Tailwindcss::Commands::UnsupportedPlatformException) do
        Tailwindcss::Commands.executable
      end
    end
  end

  test ".executable raises ExecutableNotFoundException when we can't find the executable we expect" do
    Dir.mktmpdir do |dir| # empty directory
      assert_raises(Tailwindcss::Commands::ExecutableNotFoundException) do
        Tailwindcss::Commands.executable(exe_path: dir)
      end
    end
  end

  test ".compile_command" do
    mock_exe_directory("sparc-solaris2.8") do |dir, executable|
      Rails.stub(:root, File) do # Rails.root won't work in this test suite
        actual = Tailwindcss::Commands.compile_command(exe_path: dir)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        assert_includes(actual, "--minify")

        actual = Tailwindcss::Commands.compile_command(exe_path: dir, debug: true)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        refute_includes(actual, "--minify")
      end
    end
  end

  test ".watch_command" do
    mock_exe_directory("sparc-solaris2.8") do |dir, executable|
      Rails.stub(:root, File) do # Rails.root won't work in this test suite
        actual = Tailwindcss::Commands.watch_command(exe_path: dir)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        assert_includes(actual, "-w")
        refute_includes(actual, "-p")
        assert_includes(actual, "--minify")

        actual = Tailwindcss::Commands.watch_command(exe_path: dir, debug: true)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        assert_includes(actual, "-w")
        refute_includes(actual, "-p")
        refute_includes(actual, "--minify")

        actual = Tailwindcss::Commands.watch_command(exe_path: dir, poll: true)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        assert_includes(actual, "-w")
        assert_includes(actual, "-p")
        assert_includes(actual, "--minify")
      end
    end
  end
end
