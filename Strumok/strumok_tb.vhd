-- =====================================================================
--  "Струмок" (ДСТУ 8845:2019) - самоперевірний тестбенч
--  Автор: CleverBot
--
--  Вісім векторів гами з Додатка D стандарту (D.1.1.1 - D.1.1.4 для
--  ключів 256 і 512 біт). Оскільки ДСТУ не має машинозчитуваного
--  видання, кожен вектор попередньо звірено з ДВОМА незалежними
--  реалізаціями: li0ard/strumok (TypeScript) та outspace/dstu8845 (C).
--
--  Файл згенеровано з таблиці векторів, щоб виключити описки.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.crypto_util.all;
use work.strumok_package.all;

entity strumok_tb is
end entity strumok_tb;

architecture Behavioral of strumok_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal sim_done : boolean := false;
    signal errors   : natural := 0;

    type ks_array is array (0 to 7) of unsigned(63 downto 0);

    type sv256_t is record
        key : unsigned(255 downto 0);
        iv  : unsigned(255 downto 0);
        ks  : ks_array;
    end record;
    type sv512_t is record
        key : unsigned(511 downto 0);
        iv  : unsigned(255 downto 0);
        ks  : ks_array;
    end record;
    type sv256_arr is array (natural range <>) of sv256_t;
    type sv512_arr is array (natural range <>) of sv512_t;

    constant T256 : sv256_arr := (
        (key => x"0000000000000000000000000000000000000000000000008000000000000000", iv => x"0000000000000000000000000000000000000000000000000000000000000000",
         ks  => (x"e442d15345dc66ca", x"f47d700ecc66408a", x"b4cb284b5477e641", x"a2afc9092e4124b0", x"728e5fa26b11a7d9", x"e6a7b9288c68f972", x"70eb3606de8ba44c", x"aced7956bd3e3de7")),
        (key => x"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", iv => x"0000000000000000000000000000000000000000000000000000000000000000",
         ks  => (x"a7510b38c7a95d1d", x"cd5ea28a15b8654f", x"c5e2e2771d0373b2", x"98ae829686d5fcee", x"45bddf65c523dbb8", x"32a93fcdd950001f", x"752a7fb588af8c51", x"9de92736664212d4")),
        (key => x"0000000000000000000000000000000000000000000000008000000000000000", iv => x"0000000000000001000000000000000200000000000000030000000000000004",
         ks  => (x"fe44a2508b5a2acd", x"af355b4ed21d2742", x"dcd7fdd6a57a9e71", x"5d267bd2739fb5eb", x"b22eee96b2832072", x"c7de6a4cdaa9a847", x"72d5da93812680f2", x"4a0acb7e93da2ce0")),
        (key => x"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", iv => x"0000000000000001000000000000000200000000000000030000000000000004",
         ks  => (x"e6d0efd9cea5abcd", x"1e78ba1a9b0e401e", x"bcfbea2c02ba0781", x"1bd375588ae08794", x"5493cf21e114c209", x"66cd5d7cc7d0e69a", x"a5cdb9f3380d07fa", x"2940d61a4d4e9ce4")));

    constant T512 : sv512_arr := (
        (key => x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000", iv => x"0000000000000000000000000000000000000000000000000000000000000000",
         ks  => (x"f5b9ab51100f8317", x"898ef2086a4af395", x"59571fecb5158d0b", x"b7c45b6744c71fbb", x"ff2efcf05d8d8db9", x"7a585871e5c419c0", x"6b5c4691b9125e71", x"a55be7d2b358ec6e")),
        (key => x"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", iv => x"0000000000000000000000000000000000000000000000000000000000000000",
         ks  => (x"d2a6103c50bd4e04", x"dc6a21af5eb13b73", x"df4ca6cb07797265", x"f453c253d8d01876", x"039a64dc7a01800c", x"688ce327dccb7e84", x"41e0250b5e526403", x"9936e478aa200f22")),
        (key => x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000", iv => x"0000000000000001000000000000000200000000000000030000000000000004",
         ks  => (x"cca12eae8133aaaa", x"528d85507ce8501d", x"da83c7fe3e1823f1", x"21416ebf63b71a42", x"26d76d2bf1a625eb", x"eec66ee0cd0b1efc", x"02dd68f338a345a8", x"47538790a5411adb")),
        (key => x"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", iv => x"0000000000000001000000000000000200000000000000030000000000000004",
         ks  => (x"965648e775c717d5", x"a63c2a7376e92df3", x"0b0eb0bbd47ca267", x"ea593d979ae5bd39", x"d773b5e5193cafe1", x"b0a26671d259422b", x"85b2aa326b280156", x"511ace6451435f0c")));

    -- Струмок-256
    signal k256   : unsigned(255 downto 0) := (others => '0');
    signal iv256  : unsigned(255 downto 0) := (others => '0');
    signal in256  : unsigned(63 downto 0)  := (others => '0');
    signal i256, e256 : std_logic := '0';
    signal r256, v256 : std_logic;
    signal ks256, do256 : unsigned(63 downto 0);

    -- Струмок-512
    signal k512   : unsigned(511 downto 0) := (others => '0');
    signal iv512  : unsigned(255 downto 0) := (others => '0');
    signal in512  : unsigned(63 downto 0)  := (others => '0');
    signal i512, e512 : std_logic := '0';
    signal r512, v512 : std_logic;
    signal ks512, do512 : unsigned(63 downto 0);

