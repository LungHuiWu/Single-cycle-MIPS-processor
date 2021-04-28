// Your SingleCycle MIPS code

module CHIP(clk,
            rst_n,
            // for mem_D
            mem_wen_D,
            mem_addr_D,
            mem_wdata_D,
            mem_rdata_D,
            // for mem_I
            mem_addr_I,
            mem_rdata_I
    );

    //===================// parameters //===================//
    parameter word_length = 32;
    parameter reg_addr_length = 5;
    parameter mem_addr_length = 32;
    parameter inst_addr_length = 32;
    parameter reg_num = 32;
    parameter link_size = 28;
    integer   i;

    //===================// I/O //===================//
    input         clk, rst_n ;
    // for mem_D
    output        mem_wen_D  ;  // mem_wen_D is high, CHIP writes data to D-mem; else, CHIP reads data from D-mem
    output [mem_addr_length-1:0]    mem_addr_D ;  // the specific address to fetch/store data 
    output [word_length-1:0]        mem_wdata_D;  // data writing to D-mem 
    input  [word_length-1:0]        mem_rdata_D;  // data reading from D-mem
    // for mem_I
    output [mem_addr_length-1:0]    mem_addr_I ;  // the fetching address of next instruction
    input  [word_length-1:0]        mem_rdata_I;  // instruction reading from I-mem
    
    //===================// regs and wires //===================//
    // Next state logic
    reg    [inst_addr_length-1:0]   PC;
    reg    [inst_addr_length-1:0]   PC_nxt;
    reg    [word_length-1:0]        R       [0:reg_num-1];
    reg    [word_length-1:0]        R_nxt   [0:reg_num-1];
    // control signal
    wire    [1:0]   RegDst;
    wire            Jump;
    wire            Branch;
    wire    [1:0]   MemtoReg;
    wire    [1:0]   ALUOp;
    wire            MemWrite;
    wire            ALUSrc;
    wire            RegWrite;
    wire            JumpReg;
    // ALU control
    reg     [2:0]    ALUControl;
    // Read & write registers
    reg     [word_length-1:0]       ReadRegData1;
    reg     [word_length-1:0]       ReadRegData2;
    reg     [reg_addr_length-1:0]   WriteRegNum;
    reg     [word_length-1:0]       WriteData;
    // ALU result
    reg     [mem_addr_length-1:0]   ALUResult;
    reg                             Zero;
    // medium
    wire    [mem_addr_length-1:0]   SignExtend;
    wire    [mem_addr_length-1:0]   ALUInput2;
    wire    [inst_addr_length-1:0]  ShiftLeftAdd;
    wire    AndOut;
    wire    [inst_addr_length-1:0]  PCadd4;
    wire    [link_size-1:0]         ShiftLeftLink;
    wire    [inst_addr_length-1:0]  Linked;
    wire    [inst_addr_length-1:0]  PCAddResult;
    wire    [inst_addr_length-1:0]  PCChoice1;
    wire    [inst_addr_length-1:0]  PCChoice2;

    //===================// wire assignment //===================//
    // control signal generation
    assign  RegDst[1]   = (mem_rdata_I[31:26] == 3);
    assign  RegDst[0]   = (mem_rdata_I[31:26] == 0);
    assign  Jump        = (mem_rdata_I[31:26] == 2) || (mem_rdata_I[31:26] == 3);
    assign  ALUSrc      = (mem_rdata_I[31:26] == 35) || (mem_rdata_I[31:26] == 43);
    assign  MemtoReg[1] = (mem_rdata_I[31:26] == 3);
    assign  MemtoReg[0] = (mem_rdata_I[31:26] == 35);
    assign  RegWrite    = ((mem_rdata_I[31:26] == 0) || (mem_rdata_I[31:26] == 35) || (mem_rdata_I[31:26] == 3)) && (mem_rdata_I[5:0] != 8);
    assign  MemWrite    = (mem_rdata_I[31:26] == 43);
    assign  Branch      = (mem_rdata_I[31:26] == 4);
    assign  ALUOp[1]    = (mem_rdata_I[31:26] == 0);
    assign  ALUOp[0]    = (mem_rdata_I[31:26] == 4);
    assign  JumpReg     = (mem_rdata_I[31:26] == 0) && (mem_rdata_I[5:0] == 8);
    // Output
    assign  mem_addr_I      = PC;
    assign  mem_wen_D       = MemWrite;
    assign  mem_addr_D      = ALUResult;
    assign  mem_wdata_D     = ReadRegData2;
    // Sign extension
    assign  SignExtend = $signed(mem_rdata_I[15:0]);
    // ALU Input
    assign  ALUInput2 = ALUSrc ? SignExtend : ReadRegData2;
    // Shift left 2
    assign  ShiftLeftAdd = SignExtend << 2;
    // And gate
    assign  AndOut = Branch & Zero;
    // PC + 4
    assign  PCadd4 = PC + 4;
    // Shift left link
    assign  ShiftLeftLink = {mem_rdata_I[25:0], 2'b00};
    // Link
    assign  Linked = {PCadd4[31:28], ShiftLeftLink};
    // Add ALU result
    assign  PCAddResult = PCadd4 + ShiftLeftAdd;
    // Mux 1
    assign  PCChoice1 = AndOut ? PCAddResult : PCadd4;
    // Mux 2
    assign  PCChoice2 = Jump ? Linked : PCChoice1;

    //===================// Combinational part //===================//
    always@(*)begin
        // initial data
        for (i=0; i<reg_num; i=i+1)begin
            R_nxt[i]        = R[i];
        end
        // ALU control generation
        case (ALUOp)
            0: ALUControl = 2; // add
            1: ALUControl = 6; // subtract
            2: case (mem_rdata_I[3:0])
                4'b0000: ALUControl = 2; // add
                4'b0010: ALUControl = 6; // subtract
                4'b0100: ALUControl = 0; // and
                4'b0101: ALUControl = 1; // or
                4'b1010: ALUControl = 7; // set on less than
                default: ALUControl = 0;
            endcase
            default: ALUControl = 0;
        endcase
        // Read
        ReadRegData1 = R[mem_rdata_I[25:21]];
        ReadRegData2 = R[mem_rdata_I[20:16]];
        // Write register
        case (RegDst)
            0: WriteRegNum = mem_rdata_I[20:16];
            1: WriteRegNum = mem_rdata_I[15:11];
            2: WriteRegNum = 31;
            default: WriteRegNum = 0;
        endcase
        // Write data for reg mem
        case (MemtoReg)
            0: WriteData = ALUResult;
            1: WriteData = mem_rdata_D;
            2: WriteData = PCadd4;
            default: WriteData = 0;
        endcase
        // ALU result
        case (ALUControl)
            2: begin
                ALUResult = ReadRegData1 + ALUInput2;
                Zero = 0;
            end 
            6: begin
                ALUResult = ReadRegData1 - ALUInput2;
                Zero = (ALUResult == 0);
            end
            0: begin
                ALUResult = ReadRegData1 & ALUInput2;
                Zero = 0;
            end
            1: begin
                ALUResult = ReadRegData1 | ALUInput2;
                Zero = 0;
            end
            7: begin
                ALUResult = ($signed(ReadRegData1) < $signed(ALUInput2));
                Zero = 0;
            end
            default: begin
                ALUResult = 0;
                Zero = 0;
            end
        endcase
        // Update PCnxt
        if (JumpReg) begin
            PC_nxt = ReadRegData1;
        end else begin
            PC_nxt = PCChoice2;
        end
        // Write reg
        if (RegWrite) begin
            R_nxt[WriteRegNum] = WriteData;
        end
    end

    //===================// Sequential part //===================//
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            PC              <= 0;
            for (i=0; i<reg_num; i=i+1)begin
                R[i]        <= 0;
            end
        end
        else begin
            PC              <= PC_nxt;
            for (i=0; i<reg_num; i=i+1)
                R[i]        <= R_nxt[i];
        end
    end

endmodule