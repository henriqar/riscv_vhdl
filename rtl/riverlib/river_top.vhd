--!
--! Copyright 2018 Sergey Khabarov, sergeykhbr@gmail.com
--!
--! Licensed under the Apache License, Version 2.0 (the "License");
--! you may not use this file except in compliance with the License.
--! You may obtain a copy of the License at
--!
--!     http://www.apache.org/licenses/LICENSE-2.0
--!
--! Unless required by applicable law or agreed to in writing, software
--! distributed under the License is distributed on an "AS IS" BASIS,
--! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--! See the License for the specific language governing permissions and
--! limitations under the License.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use std.textio.all;
library commonlib;
use commonlib.types_common.all;
--! RIVER CPU specific library.
library riverlib;
--! RIVER CPU configuration constants.
use riverlib.river_cfg.all;
--! River Netlist component declaration
use riverlib.types_river.all;
library ambalib;
use ambalib.types_amba4.all;

entity RiverTop is
  generic (
    memtech : integer := 0;
    hartid : integer := 0;
    async_reset : boolean := false;
    fpu_ena : boolean := true;
    coherence_ena : boolean := false;
    tracer_ena : boolean := false;
    power_sim_estimation : boolean := false
  );
  port (
    i_clk : in std_logic;                                             -- CPU clock
    i_nrst : in std_logic;                                            -- Reset. Active LOW.
    -- Memory interface:
    i_req_mem_ready : in std_logic;                                   -- AXI request was accepted
    o_req_mem_path : out std_logic;                                   -- 0=ctrl; 1=data path
    o_req_mem_valid : out std_logic;                                  -- AXI memory request is valid
    o_req_mem_type : out std_logic_vector(REQ_MEM_TYPE_BITS-1 downto 0);-- AXI memory request is write type
    o_req_mem_addr : out std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0); -- AXI memory request address
    o_req_mem_strob : out std_logic_vector(L1CACHE_BYTES_PER_LINE-1 downto 0);-- Writing strob. 1 bit per Byte
    o_req_mem_data : out std_logic_vector(L1CACHE_LINE_BITS-1 downto 0); -- Writing data
    i_resp_mem_valid : in std_logic;                                  -- AXI response is valid
    i_resp_mem_path : in std_logic;                                   -- 0=ctrl; 1=data path
    i_resp_mem_data : in std_logic_vector(L1CACHE_LINE_BITS-1 downto 0); -- Read data
    i_resp_mem_load_fault : in std_logic;                             -- Bus response with SLVERR or DECERR on read
    i_resp_mem_store_fault : in std_logic;                            -- Bus response with SLVERR or DECERR on write
    -- Interrupt line from external interrupts controller (PLIC).
    i_ext_irq : in std_logic;
    o_time : out std_logic_vector(63 downto 0);                       -- Timer. Clock counter except halt state.
    o_exec_cnt : out std_logic_vector(63 downto 0);
    -- D$ Snoop interface
    i_req_snoop_valid : in std_logic;
    i_req_snoop_type : in std_logic_vector(SNOOP_REQ_TYPE_BITS-1 downto 0);
    o_req_snoop_ready : out std_logic;
    i_req_snoop_addr : in std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
    i_resp_snoop_ready : in std_logic;
    o_resp_snoop_valid : out std_logic;
    o_resp_snoop_data : out std_logic_vector(L1CACHE_LINE_BITS-1 downto 0);
    o_resp_snoop_flags : out std_logic_vector(DTAG_FL_TOTAL-1 downto 0);
    -- Debug interface:
    i_dport_valid : in std_logic;                                     -- Debug access from DSU is valid
    i_dport_write : in std_logic;                                     -- Write command flag
    i_dport_region : in std_logic_vector(1 downto 0);                 -- Registers region ID: 0=CSR; 1=IREGS; 2=Control
    i_dport_addr : in std_logic_vector(11 downto 0);                  -- Register idx
    i_dport_wdata : in std_logic_vector(RISCV_ARCH-1 downto 0);       -- Write value
    o_dport_ready : out std_logic;                                    -- Response is ready
    o_dport_rdata : out std_logic_vector(RISCV_ARCH-1 downto 0);      -- Response value
    o_halted : out std_logic
  );
end;
 
