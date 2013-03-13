require 'test/unit'

$VERBOSE = true
require "#{File.dirname File.dirname(__FILE__)}/lib/memory-profiler"
class Test_memory_profiler < Test::Unit::TestCase
	def test_memory_profiler
		assert_nothing_raised { MemoryProfiler.start_daemon }
		assert_nothing_raised { MemoryProfiler.stop_daemon }
		assert_nothing_raised { MemoryProfiler.start }
		assert_raise(RuntimeError) { MemoryProfiler.start }
		assert_nothing_raised { MemoryProfiler.restart }
		assert_nothing_raised { MemoryProfiler.stop }
		assert_raise(RuntimeError) { MemoryProfiler.restart }
		assert_raise(RuntimeError) { MemoryProfiler.stop }
	end
end

