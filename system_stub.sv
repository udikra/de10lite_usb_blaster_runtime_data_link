// system_stub.sv  -  placeholder for the main design (sys_clk domain)
//
// Registers: drives SWJR register 8 + n with the bitwise inverse of JWSR
// register n (n = 0..5), so both bridge directions can be checked from the
// host. JWSR 5..7 and SWJR 14..15 belong to sys_access.sv.
//
// System address space: a 16384 x 32-bit (64 KiB) RAM answering the sa_* bus,
// aliased every 64 KiB (word address sa_addr[15:2]). It takes each request
// from the cycle with sa_enable high and keeps it until served; to exercise the
// handshake, an LFSR delays the service at random, so sa_ready comes 1 or more
// cycles after the request (2 on average).
module system_stub (
    input  wire              clk,
    input  wire              rst_n,
    input  wire  [5:0][31:0] jwsr,
    output logic [5:0][31:0] swjr,

    input  wire  [31:0]      sa_addr,
    input  wire              sa_enable,
    input  wire              sa_wr,
    input  wire  [31:0]      sa_data_out,
    output logic [31:0]      sa_data_in,
    output logic             sa_ready
);
    always @(posedge clk) begin
        if (!rst_n) swjr <= '0;
        else        swjr <= ~jwsr;
    end

    reg [15:0] lfsr = 16'hACE1;
    always @(posedge clk)
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

    // The RAM is not reset, so it survives KEY[0].
    reg  [31:0] mem [0:16383];
    reg         pending;                    // a request waits for service
    reg  [13:0] p_word;
    reg         p_wr;
    reg  [31:0] p_data;
    wire [13:0] word  = sa_enable ? sa_addr[15:2] : p_word;
    wire        wr    = sa_enable ? sa_wr       : p_wr;
    wire [31:0] wdata = sa_enable ? sa_data_out : p_data;
    wire        serve = (sa_enable || pending) && lfsr[0];

    always @(posedge clk) begin
        if (sa_enable) begin
            p_word <= sa_addr[15:2];
            p_wr <= sa_wr;
            p_data <= sa_data_out;
        end
        if (serve) begin
            if (wr)
                mem[word] <= wdata;
            sa_data_in <= mem[word];
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            pending <= 1'b0;
            sa_ready <= 1'b0;
        end else begin
            pending <= (sa_enable || pending) && !serve;
            sa_ready <= serve;
        end
    end
endmodule
