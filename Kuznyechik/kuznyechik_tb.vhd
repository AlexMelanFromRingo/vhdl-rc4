-- =====================================================================
--  "Кузнечик" - самоперевірний тестбенч
--  Автор: Alex Melan
--
--  Частина A: покрокові приклади перетворень S, L, L^-1 зі стандарту
--             ГОСТ Р 34.12-2015 (розділ "Контрольні приклади").
--  Частина B: повний блок - вектор із RFC 7801.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;
use work.kuznyechik_package.all;

entity kuznyechik_tb is
end entity kuznyechik_tb;

architecture Behavioral of kuznyechik_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal key_start : std_logic := '0';
    signal key_ready : std_logic;
    signal start     : std_logic := '0';
    signal decrypt   : std_logic := '0';
    signal key_in    : unsigned(255 downto 0) := (others => '0');
    signal data_in   : unsigned(127 downto 0) := (others => '0');
    signal data_out  : unsigned(127 downto 0);
    signal done      : std_logic;

    signal sim_done  : boolean := false;
    signal errors    : natural := 0;

    constant KEY : unsigned(255 downto 0) :=
        x"8899aabbccddeeff0011223344556677fedcba98765432100123456789abcdef";
    constant PT  : unsigned(127 downto 0) := x"1122334455667700ffeeddccbbaa9988";
    constant CT  : unsigned(127 downto 0) := x"7f679d90bebc24305a468d42b9d4edcd";

begin

    UUT : entity work.kuznyechik_cipher
        port map (clk => clk, reset => reset,
                  key_in => key_in, key_start => key_start, key_ready => key_ready,
                  start => start, decrypt => decrypt, data_in => data_in,
                  data_out => data_out, done => done, busy => open);

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_process : process

        procedure check(msg : string; got_v, exp_v : unsigned(127 downto 0)) is
        begin
            if got_v = exp_v then
                report msg & ": PASS  " & to_hex(got_v) severity note;
            else
                report msg & ": FAIL  got " & to_hex(got_v) &
                       "  expected " & to_hex(exp_v) severity error;
                errors <= errors + 1;
            end if;
        end procedure check;

    begin
        report "=== Kuznyechik (GOST R 34.12-2015) test start ===" severity note;

        -- ---------- Частина A: окремі перетворення ----------
        check("S  (standard example)",
              to_word(s_layer(to_block(x"ffeeddccbbaa99881122334455667700"))),
              x"b66cd8887d38e8d77765aeea0c9a7efc");

        check("L  (standard example)",
              to_word(l_layer(to_block(x"64a59400000000000000000000000000"))),
              x"d456584dd0e3e84cc3166e4b7fa2890d");

        check("L^-1 round-trip",
              to_word(l_layer_inv(l_layer(to_block(x"64a59400000000000000000000000000")))),
              x"64a59400000000000000000000000000");

        check("S^-1 round-trip",
              to_word(s_layer_inv(s_layer(to_block(PT)))), PT);

        -- ---------- Частина B: повний блок ----------
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';
        wait for CLK_PERIOD;

        -- Розгортання ключа
        key_in <= KEY;
        wait until rising_edge(clk);
        key_start <= '1';
        wait until rising_edge(clk);
        key_start <= '0';
        wait until key_ready = '1';
        report "key schedule ready" severity note;
        wait until rising_edge(clk);

        -- Зашифрування
        data_in <= PT;
        decrypt <= '0';
        wait until rising_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until done = '1';
        check("encipher (RFC 7801)", data_out, CT);
        wait until rising_edge(clk);

        -- Розшифрування
        data_in <= CT;
        decrypt <= '1';
        wait until rising_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until done = '1';
        check("decipher (RFC 7801)", data_out, PT);
        wait until rising_edge(clk);

        wait for CLK_PERIOD;
        if errors = 0 then
            report "=== Kuznyechik: ALL TESTS PASSED ===" severity note;
        else
            report "=== Kuznyechik: " & integer'image(errors) &
                   " FAILURE(S) ===" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture Behavioral;
