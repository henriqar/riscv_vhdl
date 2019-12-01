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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library techmap;
use techmap.gencomp.all;

package config_target is
-- Technology and synthesis options
  constant CFG_FABTECH : integer := inferred;
  constant CFG_MEMTECH : integer := inferred;
  constant CFG_PADTECH : integer := inferred;
  constant CFG_JTAGTECH : integer := inferred;

  constant CFG_ASYNC_RESET : boolean := false;

  constant CFG_TOPDIR : string := "../../../";

  --! @brief   Dual-core configuration enabling
  --! @details This config parameter used only with CPU River
  constant CFG_COMMON_DUAL_CORE_ENABLE : boolean := false;

  --! @brief   HEX-image for the initialization of the Boot ROM.
  --! @details This file is used by \e inferred ROM implementation.
  constant CFG_SIM_BOOTROM_HEX : string := 
              CFG_TOPDIR & "examples/boot/linuxbuild/bin/bootimage.hex";
--              CFG_TOPDIR & "examples/bootrom_tests/linuxbuild/bin/bootrom_tests.hex";

  --! @brief   HEX-image for the initialization of the FwImage ROM.
  --! @details This file is used by \e inferred ROM implementation.
  constant CFG_SIM_FWIMAGE_HEX : string := 
                CFG_TOPDIR & "examples/zephyr/gcc711/zephyr.hex";
--                CFG_TOPDIR & "examples/dhrystone21/makefiles/bin/dhrystone21.hex";
                

  --! @brief Hardware SoC Identificator.
  --!
  --! @details Read Only unique platform identificator that could be
  --!          read by firmware from the Plug'n'Play support module.
  constant CFG_HW_ID : std_logic_vector(31 downto 0) := X"20191201";

  --! @brief Enabling Ethernet MAC interface.
  --! @details By default MAC module enables support of the debug feature EDCL.
  constant CFG_ETHERNET_ENABLE : boolean := true;

  --! @brief Enable/Disable Debug Unit 
  constant CFG_DSU_ENABLE : boolean := true;

  --! External Flash IC connected via SPI
  constant CFG_EXT_FLASH_ENA : boolean := true;

  --! GNSS sub-system
  constant CFG_GNSS_SS_ENA : boolean := false;

  --! OTP 8 KB memory bank
  constant CFG_OTP8KB_ENA : boolean := true;

end;
