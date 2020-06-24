--!
--! Copyright 2020 Sergey Khabarov, sergeykhbr@gmail.com
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

--! Standard library.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library commonlib;
use commonlib.types_common.all;
--! AMBA system bus specific library.
library ambalib;
--! AXI4 configuration constants.
use ambalib.types_amba4.all;
use ambalib.types_bus0.all; -- TODO: REMOVE ME when update dsu

--! RIVER CPU specific library.
library riverlib;
--! RIVER CPU configuration constants.
use riverlib.river_cfg.all;

--! @brief   Declaration of components visible on SoC top level.
package types_river is

constant CFG_TOTAL_CPU_MAX : integer := 2;

-- AXI4 with ACE channels
type axi4_river_out_type is record
  aw_valid : std_logic;
  aw_bits : axi4_metadata_type;
  aw_id   : std_logic_vector(CFG_CPU_ID_BITS-1 downto 0);
  aw_user : std_logic_vector(CFG_CPU_USER_BITS-1 downto 0);
  w_valid : std_logic;
  w_data : std_logic_vector(L1CACHE_LINE_BITS-1 downto 0);
  w_last : std_logic;
  w_strb : std_logic_vector(L1CACHE_BYTES_PER_LINE-1 downto 0);
  w_user : std_logic_vector(CFG_CPU_USER_BITS-1 downto 0);
  b_ready : std_logic;
  ar_valid : std_logic;
  ar_bits : axi4_metadata_type;
  ar_id   : std_logic_vector(CFG_CPU_ID_BITS-1 downto 0);
  ar_user : std_logic_vector(CFG_CPU_USER_BITS-1 downto 0);
  r_ready : std_logic;
  -- ACE signals
  ar_domain : std_logic_vector(1 downto 0);                -- 00=Non-shareable (single master in domain)
  ar_snoop : std_logic_vector(3 downto 0);                 -- Table C3-7:
  ar_bar : std_logic_vector(1 downto 0);                   -- read barrier transaction
  aw_domain : std_logic_vector(1 downto 0);
  aw_snoop : std_logic_vector(3 downto 0);                 -- Table C3-8
  aw_bar : std_logic_vector(1 downto 0);                   -- write barrier transaction
  ac_ready : std_logic;
  cr_valid : std_logic;
  cr_resp : std_logic_vector(4 downto 0);
  cd_valid : std_logic;
  cd_data : std_logic_vector(L1CACHE_LINE_BITS-1 downto 0);
  cd_last : std_logic;
  rack : std_logic;
  wack : std_logic;
end record;

constant axi4_river_out_none : axi4_river_out_type := (
      '0', META_NONE, (others=>'0'), (others => '0'),
      '0', (others=>'0'), '0', (others=>'0'), (others => '0'), 
      '0', '0', META_NONE, (others=>'0'), (others => '0'), '0',
       "00", X"0", "00", "00", X"0", "00", '0', '0',
       "00000", '0', (others => '0'), '0', '0', '0');

type axi4_river_in_type is record
  aw_ready : std_logic;
  w_ready : std_logic;
  b_valid : std_logic;
  b_resp : std_logic_vector(1 downto 0);
  b_id   : std_logic_vector(CFG_CPU_ID_BITS-1 downto 0);
  b_user : std_logic_vector(CFG_CPU_USER_BITS-1 downto 0);
  ar_ready : std_logic;
  r_valid : std_logic;
  r_resp : std_logic_vector(3 downto 0);
  r_data : std_logic_vector(L1CACHE_LINE_BITS-1 downto 0);
  r_last : std_logic;
  r_id   : std_logic_vector(CFG_CPU_ID_BITS-1 downto 0);
  r_user : std_logic_vector(CFG_CPU_USER_BITS-1 downto 0);
  -- ACE signals
  ac_valid : std_logic;
  ac_addr : std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
  ac_snoop : std_logic_vector(3 downto 0);                  -- Table C3-19
  ac_prot : std_logic_vector(2 downto 0);
  cr_ready : std_logic;
  cd_ready : std_logic;
end record;

constant axi4_river_in_none : axi4_river_in_type := (
      '0', '0', '0', AXI_RESP_OKAY, (others=>'0'), (others => '0'),
      '0', '0', (others => '0'), (others=>'0'), '0', (others=>'0'), (others => '0'),
      '0', (others => '0'), X"0", "000", '0', '0');

