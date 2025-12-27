note
	description: "Test application for SIMPLE_AUDIO"
	author: "Larry Rix"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the tests.
		do
			print ("Running SIMPLE_AUDIO tests...%N%N")
			passed := 0
			failed := 0

			run_lib_tests

			print ("%N========================%N")
			print ("Results: " + passed.out + " passed, " + failed.out + " failed%N")

			if failed > 0 then
				print ("TESTS FAILED%N")
			else
				print ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Test Runners

	run_lib_tests
		do
			create lib_tests
			run_test (agent lib_tests.test_initialization, "test_initialization")
			run_test (agent lib_tests.test_output_device_enumeration, "test_output_device_enumeration")
			run_test (agent lib_tests.test_input_device_enumeration, "test_input_device_enumeration")
			run_test (agent lib_tests.test_default_output_device, "test_default_output_device")
			run_test (agent lib_tests.test_default_input_device, "test_default_input_device")
			run_test (agent lib_tests.test_device_properties, "test_device_properties")
			run_test (agent lib_tests.test_device_count, "test_device_count")
			run_test (agent lib_tests.test_refresh, "test_refresh")
			run_test (agent lib_tests.test_buffer_creation, "test_buffer_creation")
			run_test (agent lib_tests.test_buffer_8bit, "test_buffer_8bit")
			run_test (agent lib_tests.test_buffer_24bit, "test_buffer_24bit")
			run_test (agent lib_tests.test_buffer_32bit, "test_buffer_32bit")
			run_test (agent lib_tests.test_buffer_sample_access, "test_buffer_sample_access")
			run_test (agent lib_tests.test_buffer_clear, "test_buffer_clear")
			run_test (agent lib_tests.test_buffer_sine_wave, "test_buffer_sine_wave")
			run_test (agent lib_tests.test_empty_device, "test_empty_device")
			run_test (agent lib_tests.test_empty_buffer, "test_empty_buffer")
		end

feature {NONE} -- Test Infrastructure

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test.
		local
			l_failed: BOOLEAN
		do
			if not l_failed then
				a_test.call (Void)
				passed := passed + 1
				print ("[PASS] " + a_name + "%N")
			end
		rescue
			l_failed := True
			failed := failed + 1
			print ("[FAIL] " + a_name + "%N")
			retry
		end

	passed: INTEGER
	failed: INTEGER

feature {NONE} -- Test Objects

	lib_tests: LIB_TESTS

end
