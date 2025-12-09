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

end package rc4_pkg;

package body rc4_pkg is
    -- Package body (empty for now)
end package body rc4_pkg;
