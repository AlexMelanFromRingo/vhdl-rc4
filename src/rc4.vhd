--------------------------------------------------------------------------------
-- RC4 Cipher - Main Module (OPTIMIZED)
-- Compatible with Xilinx ISE 8.1i (VHDL-93)
-- For Spartan-3 FPGA
--
-- OPTIMIZED FSM: Reduced from 20 states to 10 states
-- KSA now takes ~1024 cycles instead of ~2048 cycles
--
-- Algorithm:
--   KSA: Initialize S[i]=i, then for i=0..255: swap(S[i], S[j])
--   PRGA: Generate keystream byte K = S[(S[i]+S[j]) mod 256]
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.rc4_pkg.ALL;

entity rc4 is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Control signals
        start       : in  std_logic;
        key_len     : in  std_logic_vector(7 downto 0);
        key_data    : in  byte_t;
        key_addr    : out std_logic_vector(7 downto 0);

        -- Data interface
        data_in     : in  byte_t;
        data_valid  : in  std_logic;
        data_out    : out byte_t;
        data_ready  : out std_logic;

        -- Status
        busy        : out std_logic;
        ready       : out std_logic
    );
end entity rc4;

architecture rtl of rc4 is
    -- Optimized FSM states (reduced count)
    type state_t is (
        ST_IDLE,
        ST_KSA_INIT,        -- Initialize S[i] = i
        ST_KSA_READ,        -- Read S[i], calculate j
        ST_KSA_READ_J,      -- Read S[j]
        ST_KSA_SWAP,        -- Write swapped values (both ports)
        ST_PRGA_READY,      -- Ready for data
        ST_PRGA_READ_I,     -- Read S[i]
        ST_PRGA_READ_J,     -- Read S[j]
        ST_PRGA_SWAP,       -- Swap and calculate t
        ST_PRGA_OUTPUT      -- Read S[t] and output
    );

    signal state : state_t := ST_IDLE;

    -- S-box RAM signals (initialized)
    signal sbox_addr_a  : sbox_addr_t := (others => '0');
    signal sbox_din_a   : byte_t := (others => '0');
    signal sbox_we_a    : std_logic := '0';
    signal sbox_dout_a  : byte_t;

    signal sbox_addr_b  : sbox_addr_t := (others => '0');
    signal sbox_din_b   : byte_t := (others => '0');
    signal sbox_we_b    : std_logic := '0';
    signal sbox_dout_b  : byte_t;

    -- Counters (initialized)
    signal i_cnt        : std_logic_vector(8 downto 0) := (others => '0');
    signal j_cnt        : std_logic_vector(7 downto 0) := (others => '0');

    -- Registers (initialized)
    signal si_reg       : byte_t := (others => '0');
    signal sj_reg       : byte_t := (others => '0');
    signal key_len_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal key_idx_reg  : std_logic_vector(7 downto 0) := (others => '0');

    -- Output (initialized)
    signal data_out_reg : byte_t := (others => '0');
    signal data_rdy_reg : std_logic := '0';

