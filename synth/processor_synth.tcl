
###############################################################################
# Options for the user
###############################################################################

set clk_period 5
set in_delay_max 45
set in_delay_min 10
set out_delay_max 20 
set out_delay_min 10 

# Options:  CCS, ECSM, NLDM or Functional
set nangate_library_name "CCS"

###############################################################################
## SUPER THREADING
###############################################################################

set_db super_thread_servers "localhost"
set_db max_cpus_per_server 8

# set_db hdl_vhdl_read_version 2008

###############################################################################
## VARIABLE DEFINITIONS
###############################################################################

set reportdir ./reports
set netlistdir ./netlists

set NANGATE15_HOME $::env(NANGATE15_HOME)
set nangate15 $NANGATE15_HOME/front_end/timing_power_noise
set lefnangate15 $NANGATE15_HOME/back_end/lef

set techlef $lefnangate15/NanGate_15nm_OCL.tech.lef
set macrolef $lefnangate15/NanGate_15nm_OCL.macro.lef

set filelists ./lists

set RTL_HOME $::env(RTL_HOME)
set PRJ_ROOT $::env(PRJ_ROOT)

# CCS liberty libraries
set ccs_fast_conditional $nangate15/CCS/NanGate_15nm_OCL_fast_conditional_ccs.lib
set ccs_low_temp_conditional $nangate15/CCS/NanGate_15nm_OCL_low_temp_conditional_ccs.lib
set ccs_slow_conditional $nangate15/CCS/NanGate_15nm_OCL_slow_conditional_ccs.lib
set ccs_typical_conditional $nangate15/CCS/NanGate_15nm_OCL_typical_conditional_ccs.lib
set ccs_worst_low_conditional $nangate15/CCS/NanGate_15nm_OCL_worst_low_conditional_ccs.lib

# ECSM liberty libraries
set ecsm_fast_conditional $nangate15/ECSM/NanGate_15nm_OCL_fast_conditional_ecsm.lib
set ecsm_low_temp_conditional $nangate15/ECSM/NanGate_15nm_OCL_low_temp_conditional_ecsm.lib
set ecsm_slow_conditional $nangate15/ECSM/NanGate_15nm_OCL_slow_conditional_ecsm.lib
set ecsm_typical_conditional $nangate15/ECSM/NanGate_15nm_OCL_typical_conditional_ecsm.lib
set ecsm_worst_low_conditional $nangate15/ECSM/NanGate_15nm_OCL_worst_low_conditional_ecsm.lib

# NLDM liberty libraries
set nldm_fast_conditional $nangate15/NLDM/NanGate_15nm_OCL_fast_conditional_nldm.lib
set nldm_low_temp_conditional $nangate15/NLDM/NanGate_15nm_OCL_low_temp_conditional_nldm.lib
set nldm_slow_conditional $nangate15/NLDM/NanGate_15nm_OCL_slow_conditional_nldm.lib
set nldm_typical_conditional $nangate15/NLDM/NanGate_15nm_OCL_typical_conditional_nldm.lib
set nldm_worst_low_conditional $nangate15/NLDM/NanGate_15nm_OCL_worst_low_conditional_nldm.lib

# functional liberty file
set functional_lib  $nangate15/NanGate_15nm_OCL_functional.lib

set in_conv_delay_max  [expr {double($in_delay_max)/100 * $clk_period}]
set in_conv_delay_min  [expr {double($in_delay_min)/100 * $clk_period}]
set out_conv_delay_max [expr {double($out_delay_max)/100 * $clk_period}]
set out_conv_delay_min [expr {double($out_delay_min)/100 * $clk_period}]

puts "clk period set: $clk_period"
puts "input max delay: $in_conv_delay_max"
puts "input min delay: $in_conv_delay_min"
puts "output max delay: $out_conv_delay_max"
puts "output min delay: $out_conv_delay_min"

###############################################################################
## SET CFGs
###############################################################################

set_db lp_power_analysis_effort high                                                                                    
set_db lp_power_unit uW                                                                                           
set_db hdl_track_filename_row_col true                                                                                  
set_db information_level 2

