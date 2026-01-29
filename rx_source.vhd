library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rx_source is
    generic (
        paylen : natural := 32
);
    port (
        clk : in std_logic;
        rst : in std_logic;
        
        out_byte : out std_logic_vector(7 downto 0);
        out_valid : out std_logic;
        out_sof : out std_logic;
        out_eof : out std_logic;
        out_err : out std_logic
);
end entity; 

architecture rtl of rx_source is
function crc32next(
    crc_in : std_logic_vector(31 downto 0);
    d : std_logic_vector(7 downto 0)
) return std_logic_vector is
    variable crc : unsigned(31 downto 0) := unsigned(crc_in);
    variable b : unsigned(7 downto 0) := unsigned(d);
begin
      crc := crc XOR resize(b, 32);
      for i in 0 to 7 loop
        if (crc(0) = '1') then
            crc := shift_right(crc, 1) XOR x"EDB88320";
        else 
            crc := shift_right(crc, 1);
        end if;
      end loop;
      return std_logic_vector(crc);
end function;
type hdr_t is array (0 to 13) of std_logic_vector(7 downto 0);
constant HDR : hdr_t := (
    x"01", x"02", x"03", x"04", x"05", x"06", x"0A", x"0B", x"0C", x"0D", x"0E", x"0F", x"08", x"00" );
    type state_t is (send_hdr, send_pay, send_fcs);
    signal state : state_t := send_hdr;
    
    signal hdr_i : unsigned(4 downto 0) := (others => '0');
    signal pay_i : unsigned(15 downto 0) := (others => '0');
    signal fcs_i : unsigned(2 downto 0) := (others => '0');
    
    signal crc_reg : std_logic_vector(31 downto 0) := (others => '1');
    signal lfsr : std_logic_vector(7 downto 0) := x"a5";
    signal fcs_word : std_logic_vector(31 downto 0) := (others => '0');

begin
    out_valid <= '1';
    out_err <= '0';
    
    process(clk)
        variable next_crc : std_logic_vector(31 downto 0);
        variable fb : std_logic;
        variable fcs_final : std_logic_vector(31 downto 0);
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                state <= send_hdr;
                pay_i <= (others => '0');
                fcs_i <= (others => '0');
                hdr_i <= (others => '0');
                crc_reg <= (others => '1');
                lfsr <= x"A5";
                fcs_word <= (others => '0');
                out_byte <= (others => '0');
                out_sof <= '0';
                out_eof <= '0';
            else
                out_sof <= '0';
                out_eof <= '0';
                
            case state is 
                when send_hdr =>
                    out_byte <= hdr(to_integer(hdr_i));
                    if (hdr_i = to_unsigned(0, hdr_i'length)) then
                        out_sof <= '1';
                        crc_reg <= (others => '1');
                    end if;
                    next_crc := crc32next(crc_reg, hdr(to_integer(hdr_i)));
                    crc_reg <= next_crc;
                    if (hdr_i = to_unsigned(13, hdr_i'length)) then
                        hdr_i <= (others => '0');
                        pay_i <= (others => '0');
                        state <= send_pay;
                    else    
                    hdr_i <= hdr_i + 1;
                    end if;
                when send_pay =>
                -- x^8 + x^6 + x^5 + x^4 + 1
                fb := lfsr(7) xor lfsr(5) xor lfsr(4) xor lfsr(3);
                lfsr <= lfsr(6 downto 0) & fb; 
                out_byte <= lfsr;
                next_crc := crc32next(crc_reg, lfsr);
                crc_reg <= next_crc;
                if (pay_i = to_unsigned(paylen - 1, pay_i'length)) then
                    fcs_final := not next_crc;
                    fcs_word <= fcs_final;
                    fcs_i <= (others => '0');
                    state <= send_fcs;
                else    
                    pay_i <= pay_i + 1;
                end if;
                
                when send_fcs => 
                    case to_integer(fcs_i) is
                        when 0 => out_byte <= fcs_word(7 downto 0);
                        when 1 => out_byte <= fcs_word(15 downto 8);
                        when 2 => out_byte <= fcs_word(23 downto 16);
                        when 3 => out_byte <= fcs_word(31 downto 24);
                        when others => out_byte <= (others => '0');
                    end case;
                    if (fcs_i = to_unsigned(3, fcs_i'length)) then
                        out_eof <= '1';
                        state <= send_hdr;
                        hdr_i <= (others => '0');
                        pay_i <= (others => '0');
                    else 
                        fcs_i <= fcs_i + 1;
                    end if;
            end case;
        end if;
    end if;
end process;
end architecture;               