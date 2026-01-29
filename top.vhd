library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
end top;

architecture rtl of top is
    constant CLK_PERIOD : time := 10 ns;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    
    signal s_byte : std_logic_vector(7 downto 0);
    signal s_valid : std_logic;
    signal s_sof : std_logic;
    signal s_eof : std_logic;
    signal s_err : std_logic;
    
    signal dst_mac : std_logic_vector(47 downto 0);
    signal src_mac : std_logic_vector(47 downto 0);
    signal q_tag : std_logic_vector(31 downto 0);
    signal ethertype : std_logic_vector(15 downto 0);
    
    signal payload_byte : std_logic_vector(7 downto 0);
    signal payload_valid : std_logic;
    signal frame_start : std_logic;
    signal frame_done : std_logic;
    signal frame_error : std_logic;
    
    signal crc_ok : std_logic;
    signal crc_bad : std_logic;
    signal crc_final : std_logic_vector(31 downto 0);
    signal fcs_recv : std_logic_vector(31 downto 0);

begin
    clk <= not clk after clk_period/2;
    process
    begin 
        rst <= '1';
        wait for 50 ns;
        rst <= '0';
        wait for 10 ms;
        assert false report "sim done" severity failure;
    end process;
    
    
    u_src : entity work.rx_source
        port map (
            clk => clk,
            rst => rst,
            out_byte => s_byte,
            out_valid => s_valid,
            out_sof => s_sof,
            out_eof => s_eof,
            out_err => s_err
        );
    u_parser : entity work.frame_parser
        port map (
            clk => clk,
            rst => rst,
            in_byte => s_byte,
            in_valid => s_valid,
            in_sof => s_sof,
            in_eof => s_eof,
            in_err => s_err,
            dst_mac => dst_mac,
            src_mac => src_mac, 
            q_tag => q_tag,
            ethertype => ethertype,
            payload_byte => payload_byte,
            payload_valid => payload_valid,
            frame_start => frame_start,
            frame_done => frame_done,
            frame_error => frame_error
        );
    u_crc : entity work.crc32
        port map (
            clk => clk,
            rst => rst,
            in_byte => s_byte,
            in_valid => s_valid,
            in_sof => s_sof,
            in_eof => s_eof,
            crc_ok => crc_ok,
            crc_bad => crc_bad,
            crc_final => crc_final,
            fcs_recv => fcs_recv
            );
    u_sink : entity work.payload_sink
        port map (
            clk => clk,
            rst => rst,
            frame_start => frame_start,
            frame_done => frame_done,
            frame_error => frame_error,
            payload_byte => payload_byte,
            payload_valid => payload_valid,
            payload_count => open,
            capture_wr_ptr => open,
            done_latched => open,
            error_latched => open
            );         
end architecture;
