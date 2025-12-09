--------------------------------------------------------------------------------
-- RC4 Testbench
-- Verifies RC4 implementation using test vectors from documentation
--
-- Test Vector 1:
--   Key: "Key" (ASCII) -> 4B 65 79
--   Plaintext: "Plaintext" (ASCII) -> 50 6C 61 69 6E 74 65 78 74
--   Ciphertext: BB F3 16 E8 D9 40 AF 0A D3
--
-- Test Vector 2:
--   Key: "Wiki" (ASCII) -> 57 69 6B 69
--   Plaintext: "pedia" (ASCII) -> 70 65 64 69 61
--   Ciphertext: 10 21 BF 04 20
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.rc4_pkg.all;

entity rc4_tb is
end entity rc4_tb;

architecture sim of rc4_tb is
    -- Clock period
    constant CLK_PERIOD : time := 10 ns;

    -- DUT signals
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal start        : std_logic := '0';
    signal key_len      : unsigned(7 downto 0) := (others => '0');
    signal key_data     : byte_t := (others => '0');
    signal key_addr     : unsigned(7 downto 0);
    signal data_in      : byte_t := (others => '0');
    signal data_valid   : std_logic := '0';
    signal data_out     : byte_t;
    signal data_ready   : std_logic;
    signal busy         : std_logic;
    signal ready        : std_logic;

    -- Test data
    -- Test 1: Key = "Key", Plaintext = "Plaintext"
    type key1_t is array (0 to 2) of byte_t;
    constant KEY1 : key1_t := (x"4B", x"65", x"79");  -- "Key"
    constant KEY1_LEN : integer := 3;

    type plain1_t is array (0 to 8) of byte_t;
    constant PLAIN1 : plain1_t := (x"50", x"6C", x"61", x"69", x"6E", x"74", x"65", x"78", x"74");  -- "Plaintext"
    constant CIPHER1 : plain1_t := (x"BB", x"F3", x"16", x"E8", x"D9", x"40", x"AF", x"0A", x"D3");
    constant PLAIN1_LEN : integer := 9;

    -- Test 2: Key = "Wiki", Plaintext = "pedia"
    type key2_t is array (0 to 3) of byte_t;
    constant KEY2 : key2_t := (x"57", x"69", x"6B", x"69");  -- "Wiki"
    constant KEY2_LEN : integer := 4;

    type plain2_t is array (0 to 4) of byte_t;
    constant PLAIN2 : plain2_t := (x"70", x"65", x"64", x"69", x"61");  -- "pedia"
    constant CIPHER2 : plain2_t := (x"10", x"21", x"BF", x"04", x"20");
    constant PLAIN2_LEN : integer := 5;

    -- Test control
    signal test_done    : std_logic := '0';
    signal test_pass    : std_logic := '1';
    signal current_test : integer := 0;

begin

    -- Clock generation
    clk_gen : process
    begin
        while test_done = '0' loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clk_gen;

    -- DUT instantiation
    dut : entity work.rc4
        port map (
            clk         => clk,
            rst         => rst,
            start       => start,
            key_len     => key_len,
            key_data    => key_data,
            key_addr    => key_addr,
            data_in     => data_in,
            data_valid  => data_valid,
            data_out    => data_out,
            data_ready  => data_ready,
            busy        => busy,
            ready       => ready
        );

    -- Key memory process (provides key bytes based on address)
    key_mem_proc : process(key_addr, current_test)
    begin
        if current_test = 1 then
            if to_integer(key_addr) < KEY1_LEN then
                key_data <= KEY1(to_integer(key_addr));
            else
                key_data <= x"00";
            end if;
        elsif current_test = 2 then
            if to_integer(key_addr) < KEY2_LEN then
                key_data <= KEY2(to_integer(key_addr));
            else
                key_data <= x"00";
            end if;
        else
            key_data <= x"00";
        end if;
    end process key_mem_proc;

    -- Main test process
    test_proc : process
        variable output_idx : integer;
        variable expected   : byte_t;
    begin
        -- Initial reset
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 2;

        ------------------------------------------------------------------------
        -- Test 1: Key = "Key", Plaintext = "Plaintext"
        ------------------------------------------------------------------------
        report "========================================";
        report "Test 1: Key='Key', Plaintext='Plaintext'";
        report "========================================";

        current_test <= 1;
        key_len <= to_unsigned(KEY1_LEN, 8);

        -- Start KSA
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        -- Wait for KSA to complete
        wait until ready = '1';
        report "KSA complete, starting encryption...";

        -- Encrypt each byte
        for i in 0 to PLAIN1_LEN - 1 loop
            data_in <= PLAIN1(i);
            data_valid <= '1';
            wait for CLK_PERIOD;
            data_valid <= '0';

            -- Wait for output
            wait until data_ready = '1';

            expected := CIPHER1(i);
            if data_out = expected then
                report "Byte " & integer'image(i) & ": OK (0x" &
                       to_hstring(unsigned(data_out)) & ")";
            else
                report "Byte " & integer'image(i) & ": FAIL - Expected 0x" &
                       to_hstring(unsigned(expected)) & ", Got 0x" &
                       to_hstring(unsigned(data_out)) severity error;
                test_pass <= '0';
            end if;

            wait for CLK_PERIOD;
        end loop;

        -- Reset between tests
        rst <= '1';
        wait for CLK_PERIOD * 3;
        rst <= '0';
        wait for CLK_PERIOD * 2;

        ------------------------------------------------------------------------
        -- Test 2: Key = "Wiki", Plaintext = "pedia"
        ------------------------------------------------------------------------
        report "========================================";
        report "Test 2: Key='Wiki', Plaintext='pedia'";
        report "========================================";

        current_test <= 2;
        key_len <= to_unsigned(KEY2_LEN, 8);

        -- Start KSA
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        -- Wait for KSA to complete
        wait until ready = '1';
        report "KSA complete, starting encryption...";

        -- Encrypt each byte
        for i in 0 to PLAIN2_LEN - 1 loop
            data_in <= PLAIN2(i);
            data_valid <= '1';
            wait for CLK_PERIOD;
            data_valid <= '0';

            -- Wait for output
            wait until data_ready = '1';

            expected := CIPHER2(i);
            if data_out = expected then
                report "Byte " & integer'image(i) & ": OK (0x" &
                       to_hstring(unsigned(data_out)) & ")";
            else
                report "Byte " & integer'image(i) & ": FAIL - Expected 0x" &
                       to_hstring(unsigned(expected)) & ", Got 0x" &
                       to_hstring(unsigned(data_out)) severity error;
                test_pass <= '0';
            end if;

            wait for CLK_PERIOD;
        end loop;

        -- Final report
        report "========================================";
        if test_pass = '1' then
            report "All tests PASSED!" severity note;
        else
            report "Some tests FAILED!" severity error;
        end if;
        report "========================================";

        test_done <= '1';
        wait;
    end process test_proc;

end architecture sim;
