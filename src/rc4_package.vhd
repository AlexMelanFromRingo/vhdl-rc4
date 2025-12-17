-- RC4 Package: Types and constants
-- Author: Alex Melan
-- Project: RC4 Stream Cipher Implementation

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package rc4_package is
    -- Constants
    constant SBOX_SIZE : integer := 256;
    constant MAX_KEY_LEN : integer := 256;

    -- S-box type (256 bytes)
    type sbox_type is array (0 to SBOX_SIZE-1) of unsigned(7 downto 0);

    -- Key memory type (up to 256 bytes)
    type key_type is array (0 to MAX_KEY_LEN-1) of unsigned(7 downto 0);

    -- FSM states
    type state_type is (
        IDLE,           -- Waiting for start
        INIT_SBOX,      -- S-box initialization (S[i] = i)
        KSA_PROCESS,    -- Key-Scheduling Algorithm
        PRGA_READY,     -- Ready for encryption/decryption
        PRGA_I_UPDATE,  -- Update index i
        PRGA_J_UPDATE,  -- Update index j
        PRGA_SWAP,      -- Swap S[i] and S[j]
        PRGA_OUTPUT,    -- Generate output byte
        DONE            -- Operation complete
    );

end package rc4_package;

package body rc4_package is
end package body rc4_package;
