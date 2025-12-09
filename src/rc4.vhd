--------------------------------------------------------------------------------
-- RC4 Cipher - Main Module
-- Implements RC4 stream cipher with KSA and PRGA phases
--
-- Algorithm:
--   KSA (Key-Scheduling Algorithm):
--     1. Initialize S[i] = i for i = 0..255
--     2. j = 0
--     3. For i = 0 to 255:
--        j = (j + S[i] + Key[i mod key_len]) mod 256
--        swap(S[i], S[j])
--
--   PRGA (Pseudo-Random Generation Algorithm):
--     1. i = j = 0
--     2. For each byte:
--        i = (i + 1) mod 256
--        j = (j + S[i]) mod 256
--        swap(S[i], S[j])
--        t = (S[i] + S[j]) mod 256
--        K = S[t]
--        output = input XOR K
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.rc4_pkg.all;

entity rc4 is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Control signals
        start       : in  std_logic;                    -- Start KSA
        key_len     : in  unsigned(7 downto 0);         -- Key length (1-256)
        key_data    : in  byte_t;                       -- Key byte input
        key_addr    : out unsigned(7 downto 0);         -- Key address request

        -- Data interface (for encryption/decryption)
        data_in     : in  byte_t;                       -- Input byte (plaintext/ciphertext)
        data_valid  : in  std_logic;                    -- Input data valid
        data_out    : out byte_t;                       -- Output byte (ciphertext/plaintext)
        data_ready  : out std_logic;                    -- Output data ready

        -- Status
        busy        : out std_logic;                    -- Module is busy (KSA in progress)
        ready       : out std_logic                     -- Ready to encrypt/decrypt
    );
end entity rc4;

architecture rtl of rc4 is
    -- FSM state
    signal state        : rc4_state_t := IDLE;
    signal next_state   : rc4_state_t;

    -- S-box RAM signals
    signal sbox_addr_a  : sbox_addr_t := (others => '0');
    signal sbox_din_a   : byte_t := (others => '0');
    signal sbox_we_a    : std_logic := '0';
    signal sbox_dout_a  : byte_t;

    signal sbox_addr_b  : sbox_addr_t := (others => '0');
    signal sbox_din_b   : byte_t := (others => '0');
    signal sbox_we_b    : std_logic := '0';
    signal sbox_dout_b  : byte_t;

    -- Internal counters and registers
    signal i_cnt        : unsigned(8 downto 0) := (others => '0');  -- 9-bit for 0-256 range
    signal j_cnt        : unsigned(7 downto 0) := (others => '0');

    -- Temporary registers for swap operations
    signal si_reg       : byte_t := (others => '0');   -- S[i] value
    signal sj_reg       : byte_t := (others => '0');   -- S[j] value
    signal t_reg        : unsigned(7 downto 0) := (others => '0');  -- t index

    -- Key length register
    signal key_len_reg  : unsigned(7 downto 0) := (others => '0');

    -- Keystream byte
    signal keystream    : byte_t := (others => '0');

    -- Output register
    signal data_out_reg : byte_t := (others => '0');
    signal data_rdy_reg : std_logic := '0';

