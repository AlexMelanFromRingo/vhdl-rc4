# RC4 Stream Cipher - VHDL Implementation

A complete, synthesizable VHDL implementation of the RC4 stream cipher for Xilinx Spartan-3 FPGA.

## Author

**Alex Melan**

## Features

- Full RC4 algorithm implementation (KSA + PRGA)
- Synthesizable design for Xilinx ISE 8.1i
- Support for keys from 1 to 255 bytes
- Byte-by-byte encryption/decryption
- VHDL-93 compatible (works with older tools)

## Architecture

The implementation consists of three main components:

| File | Description |
|------|-------------|
| `rc4_package.vhd` | Types, constants, and FSM state definitions |
| `rc4_cipher.vhd` | Main RC4 cipher module |
| `rc4_tb.vhd` | Testbench with 4 test vectors |

## RC4 Algorithm

### Key-Scheduling Algorithm (KSA)
- Initializes 256-byte S-box: `S[i] = i`
- Permutes S-box using the key (256 iterations)
- Completes in ~512 clock cycles

### Pseudo-Random Generation Algorithm (PRGA)
- Generates keystream bytes on demand
- XORs keystream with plaintext/ciphertext
- 4 clock cycles per output byte

## Interface

```vhdl
entity rc4_cipher is
    Port (
        clk         : in  std_logic;          -- Clock
        reset       : in  std_logic;          -- Async reset
        start       : in  std_logic;          -- Start KSA
        key_length  : in  unsigned(7 downto 0); -- Key length (1-255)
        key_in      : in  unsigned(7 downto 0); -- Key byte input
        key_valid   : in  std_logic;          -- Key byte valid
        data_in     : in  unsigned(7 downto 0); -- Data to encrypt/decrypt
        data_valid  : in  std_logic;          -- Data valid
        data_out    : out unsigned(7 downto 0); -- Encrypted/decrypted output
        data_ready  : out std_logic;          -- Output ready
        busy        : out std_logic;          -- Module busy
        ksa_done    : out std_logic           -- KSA complete
    );
end rc4_cipher;
```

## Usage

### Import Order in Xilinx ISE
1. `rc4_package.vhd`
2. `rc4_cipher.vhd`
3. `rc4_tb.vhd` (for simulation only)

### Simulation
```
run 45 us
```

### Basic Operation Sequence
1. Assert `reset` for 2+ clock cycles
2. Set `key_length` to desired key size
3. Assert `start` for 1 clock cycle
4. Feed key bytes via `key_in` with `key_valid` asserted
5. Wait for `ksa_done = '1'`
6. Feed data bytes via `data_in` with `data_valid` asserted
7. Read encrypted/decrypted bytes from `data_out` when `data_ready = '1'`

## Test Vectors

### Encryption Tests

| # | Key | Plaintext | Expected Ciphertext |
|---|-----|-----------|---------------------|
| 1 | "Key" | "Plaintext" | BB F3 16 E8 D9 40 AF 0A D3 |
| 2 | "Wiki" | "pedia" | 10 21 BF 04 20 |
| 3 | "Secret" | "Attack at dawn" | 45 A0 1F 64 5F C3 5B 38 35 52 54 4B 9B F5 |

### Decryption Test

| # | Key | Ciphertext | Expected Plaintext |
|---|-----|------------|-------------------|
| 4 | "Key" | BB F3 16 E8 D9 40 AF 0A D3 | "Plaintext" |

Test 4 verifies that RC4 is symmetric: decrypting the ciphertext from Test 1 recovers the original plaintext.

## Timing

- **Clock period**: 10 ns (100 MHz)
- **S-box init**: 256 cycles (~2.56 us)
- **KSA**: 256 cycles (~2.56 us)
- **Total init**: ~512 cycles (~5.12 us)
- **PRGA**: 4 cycles per byte (~40 ns)

## Target Platform

- **FPGA**: Xilinx Spartan-3
- **Tool**: Xilinx ISE 8.1i
- **Language**: VHDL-93

## Notes

- RC4 is a symmetric cipher: encryption and decryption use the same operation
- The design uses a cyclic counter instead of modulo operator for synthesis compatibility
- Reset must be asserted between different encryption sessions
