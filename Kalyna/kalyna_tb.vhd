-- =====================================================================
--  "Калина" (ДСТУ 7624:2014) - самоперевірний тестбенч
--  Автор: Alex Melan
--
--  Перевіряються всі п'ять варіантів стандарту, зашифрування та
--  розшифрування. Вектори взяті з еталонної реалізації авторів
--  стандарту (R. Kiianchuk, R. Mordvinov, R. Oliynykov),
--  https://github.com/rkiyanchuk/kalyna - файл src/main.c.
--
--  ЗАУВАЖЕННЯ: цей файл згенеровано з еталонних векторів, щоб
--  виключити помилки переписування вручну.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;
use work.kalyna_package.all;

entity kalyna_tb is
end entity kalyna_tb;

architecture Behavioral of kalyna_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal sim_done : boolean := false;
    signal errors   : natural := 0;

    signal v22_key  : unsigned(127 downto 0) := (others => '0');
    signal v22_din  : unsigned(127 downto 0) := (others => '0');
    signal v22_dout : unsigned(127 downto 0);
    signal v22_ks, v22_st, v22_dec : std_logic := '0';
    signal v22_kr, v22_dn : std_logic;
    signal v24_key  : unsigned(255 downto 0) := (others => '0');
    signal v24_din  : unsigned(127 downto 0) := (others => '0');
    signal v24_dout : unsigned(127 downto 0);
    signal v24_ks, v24_st, v24_dec : std_logic := '0';
    signal v24_kr, v24_dn : std_logic;
    signal v44_key  : unsigned(255 downto 0) := (others => '0');
    signal v44_din  : unsigned(255 downto 0) := (others => '0');
    signal v44_dout : unsigned(255 downto 0);
    signal v44_ks, v44_st, v44_dec : std_logic := '0';
    signal v44_kr, v44_dn : std_logic;
    signal v48_key  : unsigned(511 downto 0) := (others => '0');
    signal v48_din  : unsigned(255 downto 0) := (others => '0');
    signal v48_dout : unsigned(255 downto 0);
    signal v48_ks, v48_st, v48_dec : std_logic := '0';
    signal v48_kr, v48_dn : std_logic;
    signal v88_key  : unsigned(511 downto 0) := (others => '0');
    signal v88_din  : unsigned(511 downto 0) := (others => '0');
    signal v88_dout : unsigned(511 downto 0);
    signal v88_ks, v88_st, v88_dec : std_logic := '0';
    signal v88_kr, v88_dn : std_logic;

