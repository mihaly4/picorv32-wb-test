IVERILOG = iverilog

IVFLAGS = -DSIM

RISCV_CROSS_COMPILE ?= /opt/abcross/riscv64/bin/riscv64-aosc-linux-gnu-

RISCV_AS = $(RISCV_CROSS_COMPILE)as
RISCV_GCC = $(RISCV_CROSS_COMPILE)gcc
RISCV_LD = $(RISCV_CROSS_COMPILE)ld
RISCV_OBJCOPY = $(RISCV_CROSS_COMPILE)objcopy

TD ?= td

VERILOG_SOURCES = top.v \
		  wb_ram_1.0/rtl/verilog/wb_ram.v \
		  wb_intercon.v wb_intercon_1.1/rtl/verilog/wb_mux.v \
		  picorv32_wrapper.v \
		  uart16550_1.5.4/rtl/verilog/uart_top.v uart16550_1.5.4/rtl/verilog/uart_wb.v uart16550_1.5.4/rtl/verilog/uart_regs.v uart16550_1.5.4/rtl/verilog/uart_receiver.v uart16550_1.5.4/rtl/verilog/uart_transmitter.v uart16550_1.5.4/rtl/verilog/uart_rfifo.v uart16550_1.5.4/rtl/verilog/uart_tfifo.v uart16550_1.5.4/rtl/verilog/raminfr.v uart16550_1.5.4/rtl/verilog/uart_sync_flops.v \
		  sdr_ctrl/rtl/lib/async_fifo.v sdr_ctrl/rtl/lib/sync_fifo.v sdr_ctrl/rtl/top/sdrc_top.v sdr_ctrl/rtl/core/sdrc_core.v sdr_ctrl/rtl/core/sdrc_bank_fsm.v sdr_ctrl/rtl/core/sdrc_define.v sdr_ctrl/rtl/core/sdrc_bs_convert.v sdr_ctrl/rtl/core/sdrc_req_gen.v sdr_ctrl/rtl/core/sdrc_xfr_ctl.v sdr_ctrl/rtl/core/sdrc_bank_ctl.v sdr_ctrl/rtl/wb2sdrc/wb2sdrc.v

SIM_ONLY_SOURCES = wb_ram_1.0/rtl/verilog/wb_ram_generic.v sdram_sim/mt48lc2m32b2.v sdram_sim.v

SYNTHESIS_ONLY_SOURCES = wb_ram_al_bram.v al_ip/al_ip_bram_simple_dual_emb9k_4kbyte.v sdram_al_eg4s20.v

VVP = vvp

%.vcd: %.vvp
	$(VVP) $(VVPFLAGS) -n $<

sim: top_tb.vcd
bitstream: picorv32-wb-test.bit
program: picorv32-wb-test.bit
	$(TD) program.tcl

top_tb.vcd: top_tb.vvp firmware.hex

top_tb.vvp: top_tb.v $(VERILOG_SOURCES) $(SIM_ONLY_SOURCES)
	iverilog $(IVFLAGS) -s top_tb -o top_tb.vvp top_tb.v $(VERILOG_SOURCES) $(SIM_ONLY_SOURCES)
wb_intercon.v: wb_intercon.conf
	utils/wb_intercon_gen $< $@

wb_intercon.vh: wb_intercon.v

start.o: start.S
	$(RISCV_AS) -march=rv32imc $< -o $@

main.o: main.c
	$(RISCV_GCC) -march=rv32imc -mabi=ilp32 -c $< -o $@

firmware.elf: main.o start.o ldscript.lds
	$(RISCV_LD) start.o main.o -m elf32lriscv -T ldscript.lds -o $@

firmware.bin: firmware.elf
	$(RISCV_OBJCOPY) -O binary $< $@

firmware.hex: firmware.bin gen_4bword_hex
	./gen_4bword_hex < firmware.bin > firmware.hex

firmware.mif: firmware.bin gen_mif
	./gen_mif 1024 < firmware.bin > firmware.mif

picorv32-wb-test.bit: picorv32-wb-test.al td.tcl $(VERILOG_SOURCES) $(SYNTHESIS_ONLY_SOURCES) firmware.mif
	$(TD) td.tcl
