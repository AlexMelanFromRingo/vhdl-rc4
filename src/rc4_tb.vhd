-- RC4 Testbench: Тестування шифру
-- Автор: CleverBot
-- Тестовий вектор 1: Key="Key", Plaintext="Plaintext"

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.rc4_package.all;

entity rc4_tb is
end rc4_tb;

architecture Behavioral of rc4_tb is
    -- Компонент для тестування
    component rc4_cipher
        Port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            start       : in  std_logic;
            key_length  : in  unsigned(7 downto 0);
            key_in      : in  unsigned(7 downto 0);
            key_valid   : in  std_logic;
            data_in     : in  unsigned(7 downto 0);
            data_valid  : in  std_logic;
            data_out    : out unsigned(7 downto 0);
            data_ready  : out std_logic;
            busy        : out std_logic;
            ksa_done    : out std_logic
        );
    end component;

    -- Сигнали
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal start : std_logic := '0';
    signal key_length : unsigned(7 downto 0) := (others => '0');
    signal key_in : unsigned(7 downto 0) := (others => '0');
    signal key_valid : std_logic := '0';
    signal data_in : unsigned(7 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';
    signal data_out : unsigned(7 downto 0);
    signal data_ready : std_logic;
    signal busy : std_logic;
    signal ksa_done : std_logic;

    -- Константи часу
    constant clk_period : time := 10 ns;

    -- Тестові дані
    type test_key_array is array (0 to 2) of unsigned(7 downto 0);
    constant test_key : test_key_array := (
        x"4B",  -- 'K'
        x"65",  -- 'e'
        x"79"   -- 'y'
    );

    type test_plain_array is array (0 to 8) of unsigned(7 downto 0);
    constant test_plaintext : test_plain_array := (
        x"50",  -- 'P'
        x"6C",  -- 'l'
        x"61",  -- 'a'
        x"69",  -- 'i'
        x"6E",  -- 'n'
        x"74",  -- 't'
        x"65",  -- 'e'
        x"78",  -- 'x'
        x"74"   -- 't'
    );

    type test_cipher_array is array (0 to 8) of unsigned(7 downto 0);
    constant expected_ciphertext : test_cipher_array := (
        x"BB",
        x"F3",
        x"16",
        x"E8",
        x"D9",
        x"40",
        x"AF",
        x"0A",
        x"D3"
    );

    -- Функція to_hstring для старих версій VHDL
    function to_hstring(slv : std_logic_vector) return string is
        variable hex_digits : string(1 to 16) := "0123456789ABCDEF";
        variable four_bit : std_logic_vector(3 downto 0);
        variable result : string(1 to (slv'length+3)/4);
        variable pad_slv : std_logic_vector(result'length*4-1 downto 0) := (others => '0');
        variable pointer : integer := 1;
    begin
        -- Вирівнювання вектора
        pad_slv(slv'length-1 downto 0) := slv;

        -- Цикл по 4 біти (по ніблам)
        for i in result'length-1 downto 0 loop
            four_bit := pad_slv(i*4+3 downto i*4);
            case four_bit is
                when "0000" => result(pointer) := '0';
                when "0001" => result(pointer) := '1';
                when "0010" => result(pointer) := '2';
                when "0011" => result(pointer) := '3';
                when "0100" => result(pointer) := '4';
                when "0101" => result(pointer) := '5';
                when "0110" => result(pointer) := '6';
                when "0111" => result(pointer) := '7';
                when "1000" => result(pointer) := '8';
                when "1001" => result(pointer) := '9';
                when "1010" => result(pointer) := 'A';
                when "1011" => result(pointer) := 'B';
                when "1100" => result(pointer) := 'C';
                when "1101" => result(pointer) := 'D';
                when "1110" => result(pointer) := 'E';
                when "1111" => result(pointer) := 'F';
                when others => result(pointer) := 'X';
            end case;
            pointer := pointer + 1;
        end loop;

        return result;
    end function;

begin

    -- Інстанціювання модуля
    UUT: rc4_cipher
        port map (
            clk => clk,
            reset => reset,
            start => start,
            key_length => key_length,
            key_in => key_in,
            key_valid => key_valid,
            data_in => data_in,
            data_valid => data_valid,
            data_out => data_out,
            data_ready => data_ready,
            busy => busy,
            ksa_done => ksa_done
        );

    -- Генерація тактового сигналу
    clk_process: process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Основний тестовий процес
    stim_process: process
        variable output_index : integer := 0;
    begin
        -- Початковий reset
        reset <= '1';
        wait for clk_period * 2;
        reset <= '0';
        wait for clk_period;

        report "=== RC4 Test Start ===" severity note;
        report "Test Vector 1: Key='Key', Plaintext='Plaintext'" severity note;

        -- Налаштування довжини ключа
        key_length <= to_unsigned(3, 8);  -- 3 байти
        wait for clk_period;

        -- Запуск ініціалізації
        start <= '1';
        wait for clk_period;
        start <= '0';

        -- Завантаження ключа
        for i in 0 to 2 loop
            wait for clk_period;
            key_in <= test_key(i);
            key_valid <= '1';
            wait for clk_period;
            key_valid <= '0';
        end loop;

        -- Очікування завершення KSA
        report "Waiting for KSA completion..." severity note;
        wait until ksa_done = '1';
        wait for clk_period * 10;
        report "KSA completed!" severity note;

        -- Шифрування даних
        report "Starting encryption..." severity note;
        for i in 0 to 8 loop
            wait for clk_period;
            data_in <= test_plaintext(i);
            data_valid <= '1';
            wait for clk_period;
            data_valid <= '0';

            -- Очікування результату
            wait until data_ready = '1';
            wait for clk_period;

            -- Перевірка результату
            if data_out = expected_ciphertext(i) then
                report "Byte " & integer'image(i) & ": PASS - Output: 0x" &
                       to_hstring(std_logic_vector(data_out)) & " (expected: 0x" &
                       to_hstring(std_logic_vector(expected_ciphertext(i))) & ")" severity note;
            else
                report "Byte " & integer'image(i) & ": FAIL - Output: 0x" &
                       to_hstring(std_logic_vector(data_out)) & " (expected: 0x" &
                       to_hstring(std_logic_vector(expected_ciphertext(i))) & ")" severity error;
            end if;

            wait for clk_period * 5;
        end loop;

        report "=== RC4 Test Complete ===" severity note;
        wait for clk_period * 10;

        -- Додатковий тест: Test Vector 2
        report "=== RC4 Test Vector 2 Start ===" severity note;
        report "Test Vector 2: Key='Wiki', Plaintext='pedia'" severity note;

        reset <= '1';
        wait for clk_period * 2;
        reset <= '0';
        wait for clk_period;

        key_length <= to_unsigned(4, 8);  -- 4 байти
        start <= '1';
        wait for clk_period;
        start <= '0';

        -- Ключ "Wiki"
        key_in <= x"57"; key_valid <= '1'; wait for clk_period; key_valid <= '0'; wait for clk_period;
        key_in <= x"69"; key_valid <= '1'; wait for clk_period; key_valid <= '0'; wait for clk_period;
        key_in <= x"6B"; key_valid <= '1'; wait for clk_period; key_valid <= '0'; wait for clk_period;
        key_in <= x"69"; key_valid <= '1'; wait for clk_period; key_valid <= '0'; wait for clk_period;

        wait until ksa_done = '1';
        wait for clk_period * 10;

        -- Plaintext "pedia" -> очікуваний результат: 10 21 BF 04 20
        data_in <= x"70"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Output byte 0: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x10)" severity note;
        wait for clk_period * 5;

        data_in <= x"65"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Output byte 1: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x21)" severity note;
        wait for clk_period * 5;

        data_in <= x"64"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Output byte 2: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0xBF)" severity note;
        wait for clk_period * 5;

        data_in <= x"69"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Output byte 3: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x04)" severity note;
        wait for clk_period * 5;

        data_in <= x"61"; data_valid <= '1'; wait for clk_period; data_valid <= '0';
        wait until data_ready = '1'; wait for clk_period;
        report "Output byte 4: 0x" & to_hstring(std_logic_vector(data_out)) & " (expected: 0x20)" severity note;

        report "=== All Tests Complete ===" severity note;
        wait;
    end process;

end Behavioral;
