
#include ../../OsvvmLibraries.pro
#include ../../Common/Common.pro
TestSuite AvalonStream
include ../src/build.pro
include ../testbench/testbench.pro



SetCoverageAnalyzeEnable true
library osvvm_avalonst




# set testname1 "AvalonStreamReadyLatencyAllowance"
# file copy -force "../sim/reports/AvalonStream/$testname1.fst" "../../../"
RunTest AvalonStreamSetOptions.vhd

