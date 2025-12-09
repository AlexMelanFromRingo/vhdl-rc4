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
    constant SBOX_SIZE      : integer := 256;   -- S-box size (256 bytes)
    constant SBOX_ADDR_WIDTH: integer := 8;     -- Address width for S-box
    constant DATA_WIDTH     : integer := 8;     -- Data width (1 byte)
    constant MAX_KEY_LENGTH : integer := 256;   -- Maximum key length in bytes

    -- Types
    subtype byte_t is std_logic_vector(7 downto 0);
    subtype sbox_addr_t is std_logic_vector(7 downto 0);

    -- Key array type (variable length key support)
    type key_array_t is array (0 to MAX_KEY_LENGTH-1) of byte_t;

    -- S-box memory type
    type sbox_mem_t is array (0 to SBOX_SIZE-1) of byte_t;

    -- RC4 FSM States
    type rc4_state_t is (
        IDLE,           -- Waiting for start signal
        -- KSA (Key-Scheduling Algorithm) states
        KSA_INIT,       -- Initialize S[i] = i
        KSA_CALC_J,     -- Calculate j = (j + S[i] + Key[i mod key_len]) mod 256
        KSA_READ_SI,    -- Read S[i]
        KSA_READ_SJ,    -- Read S[j]
        KSA_SWAP,       -- Swap S[i] and S[j]
        KSA_WRITE_SI,   -- Write new S[i]
        KSA_WRITE_SJ,   -- Write new S[j]
        KSA_NEXT,       -- Increment i, check if done
        -- PRGA (Pseudo-Random Generation Algorithm) states
        PRGA_READY,     -- Ready to encrypt/decrypt
        PRGA_CALC_I,    -- i = (i + 1) mod 256
        PRGA_READ_SI,   -- Read S[i]
        PRGA_CALC_J,    -- j = (j + S[i]) mod 256
        PRGA_READ_SJ,   -- Read S[j]
        PRGA_SWAP,      -- Swap S[i] and S[j]
        PRGA_WRITE_SI,  -- Write new S[i]
        PRGA_WRITE_SJ,  -- Write new S[j]
        PRGA_CALC_T,    -- t = (S[i] + S[j]) mod 256
        PRGA_READ_ST,   -- Read S[t] - this is the keystream byte
        PRGA_OUTPUT     -- XOR with input byte and output
    );

    -- Function to convert nibble to hex character (for simulation output)
    function nibble_to_hex(nibble : std_logic_vector(3 downto 0)) return character;

    -- Function to convert byte to hex string (for simulation output)
    function byte_to_hex(byte_val : std_logic_vector(7 downto 0)) return string;

end package rc4_pkg;

package body rc4_pkg is

    -- Convert 4-bit nibble to hex character
    function nibble_to_hex(nibble : std_logic_vector(3 downto 0)) return character is
        variable result : character;
    begin
        case nibble is
            when "0000" => result := '0';
            when "0001" => result := '1';
            when "0010" => result := '2';
            when "0011" => result := '3';
            when "0100" => result := '4';
            when "0101" => result := '5';
            when "0110" => result := '6';
            when "0111" => result := '7';
            when "1000" => result := '8';
            when "1001" => result := '9';
            when "1010" => result := 'A';
            when "1011" => result := 'B';
            when "1100" => result := 'C';
            when "1101" => result := 'D';
            when "1110" => result := 'E';
            when "1111" => result := 'F';
            when others => result := 'X';
        end case;
        return result;
    end function nibble_to_hex;

    -- Convert byte to 2-character hex string
    function byte_to_hex(byte_val : std_logic_vector(7 downto 0)) return string is
        variable result : string(1 to 2);
    begin
        result(1) := nibble_to_hex(byte_val(7 downto 4));
        result(2) := nibble_to_hex(byte_val(3 downto 0));
        return result;
    end function byte_to_hex;

end package body rc4_pkg;
