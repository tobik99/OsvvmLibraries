package require fileutil

set tb_name [lindex [split [env] '/'] 1]

# load regular wave.do if no matching file was found
if {[file exist "$vunit_tb_path/wave_${tb_name}.do"]} then {
    echo "loading custom wave.do for testbench $tb_name"
    do "$vunit_tb_path/wave_${tb_name}.do"
} else {
    echo "loading regular wave.do"
    do $vunit_tb_path/wave.do
}

# run the simulation
run -all