begin

    UUT_22 : entity work.kalyna_cipher
        generic map (NB => 2, NK => 2)
        port map (clk => clk, reset => reset,
                  key_in => v22_key, key_start => v22_ks, key_ready => v22_kr,
                  start => v22_st, decrypt => v22_dec, data_in => v22_din,
                  data_out => v22_dout, done => v22_dn, busy => open);
    UUT_24 : entity work.kalyna_cipher
        generic map (NB => 2, NK => 4)
        port map (clk => clk, reset => reset,
                  key_in => v24_key, key_start => v24_ks, key_ready => v24_kr,
                  start => v24_st, decrypt => v24_dec, data_in => v24_din,
                  data_out => v24_dout, done => v24_dn, busy => open);
    UUT_44 : entity work.kalyna_cipher
        generic map (NB => 4, NK => 4)
        port map (clk => clk, reset => reset,
                  key_in => v44_key, key_start => v44_ks, key_ready => v44_kr,
                  start => v44_st, decrypt => v44_dec, data_in => v44_din,
                  data_out => v44_dout, done => v44_dn, busy => open);
    UUT_48 : entity work.kalyna_cipher
        generic map (NB => 4, NK => 8)
        port map (clk => clk, reset => reset,
                  key_in => v48_key, key_start => v48_ks, key_ready => v48_kr,
                  start => v48_st, decrypt => v48_dec, data_in => v48_din,
                  data_out => v48_dout, done => v48_dn, busy => open);
    UUT_88 : entity work.kalyna_cipher
        generic map (NB => 8, NK => 8)
        port map (clk => clk, reset => reset,
                  key_in => v88_key, key_start => v88_ks, key_ready => v88_kr,
                  start => v88_st, decrypt => v88_dec, data_in => v88_din,
                  data_out => v88_dout, done => v88_dn, busy => open);

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_process : process

        -- Неконстрейнений параметр: одна процедура обслуговує 128/256/512 біт
        procedure check(msg : string; got_v, exp_v : unsigned) is
        begin
            if got_v = exp_v then
                report msg & ": PASS  " & to_hex(got_v) severity note;
            else
                report msg & ": FAIL" severity error;
                report "   got      " & to_hex(got_v) severity error;
                report "   expected " & to_hex(exp_v) severity error;
                errors <= errors + 1;
            end if;
        end procedure check;

    begin
        report "=== Kalyna (DSTU 7624:2014) test start ===" severity note;
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';
        wait for CLK_PERIOD;


        report "--- Kalyna-128/128 ---" severity note;
        v22_key <= x"0f0e0d0c0b0a09080706050403020100";
        wait until rising_edge(clk);
        v22_ks <= '1'; wait until rising_edge(clk); v22_ks <= '0';
        wait until v22_kr = '1'; wait until rising_edge(clk);
        v22_din <= x"1f1e1d1c1b1a19181716151413121110"; v22_dec <= '0';
        wait until rising_edge(clk);
        v22_st <= '1'; wait until rising_edge(clk); v22_st <= '0';
        wait until v22_dn = '1';
        check("Kalyna-128/128 encipher", v22_dout, x"06add2b439eac9e120ac9b777d1cbf81");
        wait until rising_edge(clk);
        v22_key <= x"000102030405060708090a0b0c0d0e0f";
        wait until rising_edge(clk);
        v22_ks <= '1'; wait until rising_edge(clk); v22_ks <= '0';
        wait until v22_kr = '1'; wait until rising_edge(clk);
        v22_din <= x"101112131415161718191a1b1c1d1e1f"; v22_dec <= '1';
        wait until rising_edge(clk);
        v22_st <= '1'; wait until rising_edge(clk); v22_st <= '0';
        wait until v22_dn = '1';
        check("Kalyna-128/128 decipher", v22_dout, x"d7da733930c2096f84c70c472bef9172");
        wait until rising_edge(clk);
        report "--- Kalyna-128/256 ---" severity note;
        v24_key <= x"1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100";
        wait until rising_edge(clk);
        v24_ks <= '1'; wait until rising_edge(clk); v24_ks <= '0';
        wait until v24_kr = '1'; wait until rising_edge(clk);
        v24_din <= x"2f2e2d2c2b2a29282726252423222120"; v24_dec <= '0';
        wait until rising_edge(clk);
        v24_st <= '1'; wait until rising_edge(clk); v24_st <= '0';
        wait until v24_dn = '1';
        check("Kalyna-128/256 encipher", v24_dout, x"144f336f16f748118a150010093eec58");
        wait until rising_edge(clk);
        v24_key <= x"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
        wait until rising_edge(clk);
        v24_ks <= '1'; wait until rising_edge(clk); v24_ks <= '0';
        wait until v24_kr = '1'; wait until rising_edge(clk);
        v24_din <= x"202122232425262728292a2b2c2d2e2f"; v24_dec <= '1';
        wait until rising_edge(clk);
        v24_st <= '1'; wait until rising_edge(clk); v24_st <= '0';
        wait until v24_dn = '1';
        check("Kalyna-128/256 decipher", v24_dout, x"96d9ca30705f5bb4e1dffdce56b46df3");
        wait until rising_edge(clk);
        report "--- Kalyna-256/256 ---" severity note;
        v44_key <= x"1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100";
        wait until rising_edge(clk);
        v44_ks <= '1'; wait until rising_edge(clk); v44_ks <= '0';
        wait until v44_kr = '1'; wait until rising_edge(clk);
        v44_din <= x"3f3e3d3c3b3a393837363534333231302f2e2d2c2b2a29282726252423222120"; v44_dec <= '0';
        wait until rising_edge(clk);
        v44_st <= '1'; wait until rising_edge(clk); v44_st <= '0';
        wait until v44_dn = '1';
        check("Kalyna-256/256 encipher", v44_dout, x"2cd97f61245c38885a0d6a20ec6339a08c2abddc23e3daae3521c90e573d6ef6");
        wait until rising_edge(clk);
        v44_key <= x"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
        wait until rising_edge(clk);
        v44_ks <= '1'; wait until rising_edge(clk); v44_ks <= '0';
        wait until v44_kr = '1'; wait until rising_edge(clk);
        v44_din <= x"202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f"; v44_dec <= '1';
        wait until rising_edge(clk);
        v44_st <= '1'; wait until rising_edge(clk); v44_st <= '0';
        wait until v44_dn = '1';
        check("Kalyna-256/256 decipher", v44_dout, x"e30fb28625d1ed61d3c33f2c597c5baba34b8b3fb0e9c103864e67967823c57f");
        wait until rising_edge(clk);
        report "--- Kalyna-256/512 ---" severity note;
        v48_key <= x"3f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100";
        wait until rising_edge(clk);
        v48_ks <= '1'; wait until rising_edge(clk); v48_ks <= '0';
        wait until v48_kr = '1'; wait until rising_edge(clk);
        v48_din <= x"5f5e5d5c5b5a595857565554535251504f4e4d4c4b4a49484746454443424140"; v48_dec <= '0';
        wait until rising_edge(clk);
        v48_st <= '1'; wait until rising_edge(clk); v48_st <= '0';
        wait until v48_dn = '1';
        check("Kalyna-256/512 encipher", v48_dout, x"d95dfefda8742efd02e1d73c3cc8028eb76822d793d8d64b7ab6b7e6e9906960");
        wait until rising_edge(clk);
        v48_key <= x"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f";
        wait until rising_edge(clk);
        v48_ks <= '1'; wait until rising_edge(clk); v48_ks <= '0';
        wait until v48_kr = '1'; wait until rising_edge(clk);
        v48_din <= x"404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f"; v48_dec <= '1';
        wait until rising_edge(clk);
        v48_st <= '1'; wait until rising_edge(clk); v48_st <= '0';
        wait until v48_dn = '1';
        check("Kalyna-256/512 decipher", v48_dout, x"e06aba796d910b2d97845f9e1898705e078d78a1b907cdbc82d4da67277a3118");
        wait until rising_edge(clk);
        report "--- Kalyna-512/512 ---" severity note;
        v88_key <= x"3f3e3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100";
        wait until rising_edge(clk);
        v88_ks <= '1'; wait until rising_edge(clk); v88_ks <= '0';
        wait until v88_kr = '1'; wait until rising_edge(clk);
        v88_din <= x"7f7e7d7c7b7a797877767574737271706f6e6d6c6b6a696867666564636261605f5e5d5c5b5a595857565554535251504f4e4d4c4b4a49484746454443424140"; v88_dec <= '0';
        wait until rising_edge(clk);
        v88_st <= '1'; wait until rising_edge(clk); v88_st <= '0';
        wait until v88_dn = '1';
        check("Kalyna-512/512 encipher", v88_dout, x"d9d90d947264bcc5b7fe6e85266a90cb6cc815bb34f1d62f66ab5b1717f4d095b856eb20c3ee1d3ea1f347aa5483ba671a239605cad61da66a351c811be3264a");
        wait until rising_edge(clk);
        v88_key <= x"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f";
        wait until rising_edge(clk);
        v88_ks <= '1'; wait until rising_edge(clk); v88_ks <= '0';
        wait until v88_kr = '1'; wait until rising_edge(clk);
        v88_din <= x"404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f"; v88_dec <= '1';
        wait until rising_edge(clk);
        v88_st <= '1'; wait until rising_edge(clk); v88_st <= '0';
        wait until v88_dn = '1';
        check("Kalyna-512/512 decipher", v88_dout, x"22ff5aaa13bb94f0dc1b29b5ab5741af6ae6753b839dff97f2b13b85dbef7f75a346fad954450492bd45a8e90e1e38fd29d8a9e614d7ea1b5252a025338480ce");
        wait until rising_edge(clk);

        wait for CLK_PERIOD;
        if errors = 0 then
            report "=== Kalyna: ALL TESTS PASSED (5 variants, enc+dec) ===" severity note;
        else
            report "=== Kalyna: " & integer'image(errors) & " FAILURE(S) ===" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture Behavioral;