begin

    -- S-box RAM
    sbox_inst : entity work.sbox_ram
        port map (
            clk => clk,
            addr_a => sbox_addr_a, data_in_a => sbox_din_a,
            we_a => sbox_we_a, data_out_a => sbox_dout_a,
            addr_b => sbox_addr_b, data_in_b => sbox_din_b,
            we_b => sbox_we_b, data_out_b => sbox_dout_b
        );

    -- Outputs
    data_out   <= data_out_reg;
    data_ready <= data_rdy_reg;
    busy       <= '0' when (state = ST_IDLE or state = ST_PRGA_READY) else '1';
    ready      <= '1' when state = ST_PRGA_READY else '0';
    key_addr   <= key_idx_reg;

    -- Main FSM
    process(clk)
        variable j_new : std_logic_vector(8 downto 0);
        variable t_idx : std_logic_vector(8 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state        <= ST_IDLE;
                i_cnt        <= (others => '0');
                j_cnt        <= (others => '0');
                si_reg       <= (others => '0');
                sj_reg       <= (others => '0');
                key_len_reg  <= (others => '0');
                key_idx_reg  <= (others => '0');
                data_out_reg <= (others => '0');
                data_rdy_reg <= '0';
                sbox_we_a    <= '0';
                sbox_we_b    <= '0';
                sbox_addr_a  <= (others => '0');
                sbox_addr_b  <= (others => '0');
                sbox_din_a   <= (others => '0');
                sbox_din_b   <= (others => '0');
            else
                -- Defaults
                sbox_we_a    <= '0';
                sbox_we_b    <= '0';
                data_rdy_reg <= '0';

                case state is
                    --------------------------------------------------------
                    when ST_IDLE =>
                        if start = '1' then
                            key_len_reg <= key_len;
                            i_cnt       <= (others => '0');
                            j_cnt       <= (others => '0');
                            key_idx_reg <= (others => '0');
                            state       <= ST_KSA_INIT;
                        end if;

                    --------------------------------------------------------
                    -- KSA INIT: Write S[i] = i
                    --------------------------------------------------------
                    when ST_KSA_INIT =>
                        sbox_addr_a <= i_cnt(7 downto 0);
                        sbox_din_a  <= i_cnt(7 downto 0);
                        sbox_we_a   <= '1';

                        if i_cnt(7 downto 0) = x"FF" then
                            i_cnt       <= (others => '0');
                            key_idx_reg <= (others => '0');
                            state       <= ST_KSA_READ;
                        else
                            i_cnt <= i_cnt + 1;
                        end if;

                    --------------------------------------------------------
                    -- KSA READ: Read S[i], setup key index
                    --------------------------------------------------------
                    when ST_KSA_READ =>
                        sbox_addr_a <= i_cnt(7 downto 0);
                        -- key_idx_reg is already set from previous cycle
                        state <= ST_KSA_READ_J;

                    --------------------------------------------------------
                    -- KSA READ_J: Calculate j, read S[j]
                    --------------------------------------------------------
                    when ST_KSA_READ_J =>
                        si_reg <= sbox_dout_a;
                        -- j = (j + S[i] + Key[key_idx]) mod 256
                        j_new := ('0' & j_cnt) + ('0' & sbox_dout_a) + ('0' & key_data);
                        j_cnt <= j_new(7 downto 0);
                        sbox_addr_b <= j_new(7 downto 0);
                        state <= ST_KSA_SWAP;

                    --------------------------------------------------------
                    -- KSA SWAP: Write both S[i] and S[j] simultaneously
                    --------------------------------------------------------
                    when ST_KSA_SWAP =>
                        sj_reg <= sbox_dout_b;
                        -- Swap: S[i] = S[j], S[j] = S[i]
                        sbox_addr_a <= i_cnt(7 downto 0);
                        sbox_din_a  <= sbox_dout_b;  -- S[j] -> S[i]
                        sbox_we_a   <= '1';
                        sbox_addr_b <= j_cnt;
                        sbox_din_b  <= si_reg;      -- S[i] -> S[j]
                        sbox_we_b   <= '1';

                        -- Update key index for next iteration
                        if key_idx_reg = key_len_reg - 1 then
                            key_idx_reg <= (others => '0');
                        else
                            key_idx_reg <= key_idx_reg + 1;
                        end if;

                        -- Check if done
                        if i_cnt(7 downto 0) = x"FF" then
                            i_cnt <= (others => '0');
                            j_cnt <= (others => '0');
                            state <= ST_PRGA_READY;
                        else
                            i_cnt <= i_cnt + 1;
                            state <= ST_KSA_READ;
                        end if;

                    --------------------------------------------------------
                    -- PRGA READY: Wait for data
                    --------------------------------------------------------
                    when ST_PRGA_READY =>
                        if data_valid = '1' then
                            -- i = (i + 1) mod 256
                            i_cnt <= ('0' & i_cnt(7 downto 0)) + 1;
                            state <= ST_PRGA_READ_I;
                        end if;

                    --------------------------------------------------------
                    -- PRGA READ_I: Read S[i]
                    --------------------------------------------------------
                    when ST_PRGA_READ_I =>
                        sbox_addr_a <= i_cnt(7 downto 0);
                        state <= ST_PRGA_READ_J;

                    --------------------------------------------------------
                    -- PRGA READ_J: Calculate j, read S[j]
                    --------------------------------------------------------
                    when ST_PRGA_READ_J =>
                        si_reg <= sbox_dout_a;
                        j_new := ('0' & j_cnt) + ('0' & sbox_dout_a);
                        j_cnt <= j_new(7 downto 0);
                        sbox_addr_b <= j_new(7 downto 0);
                        state <= ST_PRGA_SWAP;

                    --------------------------------------------------------
                    -- PRGA SWAP: Swap and read S[t]
                    --------------------------------------------------------
                    when ST_PRGA_SWAP =>
                        sj_reg <= sbox_dout_b;
                        -- Swap
                        sbox_addr_a <= i_cnt(7 downto 0);
                        sbox_din_a  <= sbox_dout_b;
                        sbox_we_a   <= '1';
                        sbox_addr_b <= j_cnt;
                        sbox_din_b  <= si_reg;
                        sbox_we_b   <= '1';
                        -- Calculate t = (S[i] + S[j]) mod 256 using NEW values
                        t_idx := ('0' & sbox_dout_b) + ('0' & si_reg);
                        sbox_addr_a <= t_idx(7 downto 0);
                        state <= ST_PRGA_OUTPUT;

                    --------------------------------------------------------
                    -- PRGA OUTPUT: Read S[t], XOR with input
                    --------------------------------------------------------
                    when ST_PRGA_OUTPUT =>
                        data_out_reg <= data_in xor sbox_dout_a;
                        data_rdy_reg <= '1';
                        state <= ST_PRGA_READY;

                    when others =>
                        state <= ST_IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