type axi4_river_in_vector is array (0 to CFG_TOTAL_CPU_MAX-1) of axi4_river_in_type;
type axi4_river_out_vector is array (0 to CFG_TOTAL_CPU_MAX-1) of axi4_river_out_type;


type dport_in_type is record
    valid : std_logic;
    write : std_logic;
    region : std_logic_vector(1 downto 0);
    addr : std_logic_vector(11 downto 0);
    wdata : std_logic_vector(RISCV_ARCH-1 downto 0);
end record;

constant dport_in_none : dport_in_type := (
  '0', '0', (others => '0'), (others => '0'), (others => '0'));

type dport_in_vector is array (0 to CFG_TOTAL_CPU_MAX-1) 
       of dport_in_type;


type dport_out_type is record
    halted : std_logic;
    ready : std_logic;
    rdata : std_logic_vector(RISCV_ARCH-1 downto 0);
end record;

constant dport_out_none : dport_out_type := (
    '0', '1', (others => '0'));

type dport_out_vector is array (0 to CFG_TOTAL_CPU_MAX-1) 
     of dport_out_type;

  --! @brief   Declaration of the Debug Support Unit with the AXI interface.
  --! @details This module provides access to processors CSRs via HostIO bus.
  --! @param[in] clk           System clock (BUS/CPU clock).
  --! @param[in] rstn          Reset signal with active LOW level.
  --! @param[in] i_axi         Slave slot input signals.
  --! @param[out] o_axi        Slave slot output signals.
  --! @param[out] o_dporti     Debug port output signals connected to River CPU.
  --! @param[in] i_dporto      River CPU debug port response signals.
  --! @param[out] o_soft_rstn  Software reset CPU and interrupt controller. Active HIGH
  --! @param[in] i_bus_util_w  Write bus access utilization per master statistic
  --! @param[in] i_bus_util_r  Write bus access utilization per master statistic
  component axi_dsu is
  generic (
    async_reset : boolean := false;
    xaddr    : integer := 0;
    xmask    : integer := 16#fffff#
  );
  port 
  (
    clk    : in std_logic;
    nrst   : in std_logic;
    o_cfg  : out axi4_slave_config_type;
    i_axi  : in axi4_slave_in_type;
    o_axi  : out axi4_slave_out_type;
    o_dporti : out dport_in_vector;
    i_dporto : in dport_out_vector;
    o_soft_rst : out std_logic;
    i_bus_util_w : in std_logic_vector(CFG_BUS0_XMST_TOTAL-1 downto 0);
    i_bus_util_r : in std_logic_vector(CFG_BUS0_XMST_TOTAL-1 downto 0)
  );
  end component;


--! @brief   RIVER CPU component declaration.
--! @details This module implements Risc-V CPU Core named as
--!          "RIVER" with AXI interface.
--! @param[in] xindex AXI master index
--! @param[in] i_rstn     Reset signal with active LOW level.
--! @param[in] i_clk      System clock (BUS/CPU clock).
--! @param[in] i_msti     Bus-to-Master device signals.
--! @param[out] o_msto    CachedTile-to-Bus request signals.
--! @param[in] i_ext_irq  Interrupts line supported by Rocket chip.
component river_amba is 
  generic (
    power_sim_estimation : boolean := false;
    memtech : integer;
    hartid : integer;
    async_reset : boolean;
    fpu_ena : boolean;
    coherence_ena : boolean;
    tracer_ena : boolean
  );
  port ( 
    i_nrst   : in std_logic;
    i_clk    : in std_logic;
    i_msti   : in axi4_river_in_type;
    o_msto   : out axi4_river_out_type;
    o_mstcfg : out axi4_master_config_type;
    i_dport  : in dport_in_type;
    o_dport  : out dport_out_type;
    i_ext_irq : in std_logic
  );
end component;

component river_serdes is 
  generic (
    async_reset : boolean
  );
  port ( 
    i_nrst  : in std_logic;
    i_clk   : in std_logic;
    i_coreo : in axi4_river_out_type;
    o_corei : out axi4_river_in_type;
    i_msti  : in axi4_master_in_type;
    o_msto  : out axi4_master_out_type
);
end component;

