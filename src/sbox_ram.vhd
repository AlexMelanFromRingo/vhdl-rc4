--------------------------------------------------------------------------------
-- S-box RAM - Dual-port RAM for RC4 S-box
-- Compatible with Xilinx ISE 8.1i (VHDL-93)
-- For Spartan-3 FPGA
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.rc4_pkg.ALL;

entity sbox_ram is
    port (
        clk         : in  std_logic;

        -- Port A (Read/Write)
        addr_a      : in  sbox_addr_t;
        data_in_a   : in  byte_t;
        we_a        : in  std_logic;
        data_out_a  : out byte_t;

        -- Port B (Read/Write)
        addr_b      : in  sbox_addr_t;
        data_in_b   : in  byte_t;
        we_b        : in  std_logic;
        data_out_b  : out byte_t
    );
end entity sbox_ram;

architecture rtl of sbox_ram is
    -- S-box memory (will be inferred as Block RAM in Spartan-3)
    signal sbox_mem : sbox_mem_t := (others => (others => '0'));

    -- Registered outputs for synchronous read (initialized to avoid 'U' warnings)
    signal data_out_a_reg : byte_t := (others => '0');
    signal data_out_b_reg : byte_t := (others => '0');

begin
    -- Port A process
    process(clk)
    begin
        if rising_edge(clk) then
            if we_a = '1' then
                sbox_mem(conv_integer(addr_a)) <= data_in_a;
            end if;
            data_out_a_reg <= sbox_mem(conv_integer(addr_a));
        end if;
    end process;

    -- Port B process
    process(clk)
    begin
        if rising_edge(clk) then
            if we_b = '1' then
                sbox_mem(conv_integer(addr_b)) <= data_in_b;
            end if;
            data_out_b_reg <= sbox_mem(conv_integer(addr_b));
        end if;
    end process;

    -- Output assignments
    data_out_a <= data_out_a_reg;
    data_out_b <= data_out_b_reg;

end architecture rtl;
