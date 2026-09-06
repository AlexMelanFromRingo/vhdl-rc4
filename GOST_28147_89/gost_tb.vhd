-- =====================================================================
--  ГОСТ 28147-89 - самоперевірний тестбенч
--  Автор: CleverBot
--
--  Векторів для 28147-89 у машинозчитуваному вигляді стандарт не дає,
--  тому ядро звірене з офіційним вектором "Магми" (ГОСТ Р 34.12-2015 /
--  RFC 8891), який використовує ту саму конструкцію з S-блоком TC26-Z.
--  Решта векторів обчислені перевіреною еталонною моделлю.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gost_package.all;
use work.crypto_util.all;

entity gost_tb is
end entity gost_tb;

architecture Behavioral of gost_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal start    : std_logic := '0';
    signal decrypt  : std_logic := '0';
    signal key_in   : unsigned(255 downto 0) := (others => '0');
    signal data_in  : unsigned(63 downto 0)  := (others => '0');

    -- Три екземпляри ядра з різними наборами таблиць замін
    signal dout_test, dout_cpa, dout_z : unsigned(63 downto 0);
    signal done_test, done_cpa, done_z : std_logic;

    signal sim_done : boolean := false;
    signal errors   : natural := 0;

    -- Таблиця тестових векторів -----------------------------------------
    type tv_t is record
        sid : natural;                       -- 0 = Test, 1 = CryptoPro-A, 2 = TC26-Z
        key : unsigned(255 downto 0);
        pt  : unsigned(63 downto 0);
        ct  : unsigned(63 downto 0);
    end record;
    type tv_array is array (natural range <>) of tv_t;

    constant TESTS : tv_array := (
        (sid => 2,
         key => x"ffeeddccbbaa99887766554433221100f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff",
         pt  => x"fedcba9876543210",
         ct  => x"4ee901e5c2d8ca3d"),
        (sid => 0,
         key => x"0000000000000000000000000000000000000000000000000000000000000000",
         pt  => x"0000000000000000",
         ct  => x"12610be2a6c2fdc9"),
        (sid => 1,
         key => x"0000000000000000000000000000000000000000000000000000000000000000",
         pt  => x"0000000000000000",
         ct  => x"6b7dc1d9fe674e97"),
        (sid => 0,
         key => x"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
         pt  => x"0123456789abcdef",
         ct  => x"4b9b5239b26fff5d"));

    function sbox_name(sid : natural) return string is
    begin
        case sid is
            when 0      => return "Test-ParamSet";
            when 1      => return "CryptoPro-A  ";
            when others => return "TC26-Z       ";
        end case;
    end function sbox_name;

begin

    -- Три ядра працюють паралельно від одних і тих самих входів;
    -- тестбенч дивиться на вихід того, чий набір S-блоків потрібен.
    UUT_TEST : entity work.gost_cipher
        generic map (SBOX => S_TEST)
        port map (clk => clk, reset => reset, start => start, decrypt => decrypt,
                  key_in => key_in, data_in => data_in,
                  data_out => dout_test, done => done_test, busy => open);

    UUT_CPA : entity work.gost_cipher
        generic map (SBOX => S_CRYPTOPRO_A)
        port map (clk => clk, reset => reset, start => start, decrypt => decrypt,
                  key_in => key_in, data_in => data_in,
                  data_out => dout_cpa, done => done_cpa, busy => open);

    UUT_Z : entity work.gost_cipher
        generic map (SBOX => S_TC26_Z)
        port map (clk => clk, reset => reset, start => start, decrypt => decrypt,
                  key_in => key_in, data_in => data_in,
                  data_out => dout_z, done => done_z, busy => open);

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_process : process
        variable got : unsigned(63 downto 0);

        -- Прогнати один блок і забрати результат обраного ядра
        procedure run_block(sid : natural; d : std_logic;
                            k : unsigned(255 downto 0); x : unsigned(63 downto 0);
                            result : out unsigned(63 downto 0)) is
        begin
            key_in  <= k;
            data_in <= x;
            decrypt <= d;
            wait until rising_edge(clk);
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            case sid is
                when 0      => wait until done_test = '1'; result := dout_test;
                when 1      => wait until done_cpa  = '1'; result := dout_cpa;
                when others => wait until done_z    = '1'; result := dout_z;
            end case;
            wait until rising_edge(clk);
        end procedure run_block;

        procedure check(msg : string; got_v, exp_v : unsigned(63 downto 0)) is
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
        report "=== GOST 28147-89 (ECB) test start ===" severity note;
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';
        wait for CLK_PERIOD;

        for i in TESTS'range loop
            -- Зашифрування
            run_block(TESTS(i).sid, '0', TESTS(i).key, TESTS(i).pt, got);
            check("enc [" & sbox_name(TESTS(i).sid) & "] vec" & integer'image(i),
                  got, TESTS(i).ct);

            -- Розшифрування (має повернути вихідний блок)
            run_block(TESTS(i).sid, '1', TESTS(i).key, TESTS(i).ct, got);
            check("dec [" & sbox_name(TESTS(i).sid) & "] vec" & integer'image(i),
                  got, TESTS(i).pt);
        end loop;

        wait for CLK_PERIOD;
        if errors = 0 then
            report "=== GOST 28147-89: ALL TESTS PASSED ===" severity note;
        else
            report "=== GOST 28147-89: " & integer'image(errors) &
                   " FAILURE(S) ===" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture Behavioral;