architecture arch_RiverTop of RiverTop is

  -- Control path:
  signal w_req_ctrl_ready : std_logic;
  signal w_req_ctrl_valid : std_logic;
  signal wb_req_ctrl_addr : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  signal w_resp_ctrl_valid : std_logic;
  signal wb_resp_ctrl_addr : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  signal wb_resp_ctrl_data : std_logic_vector(31 downto 0);
  signal w_resp_ctrl_load_fault : std_logic;
  signal w_resp_ctrl_executable : std_logic;
  signal w_resp_ctrl_ready : std_logic;
  -- Data path:
  signal w_req_data_ready : std_logic;
  signal w_req_data_valid : std_logic;
  signal w_req_data_write : std_logic;
  signal wb_req_data_addr : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  signal wb_req_data_wdata : std_logic_vector(63 downto 0);
  signal wb_req_data_wstrb : std_logic_vector(7 downto 0);
  signal w_resp_data_valid : std_logic;
  signal wb_resp_data_addr : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  signal wb_resp_data_data : std_logic_vector(63 downto 0);
  signal w_resp_data_load_fault : std_logic;
  signal w_resp_data_store_fault : std_logic;
  signal w_resp_data_er_mpu_load : std_logic;
  signal w_resp_data_er_mpu_store : std_logic;
  signal wb_resp_data_store_fault_addr : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  signal w_resp_data_ready : std_logic;
  signal w_mpu_region_we : std_logic;
  signal wb_mpu_region_idx : std_logic_vector(CFG_MPU_TBL_WIDTH-1 downto 0);
  signal wb_mpu_region_addr : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  signal wb_mpu_region_mask : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  signal wb_mpu_region_flags : std_logic_vector(CFG_MPU_FL_TOTAL-1 downto 0);
  signal wb_flush_address : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  signal w_flush_valid : std_logic;
  signal wb_data_flush_address : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  signal w_data_flush_valid : std_logic;
  signal w_data_flush_end : std_logic;
  signal wb_istate : std_logic_vector(3 downto 0);
  signal wb_dstate : std_logic_vector(3 downto 0);
  signal wb_cstate : std_logic_vector(1 downto 0);

  constant POWER_SIM_STOP_ADDR : std_logic_vector(CFG_SYSBUS_ADDR_BITS-1 downto 0) := "00000000000000000001111111110000";