begin

    UUT256 : entity work.strumok_cipher
        generic map (KEY_WORDS => 4)
        port map (clk => clk, reset => reset, key_in => k256, iv_in => iv256,
                  init => i256, ready => r256, en => e256, data_in => in256,
                  ks_out => ks256, data_out => do256, valid => v256);

    UUT512 : entity work.strumok_cipher
        generic map (KEY_WORDS => 8)
        port map (clk => clk, reset => reset, key_in => k512, iv_in => iv512,
                  init => i512, ready => r512, en => e512, data_in => in512,
                  ks_out => ks512, data_out => do512, valid => v512);

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_process : process
        variable n : natural;

        procedure check(msg : string; got_v, exp_v : unsigned) is
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
        report "=== Strumok (DSTU 8845:2019) test start ===" severity note;
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';
        wait for CLK_PERIOD;

        -- ---------------- Струмок-256 ----------------
        for t in T256'range loop
            k256  <= T256(t).key;
            iv256 <= T256(t).iv;
            wait until rising_edge(clk);
            i256 <= '1'; wait until rising_edge(clk); i256 <= '0';
            wait until r256 = '1';

            e256 <= '1';
            n := 0;
            while n < 8 loop
                wait until falling_edge(clk);
                if v256 = '1' then
                    check("Strumok-256 vec" & integer'image(t) &
                          " z" & integer'image(n), ks256, T256(t).ks(n));
                    n := n + 1;
                end if;
            end loop;
            e256 <= '0';
            wait until rising_edge(clk);
        end loop;

        -- ---------------- Струмок-512 ----------------
        for t in T512'range loop
            k512  <= T512(t).key;
            iv512 <= T512(t).iv;
            wait until rising_edge(clk);
            i512 <= '1'; wait until rising_edge(clk); i512 <= '0';
            wait until r512 = '1';

            e512 <= '1';
            n := 0;
            while n < 8 loop
                wait until falling_edge(clk);
                if v512 = '1' then
                    check("Strumok-512 vec" & integer'image(t) &
                          " z" & integer'image(n), ks512, T512(t).ks(n));
                    n := n + 1;
                end if;
            end loop;
            e512 <= '0';
            wait until rising_edge(clk);
        end loop;

        -- ---------------- потокове шифрування ----------------
        -- Повторна ініціалізація тим самим ключем має відтворити ту саму
        -- гаму, тож data_out = plaintext xor z, а друге накладання повертає
        -- відкритий текст. Заразом це перевіряє перезапуск по init.
        k256  <= T256(0).key;
        iv256 <= T256(0).iv;
        in256 <= x"0011223344556677";
        wait until rising_edge(clk);
        i256 <= '1'; wait until rising_edge(clk); i256 <= '0';
        wait until r256 = '1';
        e256 <= '1';
        wait until falling_edge(clk);
        while v256 /= '1' loop
            wait until falling_edge(clk);
        end loop;
        check("Strumok-256 encrypt (pt xor z0)", do256,
              x"0011223344556677" xor T256(0).ks(0));
        e256 <= '0';
        wait until rising_edge(clk);

        wait for CLK_PERIOD;
        if errors = 0 then
            report "=== Strumok: ALL TESTS PASSED (256 & 512, 8 DSTU vectors) ===" severity note;
        else
            report "=== Strumok: " & integer'image(errors) & " FAILURE(S) ===" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture Behavioral;
