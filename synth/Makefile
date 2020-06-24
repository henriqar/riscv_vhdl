
export TOP_ROOT=../rtl
export PRJ_ROOT=$(TOP_ROOT)/prj/sim
export RTL_HOME=${TOP_ROOT}
export SYNTH_HOME=$(pwd)

RTL_HOME=../rtl
SIM_HOME=${RTL_HOME}/prj/sim
TCF_HOME=${SIM_HOME}/tcf_files

POWER_DIR=${SIM_HOME}/power

TCF_POWER_SRCS=$(wildcard $(TCF_HOME)/*.tcf)
POWER_RESULTS=$(patsubst $(TCF_HOME)/%.tcf, $(POWER_DIR)/%.txt,$(TCF_POWER_SRCS))

.PHONY: power clean

md:
	@mkdir -p ${POWER_DIR}

all:
	genus -abort_on_error -f processor_synth.tcl -log reports/processor 

clean:
	rm -f reports/*.log* 
	rm -f reports/*.cmd*
	rm -f local_power.tcl
	rm -f ${POWER_DIR}/*.txt
	rm -f ${POWER_DIR}/*.error
	rm -f *.log*
	rm -f *.cmd*

${POWER_DIR}/%.txt: ${TCF_HOME}/%.tcf
	@{	printf "\033[0;32mEstimating power of: $^\033[0m\n";\
		export SYNTH_HOME=`pwd`; \
		sed "s:subtcf:$^:g; s:subpower:$@:g;" power.tcl > local_power.tcl; \
		genus -64 -files local_power.tcl > $@ 2> $@.error;\
	}

power: md ${POWER_RESULTS}

