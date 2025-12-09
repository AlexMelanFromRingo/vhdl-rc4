--------------------------------------------------------------------------------
-- RC4 Package - Types and Constants
-- Compatible with Xilinx ISE 8.1i (VHDL-93)
-- For Spartan-3 FPGA
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package rc4_pkg is
    -- Constants
    constant SBOX_SIZE      : integer := 256;
    constant SBOX_ADDR_WIDTH: integer := 8;
    constant DATA_WIDTH     : integer := 8;
    constant MAX_KEY_LENGTH : integer := 256;

    -- Types
    subtype byte_t is std_logic_vector(7 downto 0);
    subtype sbox_addr_t is std_logic_vector(7 downto 0);

    -- S-box memory type
    type sbox_mem_t is array (0 to SBOX_SIZE-1) of byte_t;

    -- Hex conversion functions (for testbench output)
    function nibble_to_hex(nibble : std_logic_vector(3 downto 0)) return character;
    function byte_to_hex(byte_val : std_logic_vector(7 downto 0)) return string;

end package rc4_pkg;

package body rc4_pkg is

    function nibble_to_hex(nibble : std_logic_vector(3 downto 0)) return character is
    begin
        case nibble is
            when "0000" => return '0';
            when "0001" => return '1';
            when "0010" => return '2';
            when "0011" => return '3';
            when "0100" => return '4';
            when "0101" => return '5';
            when "0110" => return '6';
            when "0111" => return '7';
            when "1000" => return '8';
            when "1001" => return '9';
            when "1010" => return 'A';
            when "1011" => return 'B';
            when "1100" => return 'C';
            when "1101" => return 'D';
            when "1110" => return 'E';
            when "1111" => return 'F';
            when others => return 'X';
        end case;
    end function;

    function byte_to_hex(byte_val : std_logic_vector(7 downto 0)) return string is
        variable result : string(1 to 2);
    begin
        result(1) := nibble_to_hex(byte_val(7 downto 4));
        result(2) := nibble_to_hex(byte_val(3 downto 0));
        return result;
    end function;

end package body rc4_pkg;
