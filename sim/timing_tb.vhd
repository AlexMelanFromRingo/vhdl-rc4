-- =====================================================================
--  Вимірювання латентності ядер (у тактах)
--  Автор: Alex Melan
--
--  Рахує такти між key_start і key_ready (розгортання ключа) та між
--  start і done (обробка блока). Числа з цього тестбенча наведені
--  в таблиці README.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gost_package.all;

entity timing_tb is
end entity timing_tb;

architecture Behavioral of timing_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal sim_done : boolean := false;
    signal cyc      : natural := 0;

    -- GOST 28147-89
    signal g_start, g_done : std_logic := '0';
    signal g_dout : unsigned(63 downto 0);

    -- Kuznyechik
    signal z_ks, z_kr, z_st, z_dn : std_logic := '0';
    signal z_dout : unsigned(127 downto 0);

    -- Kalyna 128/128 та 512/512
    signal a_ks, a_kr, a_st, a_dn : std_logic := '0';
    signal a_dout : unsigned(127 downto 0);
    signal b_ks, b_kr, b_st, b_dn : std_logic := '0';
    signal b_dout : unsigned(511 downto 0);

    -- Strumok
    signal s_init, s_rdy, s_en, s_v : std_logic := '0';
    signal s_ks : unsigned(63 downto 0);

begin

    GOSTC : entity work.gost_cipher
        generic map (SBOX => S_TC26_Z)
        port map (clk => clk, reset => reset, start => g_start, decrypt => '0',
                  key_in => (255 downto 0 => '0'), data_in => (63 downto 0 => '0'),
                  data_out => g_dout, done => g_done, busy => open);

    KUZ : entity work.kuznyechik_cipher
        port map (clk => clk, reset => reset, key_in => (255 downto 0 => '0'),
                  key_start => z_ks, key_ready => z_kr, start => z_st, decrypt => '0',
                  data_in => (127 downto 0 => '0'), data_out => z_dout,
                  done => z_dn, busy => open);

    KAL2 : entity work.kalyna_cipher
        generic map (NB => 2, NK => 2)
        port map (clk => clk, reset => reset, key_in => (127 downto 0 => '0'),
                  key_start => a_ks, key_ready => a_kr, start => a_st, decrypt => '0',
                  data_in => (127 downto 0 => '0'), data_out => a_dout,
                  done => a_dn, busy => open);

    KAL8 : entity work.kalyna_cipher
        generic map (NB => 8, NK => 8)
        port map (clk => clk, reset => reset, key_in => (511 downto 0 => '0'),
                  key_start => b_ks, key_ready => b_kr, start => b_st, decrypt => '0',
                  data_in => (511 downto 0 => '0'), data_out => b_dout,
                  done => b_dn, busy => open);

    STR : entity work.strumok_cipher
        generic map (KEY_WORDS => 4)
        port map (clk => clk, reset => reset, key_in => (255 downto 0 => '0'),
                  iv_in => (255 downto 0 => '0'), init => s_init, ready => s_rdy,
                  en => s_en, data_in => (63 downto 0 => '0'),
                  ks_out => s_ks, data_out => open, valid => s_v);

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    cyc_process : process(clk)
    begin
        if rising_edge(clk) then
            cyc <= cyc + 1;
        end if;
    end process;

    stim_process : process
        variable t0 : natural;
        procedure say(msg : string; n : natural) is
        begin
            report msg & ": " & integer'image(n) & " cycles" severity note;
        end procedure say;
    begin
        report "=== core latency (cycles) ===" severity note;
        reset <= '1'; wait for CLK_PERIOD * 3; reset <= '0';
        wait until rising_edge(clk);

        -- GOST: ключ не розгортається, лише блок
        t0 := cyc;
        g_start <= '1'; wait until rising_edge(clk); g_start <= '0';
        wait until g_done = '1';
        say("GOST 28147-89   block (64 bit) ", cyc - t0);

        -- Kuznyechik
        wait until rising_edge(clk);
        t0 := cyc;
        z_ks <= '1'; wait until rising_edge(clk); z_ks <= '0';
        wait until z_kr = '1';
        say("Kuznyechik      key schedule   ", cyc - t0);
        wait until rising_edge(clk);
        t0 := cyc;
        z_st <= '1'; wait until rising_edge(clk); z_st <= '0';
        wait until z_dn = '1';
        say("Kuznyechik      block (128 bit)", cyc - t0);

        -- Kalyna 128/128
        wait until rising_edge(clk);
        t0 := cyc;
        a_ks <= '1'; wait until rising_edge(clk); a_ks <= '0';
        wait until a_kr = '1';
        say("Kalyna-128/128  key schedule   ", cyc - t0);
        wait until rising_edge(clk);
        t0 := cyc;
        a_st <= '1'; wait until rising_edge(clk); a_st <= '0';
        wait until a_dn = '1';
        say("Kalyna-128/128  block (128 bit)", cyc - t0);

        -- Kalyna 512/512
        wait until rising_edge(clk);
        t0 := cyc;
        b_ks <= '1'; wait until rising_edge(clk); b_ks <= '0';
        wait until b_kr = '1';
        say("Kalyna-512/512  key schedule   ", cyc - t0);
        wait until rising_edge(clk);
        t0 := cyc;
        b_st <= '1'; wait until rising_edge(clk); b_st <= '0';
        wait until b_dn = '1';
        say("Kalyna-512/512  block (512 bit)", cyc - t0);

        -- Strumok
        wait until rising_edge(clk);
        t0 := cyc;
        s_init <= '1'; wait until rising_edge(clk); s_init <= '0';
        wait until s_rdy = '1';
        say("Strumok-256     init           ", cyc - t0);
        s_en <= '1';
        t0 := cyc;
        wait until s_v = '1';
        say("Strumok-256     first word     ", cyc - t0);
        t0 := cyc;
        for i in 1 to 8 loop
            wait until rising_edge(clk);
        end loop;
        say("Strumok-256     8 more words   ", cyc - t0);
        s_en <= '0';

        report "=== done ===" severity note;
        sim_done <= true;
        wait;
    end process;

end architecture Behavioral;