component ProcessorNanGate15 is
  port (
      i_clk : in std_logic;                                             -- CPU clock
      i_nrst : in std_logic;                                            -- Reset. Active LOW.
      -- Control path:
      i_req_ctrl_ready : in std_logic;                                  -- ICache is ready to accept request
      o_req_ctrl_valid : out std_logic;                                 -- Request to ICache is valid
      o_req_ctrl_addr : out std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);-- Requesting address to ICache
      i_resp_ctrl_valid : in std_logic;                                 -- ICache response is valid
      i_resp_ctrl_addr : in std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);-- Response address must be equal to the latest request address
      i_resp_ctrl_data : in std_logic_vector(31 downto 0);              -- Read value
      i_resp_ctrl_load_fault : in std_logic;                            -- bus response with error
      i_resp_ctrl_executable : in std_logic;
      o_resp_ctrl_ready : out std_logic;
      -- Data path:
      i_req_data_ready : in std_logic;                                  -- DCache is ready to accept request
      o_req_data_valid : out std_logic;                                 -- Request to DCache is valid
      o_req_data_write : out std_logic;                                 -- Read/Write transaction
      o_req_data_addr : out std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);-- Requesting address to DCache
      o_req_data_wdata : out std_logic_vector(63 downto 0);             -- Writing value
      o_req_data_wstrb : out std_logic_vector(7 downto 0);              -- 8-bytes aligned strobs
      i_resp_data_valid : in std_logic;                                 -- DCache response is valid
      i_resp_data_addr : in std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);-- DCache response address must be equal to the latest request address
      i_resp_data_data : in std_logic_vector(63 downto 0);              -- Read value
      i_resp_data_store_fault_addr : in std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
      i_resp_data_load_fault : in std_logic;                            -- Bus response with SLVERR or DECERR on read
      i_resp_data_store_fault : in std_logic;                           -- Bus response with SLVERR or DECERR on write
      i_resp_data_er_mpu_load : in std_logic;
      i_resp_data_er_mpu_store : in std_logic;
      o_resp_data_ready : out std_logic;
      -- External interrupt pin
      i_ext_irq : in std_logic;                                         -- PLIC interrupt accordingly with spec
      o_time : out std_logic_vector(63 downto 0);                       -- Timer in clock except halt state
      o_exec_cnt : out std_logic_vector(63 downto 0);
      -- MPU interface
      o_mpu_region_we : out std_logic;
      o_mpu_region_idx : out std_logic_vector(CFG_MPU_TBL_WIDTH-1 downto 0);
      o_mpu_region_addr : out std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
      o_mpu_region_mask : out std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);
      o_mpu_region_flags : out std_logic_vector(CFG_MPU_FL_TOTAL-1 downto 0);  -- {ena, cachable, r, w, x}
      -- Debug interface:
      i_dport_valid : in std_logic;                                     -- Debug access from DSU is valid
      i_dport_write : in std_logic;                                     -- Write command flag
      i_dport_region : in std_logic_vector(1 downto 0);                 -- Registers region ID: 0=CSR; 1=IREGS; 2=Control
      i_dport_addr : in std_logic_vector(11 downto 0);                  -- Register idx
      i_dport_wdata : in std_logic_vector(RISCV_ARCH-1 downto 0);       -- Write value
      o_dport_ready : out std_logic;                                    -- Response is ready
      o_dport_rdata : out std_logic_vector(RISCV_ARCH-1 downto 0);      -- Response value
      o_halted : out std_logic;
      -- Debug signals:
      o_flush_address : out std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);-- Address of instruction to remove from ICache
      o_flush_valid : out std_logic;                                    -- Remove address from ICache is valid
      o_data_flush_address : out std_logic_vector(CFG_CPU_ADDR_BITS-1 downto 0);    -- Address of instruction to remove from D$
      o_data_flush_valid : out std_logic;                               -- Remove address from D$ is valid
      i_data_flush_end : in std_logic;
      i_istate : in std_logic_vector(3 downto 0);                       -- ICache state machine value
      i_dstate : in std_logic_vector(3 downto 0);                       -- DCache state machine value
      i_cstate : in std_logic_vector(1 downto 0)                        -- CacheTop state machine value
    );
end component;

end; -- package body
