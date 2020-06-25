# MIPT University
# sergeykhbr@gmail.com
#

include src.mk

TIMESCALE=1ns/10ps
BENCH=asic_top_tb
CYCLES=30000

INC=+incdir+${RTL_HOME}
VLOG_PARAMS_TB=-64 -sv -work work -update
VHDL_PARAMS=-64 -v93 -smartorder -V200X -update
ELAB_PARAMS=-64 -v93 -namemap_mixgen -update -timescale ${TIMESCALE} \
            -access +rwc
SIM_OPTS = -64 -input ./ncsim_settings work.${BENCH} +cycles=${CYCLES}

TOOL_PATH := ${XCELIUM}
# POWER_DIR := ${TOP_ROOT}/../examples/power-nangate15/rv64g-hex
POWER_HEX_SRCS=$(wildcard $(POWER_DIR)/*.hex)

POWER_TIMEBOMB := 5000us
POWER_SIM_OPTS = -64 -update -input ./ncsim_power_settings +cycles=${CYCLES} work.${BENCH}

POWER_DIR := ${TOP_ROOT}/../examples/power-nangate15/test
TCF_FILES_DIR := tcf_files

TCF_FILES=$(patsubst $(POWER_DIR)/%.hex, ${TCF_FILES_DIR}/%.hex.tcf, $(POWER_HEX_SRCS))

prep:
	@mkdir -p work
	@mkdir -p ambalib
	@mkdir -p techmap 
	@mkdir -p ethlib
	@mkdir -p misclib 
	@mkdir -p riverlib 
	@mkdir -p commonlib
	@mkdir -p gnsslib 
	@mkdir -p tcf_files 
	@mkdir -p xmsimlog 

clr_logs:
	@rm -f *.log
	@rm -f *.log.tmp
	@rm -f ./*.dis ./*.ecs*
	@rm -f ./*.errmsg* ./*.mix


comp: prep clr_logs
	@ncvlog ${VLOG_PARAMS_TB} ${INC}        -f  vlog.f
	@ncvhdl ${VHDL_PARAMS} -work commonlib 	-f 	lists/commonlib.f
	@ncvhdl ${VHDL_PARAMS} -work ambalib   	-f 	lists/ambalib.f
	@ncvhdl ${VHDL_PARAMS} -work techmap   	-f 	lists/techmap.f
	@ncvhdl ${VHDL_PARAMS} -work ethlib 	-f 	lists/ethlib.f
	@ncvhdl ${VHDL_PARAMS} -work misclib  	-f 	lists/misclib.f
	@ncvhdl ${VHDL_PARAMS} -work riverlib  	-f	lists/riverlib.f
	@ncvhdl ${VHDL_PARAMS} -work gnsslib  	-f	lists/gnsslib.f
	@ncvhdl ${VHDL_PARAMS} -work work      	-f 	vhdl.f

build: comp
	@ncelab ${ELAB_PARAMS} ${BENCH}

gui:clr_logs
	@ncsim ${SIM_OPTS} -gui

sim-pre-power: prep clr_logs
	@{  set -e;\
		for test in $(POWER_HEX_SRCS); do \
			hexname=`basename $$test`; \
			printf "\033[0;32mCompiling $$hexname\033[0m\n"; \
	        ${TOOL_PATH}/xmvlog ${VLOG_PARAMS_TB} ${INC}   	    -f	vlog.f; \
	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work commonlib 	-f  lists/commonlib.f; \
	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work ambalib   	-f  lists/ambalib.f; \
	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work techmap   	-f  lists/techmap.f; \
	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work ethlib 	-f  lists/ethlib.f; \
	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work misclib  	-f  lists/misclib.f; \
	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work riverlib  	-f  lists/riverlib.f; \
	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work gnsslib  	-f  lists/gnsslib.f; \
	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work work      	-f  vhdl.f; \
			printf "\033[0;32mElaborating $$hexname\033[0m\n"; \
	        ${TOOL_PATH}/xmelab ${ELAB_PARAMS} -work work -generic 'power_sim_estimation=>"false"' -generic "power_hex_file=>\"./$$test\"" ${BENCH}; \
			printf "\033[0;32mRunning $$hexname\033[0m\n"; \
			sed "s/sub/$$hexname/g; s/\$$timebomb/${POWER_TIMEBOMB}/g" xmsim_power_settings > ncsim_power_settings; \
	        ${TOOL_PATH}/xmsim ${POWER_SIM_OPTS} -logfile xmsimlog/$$hexname.log; \
		done; \
	}

# POWER_HEX_SRCS=$(wildcard $(POWER_DIR)/*.hex)
${TCF_FILES_DIR}/%.hex.tcf: $(POWER_DIR)/%.hex
	@{  set -e;\
		hexname=`basename $^`; \
		printf "\033[0;32mCompiling $$hexname\033[0m\n"; \
		${TOOL_PATH}/xmvlog ${VLOG_PARAMS_TB} ${INC}   	    -f	vlog_power.f; \
		${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work commonlib 	-f  lists/commonlib.f; \
		${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work ambalib   	-f  lists/ambalib.f; \
		${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work techmap   	-f  lists/techmap.f; \
		${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work ethlib 	-f  lists/ethlib.f; \
		${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work misclib  	-f  lists/misclib.f; \
		${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work riverlib  	-f  lists/riverlib.f; \
		${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work gnsslib  	-f  lists/gnsslib.f; \
		${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work work      	-f  vhdl.f; \
		printf "\033[0;32mElaborating $$hexname\033[0m\n"; \
		${TOOL_PATH}/xmelab ${ELAB_PARAMS} -work work -generic 'power_sim_estimation=>"true"' -generic "power_hex_file=>\"./$^\"" ${BENCH}; \
		printf "\033[0;32mRunning $$hexname\033[0m\n"; \
		sed "s/sub/$$hexname/g; s/\$$timebomb/${POWER_TIMEBOMB}/g" xmsim_power_settings > ncsim_power_settings; \
		${TOOL_PATH}/xmsim ${POWER_SIM_OPTS} -logfile xmsimlog/$$hexname.log; \
	}

sim-pos-power: prep clr_logs ${TCF_FILES}


# sim-pos-power: prep clr_logs
# 	@{  set -e;\
# 		for test in $(POWER_HEX_SRCS); do \
# 			hexname=`basename $$test`; \
# 			printf "\033[0;32mCompiling $$hexname\033[0m\n"; \
# 	        ${TOOL_PATH}/xmvlog ${VLOG_PARAMS_TB} ${INC}   	    -f	vlog_power.f; \
# 	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work commonlib 	-f  lists/commonlib.f; \
# 	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work ambalib   	-f  lists/ambalib.f; \
# 	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work techmap   	-f  lists/techmap.f; \
# 	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work ethlib 	-f  lists/ethlib.f; \
# 	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work misclib  	-f  lists/misclib.f; \
# 	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work riverlib  	-f  lists/riverlib.f; \
# 	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work gnsslib  	-f  lists/gnsslib.f; \
# 	        ${TOOL_PATH}/xmvhdl ${VHDL_PARAMS} -work work      	-f  vhdl.f; \
# 			printf "\033[0;32mElaborating $$hexname\033[0m\n"; \
# 	        ${TOOL_PATH}/xmelab ${ELAB_PARAMS} -work work -generic 'power_sim_estimation=>"true"' -generic "power_hex_file=>\"./$$test\"" ${BENCH}; \
# 			printf "\033[0;32mRunning $$hexname\033[0m\n"; \
# 			sed "s/sub/$$hexname/g; s/\$$timebomb/${POWER_TIMEBOMB}/g" xmsim_power_settings > ncsim_power_settings; \
# 	        ${TOOL_PATH}/xmsim ${POWER_SIM_OPTS} -logfile xmsimlog/$$hexname.log; \
# 		done; \
# 	}

clean:
	@rm -f *.log *.key *.diag *.err
	@rm -rf gnsslib commonlib ambalib techmap ethlib misclib riverlib work
	@rm -rf waves* INCA_* .simvision
	@rm -f ./*.tmp
	@rm -f ./*.dis ./*.ecs*
	@rm -f ./*.errmsg* ./*.mix
	@rm -f ./*.X
	@rm -rf ./*.shm
	@rm -rf ./xmsimlog