begin

    -- S-box RAM instantiation
    sbox_inst : entity work.sbox_ram
        port map (
            clk         => clk,
            addr_a      => sbox_addr_a,
            data_in_a   => sbox_din_a,
            we_a        => sbox_we_a,
            data_out_a  => sbox_dout_a,
            addr_b      => sbox_addr_b,
            data_in_b   => sbox_din_b,
            we_b        => sbox_we_b,
            data_out_b  => sbox_dout_b
        );

    -- Output assignments
    data_out    <= data_out_reg;
    data_ready  <= data_rdy_reg;
    busy        <= '1' when state /= IDLE and state /= PRGA_READY else '0';
    ready       <= '1' when state = PRGA_READY else '0';

    -- Key address output (for external key ROM/RAM)
    key_addr    <= i_cnt(7 downto 0) mod key_len_reg when key_len_reg /= 0 else (others => '0');

    -- Main FSM process
    fsm_proc : process(clk)
        variable j_temp : unsigned(8 downto 0);
        variable t_temp : unsigned(8 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state       <= IDLE;
                i_cnt       <= (others => '0');
                j_cnt       <= (others => '0');
                si_reg      <= (others => '0');
                sj_reg      <= (others => '0');
                t_reg       <= (others => '0');
                key_len_reg <= (others => '0');
                data_out_reg<= (others => '0');
                data_rdy_reg<= '0';
                sbox_we_a   <= '0';
                sbox_we_b   <= '0';
            else
                -- Default values
                sbox_we_a   <= '0';
                sbox_we_b   <= '0';
                data_rdy_reg<= '0';

                case state is
                    ----------------------------------------------------------
                    -- IDLE: Wait for start signal
                    ----------------------------------------------------------
                    when IDLE =>
                        if start = '1' then
                            key_len_reg <= key_len;
                            i_cnt       <= (others => '0');
                            j_cnt       <= (others => '0');
                            state       <= KSA_INIT;
                        end if;

                    ----------------------------------------------------------
                    -- KSA Phase: Initialize S-box
                    ----------------------------------------------------------
                    when KSA_INIT =>
                        -- Write S[i] = i
                        sbox_addr_a <= i_cnt(7 downto 0);
                        sbox_din_a  <= std_logic_vector(i_cnt(7 downto 0));
                        sbox_we_a   <= '1';

                        if i_cnt = 255 then
                            i_cnt <= (others => '0');
                            state <= KSA_READ_SI;
                        else
                            i_cnt <= i_cnt + 1;
                        end if;

                    when KSA_READ_SI =>
                        -- Read S[i]
                        sbox_addr_a <= i_cnt(7 downto 0);
                        state <= KSA_CALC_J;

                    when KSA_CALC_J =>
                        -- j = (j + S[i] + Key[i mod key_len]) mod 256
                        si_reg <= sbox_dout_a;
                        j_temp := ('0' & j_cnt) + ('0' & unsigned(sbox_dout_a)) + ('0' & unsigned(key_data));
                        j_cnt  <= j_temp(7 downto 0);

                        -- Setup read of S[j]
                        sbox_addr_b <= j_temp(7 downto 0);
                        state <= KSA_READ_SJ;

                    when KSA_READ_SJ =>
                        -- Wait for S[j] read
                        state <= KSA_SWAP;

                    when KSA_SWAP =>
                        -- Read S[j] value
                        sj_reg <= sbox_dout_b;
                        state <= KSA_WRITE_SI;

                    when KSA_WRITE_SI =>
                        -- Write S[j] to S[i] position (swap part 1)
                        sbox_addr_a <= i_cnt(7 downto 0);
                        sbox_din_a  <= sj_reg;
                        sbox_we_a   <= '1';
                        state <= KSA_WRITE_SJ;

                    when KSA_WRITE_SJ =>
                        -- Write S[i] to S[j] position (swap part 2)
                        sbox_addr_b <= j_cnt;
                        sbox_din_b  <= si_reg;
                        sbox_we_b   <= '1';
                        state <= KSA_NEXT;

                    when KSA_NEXT =>
                        -- Check if KSA is complete
                        if i_cnt = 255 then
                            -- KSA complete, reset counters for PRGA
                            i_cnt <= (others => '0');
                            j_cnt <= (others => '0');
                            state <= PRGA_READY;
                        else
                            i_cnt <= i_cnt + 1;
                            state <= KSA_READ_SI;
                        end if;

                    ----------------------------------------------------------
                    -- PRGA Phase: Generate keystream and encrypt/decrypt
                    ----------------------------------------------------------
                    when PRGA_READY =>
                        -- Wait for input data
                        if data_valid = '1' then
                            state <= PRGA_CALC_I;
                        end if;

                    when PRGA_CALC_I =>
                        -- i = (i + 1) mod 256
                        i_cnt <= ('0' & i_cnt(7 downto 0)) + 1;
                        state <= PRGA_READ_SI;

                    when PRGA_READ_SI =>
                        -- Read S[i]
                        sbox_addr_a <= i_cnt(7 downto 0);
                        state <= PRGA_CALC_J;

                    when PRGA_CALC_J =>
                        -- j = (j + S[i]) mod 256
                        si_reg <= sbox_dout_a;
                        j_temp := ('0' & j_cnt) + ('0' & unsigned(sbox_dout_a));
                        j_cnt  <= j_temp(7 downto 0);

                        -- Setup read of S[j]
                        sbox_addr_b <= j_temp(7 downto 0);
                        state <= PRGA_READ_SJ;

                    when PRGA_READ_SJ =>
                        -- Wait for S[j] read
                        state <= PRGA_SWAP;

                    when PRGA_SWAP =>
                        -- Read S[j] value
                        sj_reg <= sbox_dout_b;
                        state <= PRGA_WRITE_SI;

                    when PRGA_WRITE_SI =>
                        -- Write S[j] to S[i] position
                        sbox_addr_a <= i_cnt(7 downto 0);
                        sbox_din_a  <= sj_reg;
                        sbox_we_a   <= '1';
                        state <= PRGA_WRITE_SJ;

                    when PRGA_WRITE_SJ =>
                        -- Write S[i] to S[j] position
                        sbox_addr_b <= j_cnt;
                        sbox_din_b  <= si_reg;
                        sbox_we_b   <= '1';
                        state <= PRGA_CALC_T;

                    when PRGA_CALC_T =>
                        -- t = (S[i] + S[j]) mod 256
                        -- Note: After swap, si_reg has old S[i], sj_reg has old S[j]
                        -- But S[i] now contains sj_reg and S[j] contains si_reg
                        t_temp := ('0' & unsigned(sj_reg)) + ('0' & unsigned(si_reg));
                        t_reg  <= t_temp(7 downto 0);

                        -- Read S[t]
                        sbox_addr_a <= t_temp(7 downto 0);
                        state <= PRGA_READ_ST;

                    when PRGA_READ_ST =>
                        -- Wait for S[t] read
                        state <= PRGA_OUTPUT;

                    when PRGA_OUTPUT =>
                        -- K = S[t], output = input XOR K
                        keystream    <= sbox_dout_a;
                        data_out_reg <= data_in xor sbox_dout_a;
                        data_rdy_reg <= '1';
                        state <= PRGA_READY;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process fsm_proc;

end architecture rtl;
