
#include ../../OsvvmLibraries.pro
TestSuite AvalonStream
include ../src/build.pro
include ../testbench/testbench.pro



SetCoverageAnalyzeEnable true
library osvvm_avalonst
RunTest AvalonStreamSendGetTest.vhd


RunTest AvalonStreamSendGetLatency.vhd
RunTest AvalonStreamReadyLatencyAllowance.vhd
RunTest AvalonStreamByteOrderSymbolWidth.vhd
RunTest AvalonStreamPacketTransport.vhd
RunTest AvalonStreamBeatsPerCycle.vhd
