
#include ../../OsvvmLibraries.pro
include ../../Common/Common.pro
TestSuite AvalonStream
include ../src/build.pro
include ../testbench/testbench.pro



SetCoverageAnalyzeEnable true
library osvvm_avalonst
RunTest AvalonStreamSendGetTest.vhd


RunTest AvalonStreamReadyLatencyAllowance.vhd
# set testname1 "AvalonStreamReadyLatencyAllowance"
# file copy -force "../sim/reports/AvalonStream/$testname1.fst" "../../../"
RunTest AvalonStreamPacketTransport.vhd
RunTest AvalonStreamSetOptions.vhd
RunTest AvalonStreamSendGetTest.vhd
RunTest AvalonStreamBeatsPerCycle.vhd
