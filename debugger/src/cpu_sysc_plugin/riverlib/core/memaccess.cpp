/*
 *  Copyright 2019 Sergey Khabarov, sergeykhbr@gmail.com
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#include "memaccess.h"

namespace debugger {

MemAccess::MemAccess(sc_module_name name_, bool async_reset)
    : sc_module(name_),
    i_clk("i_clk"),
    i_nrst("i_nrst"),
    i_pipeline_hold("i_pipeline_hold"),
    i_e_valid("i_e_valid"),
    i_e_pc("i_e_pc"),
    i_e_instr("i_e_instr"),
    i_res_addr("i_res_addr"),
    i_res_data("i_res_data"),
    i_memop_sign_ext("i_memop_sign_ext"),
    i_memop_load("i_memop_load"),
    i_memop_store("i_memop_store"),
    i_memop_size("i_memop_size"),
    i_memop_addr("i_memop_addr"),
    o_wena("o_wena"),
    o_waddr("o_waddr"),
    o_wdata("o_wdata"),
    i_mem_req_ready("i_mem_req_ready"),
    o_mem_valid("o_mem_valid"),
    o_mem_write("o_mem_write"),
    o_mem_sz("o_mem_sz"),
    o_mem_addr("o_mem_addr"),
    o_mem_data("o_mem_data"),
    i_mem_data_valid("i_mem_data_valid"),
    i_mem_data_addr("i_mem_data_addr"),
    i_mem_data("i_mem_data"),
    o_mem_resp_ready("o_mem_resp_ready"),
    i_hazard("i_hazard"),
    o_wb_ready("o_wb_ready"),
    o_wb_addr("o_wb_addr"),
    o_hold("o_hold"),
    o_valid("o_valid"),
    o_pc("o_pc"),
    o_instr("o_instr") {
    async_reset_ = async_reset;

    SC_METHOD(comb);
    sensitive << i_nrst;
    sensitive << i_pipeline_hold;
    sensitive << i_hazard;
    sensitive << i_mem_req_ready;
    sensitive << i_e_valid;
    sensitive << i_e_pc;
    sensitive << i_e_instr;
    sensitive << i_res_addr;
    sensitive << i_res_data;
    sensitive << i_memop_sign_ext;
    sensitive << i_memop_load;
    sensitive << i_memop_store;
    sensitive << i_memop_size;
    sensitive << i_memop_addr;
    sensitive << i_mem_data_valid;
    sensitive << i_mem_data_addr;
    sensitive << i_mem_data;
    sensitive << r.state;
    sensitive << r.memop_r;
    sensitive << r.memop_rw;
    sensitive << r.pc;
    sensitive << r.instr;
    sensitive << r.wb_ready;
    sensitive << r.wb_addr;
    sensitive << r.res_addr;
    sensitive << r.res_data;
    sensitive << r.memop_sign_ext;
    sensitive << r.memop_size;
    sensitive << r.wena;
    sensitive << r.hazard;

    SC_METHOD(registers);
    sensitive << i_nrst;
    sensitive << i_clk.pos();
};

void MemAccess::generateVCD(sc_trace_file *i_vcd, sc_trace_file *o_vcd) {
    if (o_vcd) {
        sc_trace(o_vcd, i_pipeline_hold, i_pipeline_hold.name());
        sc_trace(o_vcd, i_e_valid, i_e_valid.name());
        sc_trace(o_vcd, i_e_pc, i_e_pc.name());
        sc_trace(o_vcd, i_e_instr, i_e_instr.name());
        sc_trace(o_vcd, i_memop_store, i_memop_store.name());
        sc_trace(o_vcd, i_memop_load, i_memop_load.name());
        sc_trace(o_vcd, o_mem_valid, o_mem_valid.name());
        sc_trace(o_vcd, o_mem_write, o_mem_write.name());
        sc_trace(o_vcd, i_mem_req_ready, i_mem_req_ready.name());
        sc_trace(o_vcd, o_mem_sz, o_mem_sz.name());
        sc_trace(o_vcd, o_mem_addr, o_mem_addr.name());
        sc_trace(o_vcd, o_mem_data, o_mem_data.name());
        sc_trace(o_vcd, i_mem_data_valid, i_mem_data_valid.name());
        sc_trace(o_vcd, i_mem_data_addr, i_mem_data_addr.name());
        sc_trace(o_vcd, i_mem_data, i_mem_data.name());
        sc_trace(o_vcd, o_mem_resp_ready, o_mem_resp_ready.name());

        sc_trace(o_vcd, o_hold, o_hold.name());
        sc_trace(o_vcd, o_valid, o_valid.name());
        sc_trace(o_vcd, o_pc, o_pc.name());
        sc_trace(o_vcd, o_instr, o_instr.name());
        sc_trace(o_vcd, o_wena, o_wena.name());
        sc_trace(o_vcd, o_waddr, o_waddr.name());
        sc_trace(o_vcd, o_wdata, o_wdata.name());
        sc_trace(o_vcd, i_hazard, i_hazard.name());
        sc_trace(o_vcd, o_wb_ready, o_wb_ready.name());
        sc_trace(o_vcd, o_wb_addr, o_wb_addr.name());

        std::string pn(name());
        sc_trace(o_vcd, r.state, pn + ".state");
        sc_trace(o_vcd, w_next, pn + ".w_next");
        sc_trace(o_vcd, r.hazard, pn + ".r_hazard");
    }
}

void MemAccess::comb() {
    bool w_hold;
    bool w_valid;
    sc_uint<RISCV_ARCH> wb_mem_data_signext;
    sc_uint<RISCV_ARCH> wb_res_data;

    v = r;

    w_next = 0;
    if (i_e_valid.read() == 1) {
        if (i_pipeline_hold.read() == 0) {
            w_next = 1;
            if (r.hazard.read() == 1) {
                v.hazard = 0;
            }
        } else if (i_hazard.read() == 1) {
            w_next = 1;
            v.hazard = 1;
        }
    }

    w_hold = 0;
    w_valid = 0;

    switch (r.state.read()) {
    case State_Idle:
        if (w_next == 1) {
            if (i_memop_load.read() == 1 || i_memop_store.read() == 1) {
                if (i_mem_req_ready.read() == 1) {
                    v.state = State_WaitResponse;
                } else {
                    w_hold = 1;
                    v.state = State_WaitReqAccept;
                }
            } else {
                v.state = State_RegForward;
            }
        }
        break;
    case State_WaitReqAccept:
        w_hold = 1;
        if (i_mem_req_ready.read() == 1) {
            v.state = State_WaitResponse;
        }
        break;
    case State_WaitResponse:
        w_valid = 1;
        if (i_mem_data_valid.read() == 0) {
            w_valid = 0;
            w_hold = 1;
        } else if (w_next == 1) {
            if (i_memop_load.read() == 1 || i_memop_store.read() == 1) {
                if (i_mem_req_ready.read() == 1) {
                    v.state = State_WaitResponse;
                } else {
                    w_hold = 1;
                    v.state = State_WaitReqAccept;
                }
            } else {
                v.state = State_RegForward;
            }
        } else {
            v.state = State_Idle;
        }
        break;
    case State_RegForward:
        w_valid = 1;
        if (w_next == 1) {
            if (i_memop_load.read() == 1 || i_memop_store.read() == 1) {
                if (i_mem_req_ready.read() == 1) {
                    v.state = State_WaitResponse;
                } else {
                    w_hold = 1;
                    v.state = State_WaitReqAccept;
                }
            } else {
                v.state = State_RegForward;
            }
        } else {
            v.state = State_Idle;
        }
        break;
    default:;
    }

    //v.wb_ready = w_valid;


    if (w_next == 1) {
        v.memop_r = i_memop_load.read();
        v.memop_rw = i_memop_load.read() || i_memop_store.read();
        v.pc = i_e_pc.read();
        v.instr = i_e_instr.read();
        v.res_addr = i_res_addr.read();
        v.res_data = i_res_data.read();
        v.memop_sign_ext = i_memop_sign_ext.read();
        v.memop_size = i_memop_size.read();
        if (i_res_addr.read() == 0) {
            v.wena = 0;
        } else {
            v.wena = 1;
        }
        v.wb_addr = i_res_addr.read();  // TODO: write to register without wait cycle
    }

    switch (r.memop_size.read()) {
    case MEMOP_1B:
        wb_mem_data_signext = i_mem_data;
        if (i_mem_data.read()[7]) {
            wb_mem_data_signext(63, 8) = ~0;
        }
        break;
    case MEMOP_2B:
        wb_mem_data_signext = i_mem_data;
        if (i_mem_data.read()[15]) {
            wb_mem_data_signext(63, 16) = ~0;
        }
        break;
    case MEMOP_4B:
        wb_mem_data_signext = i_mem_data;
        if (i_mem_data.read()[31]) {
            wb_mem_data_signext(63, 32) = ~0;
        }
        break;
    default:
        wb_mem_data_signext = i_mem_data;
    }

    if (r.memop_r.read() == 1) {
        if (r.memop_sign_ext.read() == 1) {
            wb_res_data = wb_mem_data_signext;
        } else {
            wb_res_data = i_mem_data;
        }
    } else {
        wb_res_data = r.res_data;
    }


    if (!async_reset_ && !i_nrst.read()) {
        R_RESET(v);
    }

    o_mem_resp_ready = 1;

    o_mem_valid = i_memop_load.read() || i_memop_store.read();
    o_mem_write = i_memop_store.read();
    o_mem_sz = i_memop_size.read();
    o_mem_addr = i_memop_addr.read();
    o_mem_data = i_res_data.read();
    o_wb_ready = w_valid;//r.wb_ready;
    o_wb_addr = r.wb_addr;

    o_wena = r.wena;
    o_waddr = r.res_addr;
    o_wdata = wb_res_data;
    o_hold = w_hold;
    /** the following signal used to executation instruction count and debug */
    o_valid = w_valid;
    o_pc = r.pc;
    o_instr = r.instr;
}

void MemAccess::registers() {
    if (async_reset_ && i_nrst.read() == 0) {
        R_RESET(r);
    } else {
        r = v;
    }
}

}  // namespace debugger

