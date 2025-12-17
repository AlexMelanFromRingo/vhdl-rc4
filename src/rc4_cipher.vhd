-- RC4 Stream Cipher: Full Implementation
-- Author: Alex Melan
-- Target: Xilinx Spartan-3 / ISE 8.1i
--
-- Description:
--   Complete RC4 stream cipher implementation with:
--   - KSA (Key-Scheduling Algorithm): 256 iterations
--   - PRGA (Pseudo-Random Generation Algorithm): 4 cycles per byte
--   - Support for keys from 1 to 255 bytes
--   - Synthesizable design (no mod operator with variable)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rc4_package.all;

entity rc4_cipher is
    Port (
        clk         : in  std_logic;
        reset       : in  std_logic;

        -- Control signals
        start       : in  std_logic;
        key_length  : in  unsigned(7 downto 0);

        -- Key input
        key_in      : in  unsigned(7 downto 0);
        key_valid   : in  std_logic;

        -- Data input/output
        data_in     : in  unsigned(7 downto 0);
        data_valid  : in  std_logic;
        data_out    : out unsigned(7 downto 0);
        data_ready  : out std_logic;

        -- Status
        busy        : out std_logic;
        ksa_done    : out std_logic
    );
end rc4_cipher;

architecture Behavioral of rc4_cipher is
    -- S-box memory (256 bytes)
    signal sbox : sbox_type;

    -- Key storage
    signal key_mem : key_type;
    signal key_len : unsigned(7 downto 0);
    signal key_idx : unsigned(7 downto 0);
    signal ksa_key_idx : unsigned(7 downto 0);  -- Key index for KSA (cyclic counter)

    -- RC4 indices and counters
    signal i, j : unsigned(7 downto 0);
    signal cnt : unsigned(7 downto 0);

    -- Temporary values
    signal si, sj : unsigned(7 downto 0);
    signal t_val : unsigned(7 downto 0);

    -- FSM state
    signal state : state_type;

begin

    process(clk, reset)
        variable new_j : unsigned(7 downto 0);
    begin
        if reset = '1' then
            state <= IDLE;
            cnt <= (others => '0');
            i <= (others => '0');
            j <= (others => '0');
            key_idx <= (others => '0');
            ksa_key_idx <= (others => '0');
            data_out <= (others => '0');
            data_ready <= '0';
            busy <= '0';
            ksa_done <= '0';

        elsif rising_edge(clk) then
            data_ready <= '0';

            case state is
                -- Idle state: waiting for start signal
                when IDLE =>
                    busy <= '0';
                    ksa_done <= '0';
                    cnt <= (others => '0');
                    i <= (others => '0');
                    j <= (others => '0');
                    key_idx <= (others => '0');
                    ksa_key_idx <= (others => '0');

                    if start = '1' then
                        key_len <= key_length;
                        busy <= '1';
                        state <= INIT_SBOX;
                    end if;

                -- S-box initialization: S[i] = i for i = 0..255
                when INIT_SBOX =>
                    sbox(to_integer(cnt)) <= cnt;

                    -- Load key bytes in parallel
                    if key_valid = '1' and key_idx < key_len then
                        key_mem(to_integer(key_idx)) <= key_in;
                        key_idx <= key_idx + 1;
                    end if;

                    if cnt = 255 then
                        cnt <= (others => '0');
                        j <= (others => '0');
                        state <= KSA_PROCESS;
                    else
                        cnt <= cnt + 1;
                    end if;

                -- KSA: Key-Scheduling Algorithm
                -- for i = 0 to 255:
                --   j = (j + S[i] + key[i mod keylen]) mod 256
                --   swap(S[i], S[j])
                when KSA_PROCESS =>
                    si <= sbox(to_integer(cnt));

                    -- Calculate new j using cyclic key index
                    new_j := j + sbox(to_integer(cnt)) +
                             key_mem(to_integer(ksa_key_idx));

                    sj <= sbox(to_integer(new_j));

                    -- Swap S[cnt] and S[new_j]
                    sbox(to_integer(cnt)) <= sbox(to_integer(new_j));
                    sbox(to_integer(new_j)) <= sbox(to_integer(cnt));

                    j <= new_j;

                    -- Update key index (cyclic counter instead of mod)
                    if ksa_key_idx = key_len - 1 then
                        ksa_key_idx <= (others => '0');
                    else
                        ksa_key_idx <= ksa_key_idx + 1;
                    end if;

                    if cnt = 255 then
                        ksa_done <= '1';
                        i <= (others => '0');
                        j <= (others => '0');
                        state <= PRGA_READY;
                    else
                        cnt <= cnt + 1;
                    end if;

                -- PRGA ready: waiting for data to encrypt/decrypt
                when PRGA_READY =>
                    if data_valid = '1' then
                        state <= PRGA_I_UPDATE;
                    end if;

                -- PRGA step 1: i = (i + 1) mod 256
                when PRGA_I_UPDATE =>
                    i <= i + 1;
                    si <= sbox(to_integer(i + 1));
                    state <= PRGA_J_UPDATE;

                -- PRGA step 2: j = (j + S[i]) mod 256
                when PRGA_J_UPDATE =>
                    j <= j + si;
                    sj <= sbox(to_integer(j + si));
                    state <= PRGA_SWAP;

                -- PRGA step 3: swap(S[i], S[j])
                when PRGA_SWAP =>
                    sbox(to_integer(i)) <= sj;
                    sbox(to_integer(j)) <= si;

                    -- t = (S[i] + S[j]) mod 256
                    t_val <= si + sj;
                    state <= PRGA_OUTPUT;

                -- PRGA step 4: output = input XOR S[t]
                when PRGA_OUTPUT =>
                    data_out <= data_in xor sbox(to_integer(t_val));
                    data_ready <= '1';
                    state <= PRGA_READY;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;