begin

    rtl_generate : if power_sim_estimation = false generate
        proc0 : Processor generic map (
            hartid => hartid,
            async_reset => async_reset,
            fpu_ena => fpu_ena,
            tracer_ena => tracer_ena
          ) port map (
            i_clk => i_clk,
            i_nrst => i_nrst,
            i_req_ctrl_ready => w_req_ctrl_ready,
            o_req_ctrl_valid => w_req_ctrl_valid,
            o_req_ctrl_addr => wb_req_ctrl_addr,
            i_resp_ctrl_valid => w_resp_ctrl_valid,
            i_resp_ctrl_addr => wb_resp_ctrl_addr,
            i_resp_ctrl_data => wb_resp_ctrl_data,
            i_resp_ctrl_load_fault => w_resp_ctrl_load_fault,
            i_resp_ctrl_executable => w_resp_ctrl_executable,
            o_resp_ctrl_ready => w_resp_ctrl_ready,
            i_req_data_ready => w_req_data_ready,
            o_req_data_valid => w_req_data_valid,
            o_req_data_write => w_req_data_write,
            o_req_data_addr => wb_req_data_addr,
            o_req_data_wdata => wb_req_data_wdata,
            o_req_data_wstrb => wb_req_data_wstrb,
            i_resp_data_valid => w_resp_data_valid,
            i_resp_data_addr => wb_resp_data_addr,
            i_resp_data_data => wb_resp_data_data,
            i_resp_data_store_fault_addr => wb_resp_data_store_fault_addr,
            i_resp_data_load_fault => w_resp_data_load_fault,
            i_resp_data_store_fault => w_resp_data_store_fault,
            i_resp_data_er_mpu_load => w_resp_data_er_mpu_load,
            i_resp_data_er_mpu_store => w_resp_data_er_mpu_store,
            o_resp_data_ready => w_resp_data_ready,
            i_ext_irq => i_ext_irq,
            o_time => o_time,
            o_exec_cnt => o_exec_cnt,
            o_mpu_region_we => w_mpu_region_we,
            o_mpu_region_idx => wb_mpu_region_idx,
            o_mpu_region_addr => wb_mpu_region_addr,
            o_mpu_region_mask => wb_mpu_region_mask,
            o_mpu_region_flags => wb_mpu_region_flags,
            i_dport_valid => i_dport_valid,
            i_dport_write => i_dport_write,
            i_dport_region => i_dport_region,
            i_dport_addr => i_dport_addr,
            i_dport_wdata => i_dport_wdata,
            o_dport_ready => o_dport_ready,
            o_dport_rdata => o_dport_rdata,
            o_halted => o_halted,
            o_flush_address => wb_flush_address,
            o_flush_valid => w_flush_valid,
            o_data_flush_address => wb_data_flush_address,
            o_data_flush_valid => w_data_flush_valid,
            i_data_flush_end => w_data_flush_end,
            i_istate => wb_istate,
            i_dstate => wb_dstate,
            i_cstate => wb_cstate);
      end generate rtl_generate;

    netlist_generate : if power_sim_estimation = true generate
        proc0 : ProcessorNanGate15 port map (
            i_clk => i_clk,
            i_nrst => i_nrst,
            i_req_ctrl_ready => w_req_ctrl_ready,
            o_req_ctrl_valid => w_req_ctrl_valid,
            o_req_ctrl_addr => wb_req_ctrl_addr,
            i_resp_ctrl_valid => w_resp_ctrl_valid,
            i_resp_ctrl_addr => wb_resp_ctrl_addr,
            i_resp_ctrl_data => wb_resp_ctrl_data,
            i_resp_ctrl_load_fault => w_resp_ctrl_load_fault,
            i_resp_ctrl_executable => w_resp_ctrl_executable,
            o_resp_ctrl_ready => w_resp_ctrl_ready,
            i_req_data_ready => w_req_data_ready,
            o_req_data_valid => w_req_data_valid,
            o_req_data_write => w_req_data_write,
            o_req_data_addr => wb_req_data_addr,
            o_req_data_wdata => wb_req_data_wdata,
            o_req_data_wstrb => wb_req_data_wstrb,
            i_resp_data_valid => w_resp_data_valid,
            i_resp_data_addr => wb_resp_data_addr,
            i_resp_data_data => wb_resp_data_data,
            i_resp_data_store_fault_addr => wb_resp_data_store_fault_addr,
            i_resp_data_load_fault => w_resp_data_load_fault,
            i_resp_data_store_fault => w_resp_data_store_fault,
            i_resp_data_er_mpu_load => w_resp_data_er_mpu_load,
            i_resp_data_er_mpu_store => w_resp_data_er_mpu_store,
            o_resp_data_ready => w_resp_data_ready,
            i_ext_irq => i_ext_irq,
            o_time => o_time,
            o_exec_cnt => o_exec_cnt,
            o_mpu_region_we => w_mpu_region_we,
            o_mpu_region_idx => wb_mpu_region_idx,
            o_mpu_region_addr => wb_mpu_region_addr,
            o_mpu_region_mask => wb_mpu_region_mask,
            o_mpu_region_flags => wb_mpu_region_flags,
            i_dport_valid => i_dport_valid,
            i_dport_write => i_dport_write,
            i_dport_region => i_dport_region,
            i_dport_addr => i_dport_addr,
            i_dport_wdata => i_dport_wdata,
            o_dport_ready => o_dport_ready,
            o_dport_rdata => o_dport_rdata,
            o_halted => o_halted,
            o_flush_address => wb_flush_address,
            o_flush_valid => w_flush_valid,
            o_data_flush_address => wb_data_flush_address,
            o_data_flush_valid => w_data_flush_valid,
            i_data_flush_end => w_data_flush_end,
            i_istate => wb_istate,
            i_dstate => wb_dstate,
            i_cstate => wb_cstate
        );
    end generate netlist_generate;

    assert_end_sim : if power_sim_estimation = true generate
      cyclelogic : process (i_clk, i_nrst)
        variable my_line : line;
        variable clk_counter : std_logic_vector(31 downto 0);
      begin

        if rising_edge(i_clk) and i_clk = '1' and i_nrst = '0' then

          -- reset clk cycle counter
          clk_counter := "00000000000000000000000000000000";

          write(my_line, string'(" Resetting DUT "));
          writeline(output, my_line);

        elsif rising_edge(i_clk) and i_clk = '1' and i_nrst = '1' then

          -- increment clk cycle counter
          clk_counter := clk_counter + '1';

          -- print tracing information for simulation and hardware
          write(my_line, string'(" CLK("));
          hwrite(my_line, clk_counter);
          write(my_line, string'(") ADDR(0x"));
          hwrite(my_line, wb_resp_ctrl_addr);
          write(my_line, string'(") DASM(0x"));
          hwrite(my_line, wb_resp_ctrl_data);
          write(my_line, string'(") O_CTRL_RDY("));
          write(my_line, w_resp_ctrl_ready);
          write(my_line, string'(") LFAULT("));
          write(my_line, w_resp_ctrl_load_fault);
          write(my_line, string'(") EXEC("));
          write(my_line, w_resp_ctrl_executable);
          write(my_line, string'(")"));
          writeline(output, my_line);


          -- to prevent infinite sim, we force break when power estimating
          assert clk_counter /= "00000000000000011111111111111111" report "Fatal End of Simulation" severity failure;
          assert wb_resp_ctrl_addr /= POWER_SIM_STOP_ADDR report "Correct End of Simulation" severity failure;

        end if;
      end process;
    end generate assert_end_sim;

    cache0 : CacheTop generic map (
        memtech => memtech,
        async_reset => async_reset,
        coherence_ena => coherence_ena
     ) port map (
        i_clk => i_clk,
        i_nrst => i_nrst,
        i_req_ctrl_valid => w_req_ctrl_valid,
        i_req_ctrl_addr => wb_req_ctrl_addr,
        o_req_ctrl_ready => w_req_ctrl_ready,
        o_resp_ctrl_valid => w_resp_ctrl_valid,
        o_resp_ctrl_addr => wb_resp_ctrl_addr,
        o_resp_ctrl_data => wb_resp_ctrl_data,
        o_resp_ctrl_load_fault => w_resp_ctrl_load_fault,
        o_resp_ctrl_executable => w_resp_ctrl_executable,
        i_resp_ctrl_ready => w_resp_ctrl_ready,
        i_req_data_valid => w_req_data_valid,
        i_req_data_write => w_req_data_write,
        i_req_data_addr => wb_req_data_addr,
        i_req_data_wdata => wb_req_data_wdata,
        i_req_data_wstrb => wb_req_data_wstrb,
        o_req_data_ready => w_req_data_ready,
        o_resp_data_valid => w_resp_data_valid,
        o_resp_data_addr => wb_resp_data_addr,
        o_resp_data_data => wb_resp_data_data,
        o_resp_data_store_fault_addr => wb_resp_data_store_fault_addr,
        o_resp_data_load_fault => w_resp_data_load_fault,
        o_resp_data_store_fault => w_resp_data_store_fault,
        o_resp_data_er_mpu_load => w_resp_data_er_mpu_load,
        o_resp_data_er_mpu_store => w_resp_data_er_mpu_store,
        i_resp_data_ready => w_resp_data_ready,
        i_req_mem_ready => i_req_mem_ready,
        o_req_mem_path => o_req_mem_path,
        o_req_mem_valid => o_req_mem_valid,
        o_req_mem_type => o_req_mem_type,
        o_req_mem_addr => o_req_mem_addr,
        o_req_mem_strob => o_req_mem_strob,
        o_req_mem_data => o_req_mem_data,
        i_resp_mem_valid => i_resp_mem_valid,
        i_resp_mem_path => i_resp_mem_path,
        i_resp_mem_data => i_resp_mem_data,
        i_resp_mem_load_fault => i_resp_mem_load_fault,
        i_resp_mem_store_fault => i_resp_mem_store_fault,
        i_mpu_region_we => w_mpu_region_we,
        i_mpu_region_idx => wb_mpu_region_idx,
        i_mpu_region_addr => wb_mpu_region_addr,
        i_mpu_region_mask => wb_mpu_region_mask,
        i_mpu_region_flags => wb_mpu_region_flags,
        i_req_snoop_valid => i_req_snoop_valid,
        i_req_snoop_type => i_req_snoop_type,
        o_req_snoop_ready => o_req_snoop_ready,
        i_req_snoop_addr => i_req_snoop_addr,
        i_resp_snoop_ready => i_resp_snoop_ready,
        o_resp_snoop_valid => o_resp_snoop_valid,
        o_resp_snoop_data => o_resp_snoop_data,
        o_resp_snoop_flags => o_resp_snoop_flags,
        i_flush_address => wb_flush_address,
        i_flush_valid => w_flush_valid,
        i_data_flush_address => wb_data_flush_address,
        i_data_flush_valid => w_data_flush_valid,
        o_data_flush_end => w_data_flush_end,
        o_istate => wb_istate,
        o_dstate => wb_dstate,
        o_cstate => wb_cstate);

end;