# set lib search path
set_db init_lib_search_path $nangate15/$nangate_library_name
set_db lef_library  "$macrolef $techlef" 

set_db init_hdl_search_path $RTL_HOME

if {[string match "CCS" $nangate_library_name]} {
    puts "CCS lib choosen"
    set_db library $ccs_typical_conditional 
} else {
    if {[string match "ECSM" $nangate_library_name]} {
        puts "ECSM lib choosen"
        set_db library $ecsm_typical_conditional 
    } else {
        if {[string match "NLDM" $nangate_library_name]} {
            puts "NLDM lib choosen"
            set_db library $nldm_typical_conditional 
        } else {
            puts "Functional lib choosen"
            set_db library $functional_lib 
        }
    }
}

# read the RTL design
read_hdl -f $filelists/vlog.f
read_hdl -language vhdl -library commonlib -f $filelists/commonlib.f
read_hdl -language vhdl -library ambalib   -f $filelists/ambalib.f
read_hdl -language vhdl -library techmap   -f $filelists/techmap.f
read_hdl -language vhdl -library ethlib    -f $filelists/ethlib.f
read_hdl -language vhdl -library misclib   -f $filelists/misclib.f
read_hdl -language vhdl -library riverlib  -f $filelists/riverlib.f
read_hdl -language vhdl -library gnsslib   -f $filelists/gnsslib.f
read_hdl -language vhdl -library work      -f $filelists/vhdl.f

# elaborate the design
elaborate Processor -parameters { {hartid 0} {async_reset false} {fpu_ena true} {tracer_ena false} }

###############################################################################
## APPLY CONSTRAINTS
###############################################################################

create_clock -name i_clk -period $clk_period [get_ports i_clk]
set_output_delay -clock i_clk -max $in_conv_delay_max [get_ports o_*]
set_output_delay -clock i_clk -min $in_conv_delay_min [get_ports o_*]
set_input_delay -clock i_clk -max $out_conv_delay_max [get_ports i_*]
set_input_delay -clock i_clk -min $out_conv_delay_min [get_ports i_*]

###############################################################################
## SYNTHESIS
###############################################################################
# generic synthesys
syn_generic

# generic mapping
syn_map

if {[string match "CCS" $nangate_library_name]} {
    set processor_name "processor.ccs"
    # write_hdl ProcessorNanGate15 > $netlistdir/processor.ccs.netlist.v
} else {
    if {[string match "ECSM" $nangate_library_name]} {
        set processor_name "processor.ecsm"
        # write_hdl ProcessorNanGate15 > $netlistdir/processor.ecsm.netlist.v
    } else {
        if {[string match "NLDM" $nangate_library_name]} {
            set processor_name "processor.nldm"
            # write_hdl ProcessorNanGate15 > $netlistdir/processor.nldm.netlist.v
        } else {
            set processor_name "processor.functional"
            # write_hdl ProcessorNanGate15 > $netlistdir/processor.functional.netlist.v
        }
    }
}

# reporting 
check_timing_intent > $reportdir/$processor_name-timing_intent.rpt
report power -rtl_cross_reference > $reportdir/$processor_name.power-cross.txt                                                                    
report timing -lint > $reportdir/$processor_name-timing.lint.rpt
report timing > $reportdir/$processor_name-timing.rpt
report area > $reportdir/$processor_name-area.rpt
report power > $reportdir/$processor_name-power.txt                                                                    

# check_timing_intent > $reportdir/timing_intent.rpt
# report power -rtl_cross_reference > $reportdir/riscv_fpu.power-cross.txt                                                                    
# report timing -lint > $reportdir/riscv_fpu.timing.lint.rpt
# report timing > $reportdir/riscv_fpu.timing.rpt
# report area > $reportdir/riscv_fpu.area.rpt
# report power > $reportdir/riscv_fpu.power.txt                                                                    

# consolidate netlist
write_hdl > $netlistdir/$processor_name-netlist.v

exit
