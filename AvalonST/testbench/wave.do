onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /avalonst_test_harness/clk
add wave -noupdate /avalonst_test_harness/nreset
add wave -noupdate /avalonst_test_harness/ready
add wave -noupdate /avalonst_test_harness/data
add wave -noupdate /avalonst_test_harness/valid
add wave -noupdate -expand -group dut /avalonst_test_harness/TestCtrl_2/io_trans_rec.Operation
add wave -noupdate -expand -group dut /avalonst_test_harness/TestCtrl_2/i_data
add wave -noupdate -expand -group dut /avalonst_test_harness/TestCtrl_2/o_ready
add wave -noupdate -expand -group dut /avalonst_test_harness/TestCtrl_2/i_valid
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {60177 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1000
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {32 ns}
