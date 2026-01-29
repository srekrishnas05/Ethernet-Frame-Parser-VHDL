library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity payload_sink is
    generic (
        capture_bytes : natural := 256
);
    port (
        clk : in std_logic;
        rst : in std_logic;
        
        frame_start : in std_logic;
        frame_done : in std_logic;
        frame_error : in std_logic;
        
        payload_byte : in std_logic_vector(7 downto 0);
        payload_valid : in std_logic;
        
        payload_count : out std_logic_vector(15 downto 0);
        capture_wr_ptr : out std_logic_vector(15 downto 0);
        
        done_latched : out std_logic;
        error_latched : out std_logic
        );
end entity;

architecture rtl of payload_sink is
    type mem_t is array (0 to capture_bytes-1) of std_logic_vector(7 downto 0);
    signal mem : mem_t := (others => (others => '0'));
    signal count_r : unsigned(15 downto 0) := (others => '0');
    signal wr_ptr : unsigned(15 downto 0) := (others => '0');
    signal done_r : std_logic := '0';
    signal err_r : std_logic := '0';
begin
    payload_count <= std_logic_vector(count_r);
    capture_wr_ptr <= std_logic_vector(wr_ptr);
    done_latched <= done_r;
    error_latched <= err_r;
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                count_r <= (others => '0');
                wr_ptr <= (others => '0');
                done_r <= '0';
                err_r <= '0';
            else
                if (frame_start = '1') then
                    count_r <= (others => '0');
                    wr_ptr <= (others => '0');
                    done_r <= '0';
                    err_r <= '0';
                end if;
                if (frame_error = '1') then
                    err_r <= '1';
                end if;
                if (payload_valid = '1') then
                    count_r <= count_r + 1;
                    if (to_integer(wr_ptr) < capture_bytes) then
                        mem(to_integer(wr_ptr)) <= payload_byte;
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;
                if (frame_done = '1') then
                    done_r <= '1';
                end if;    
            end if;
        end if;
    end process;
end architecture;               