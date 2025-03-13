#  File Name:         TestAvalonST.pro
#  Revision:          OSVVM MODELS STANDARD VERSION
#
#  Maintainer:        Jim Lewis      email:  jim@synthworks.com
#  Contributor(s):
#     Jim Lewis      jim@synthworks.com
#
#
#  Description:
#        Script to run AvalonST testbench
#
#  Developed for:
#        SynthWorks Design Inc.
#        VHDL Training Classes
#        11898 SW 128th Ave.  Tigard, Or  97223
#        http://www.SynthWorks.com
#
#  Revision History:
#    Date      Version    Description
#     3/2025   2025.03    Initial version for AvalonST testbench
#
#
#  This file is part of OSVVM.
#  
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#  
#      https://www.apache.org/licenses/LICENSE-2.0
#  
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#  
build /home/tobi/repos/OsvvmLibraries

library osvvm_avalonst

analyze /home/tobi/repos/OsvvmLibraries/AvalonST/src/AvalonST_context.vhd
analyze /home/tobi/repos/OsvvmLibraries/AvalonST/src/AvalonST_source_component_pkg.vhd
analyze /home/tobi/repos/OsvvmLibraries/AvalonST/src/AvalonSt_test_common_pkg.vhd
analyze /home/tobi/repos/OsvvmLibraries/AvalonST/src/AvalonST_source.vhd
analyze /home/tobi/repos/OsvvmLibraries/AvalonST/testbench/AvalonST_TestCtrl_e.vhd
analyze /home/tobi/repos/OsvvmLibraries/AvalonST/testbench/AvalonST_SendTest_a.vhd
analyze /home/tobi/repos/OsvvmLibraries/AvalonST/testbench/AvalonSt_TestHarness.vhd

RunTest AvalonST_test_harness