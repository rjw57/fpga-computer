#include "interrupt.h"
#include "types.h"
#include "font.h"

// Defined by linker
extern u8 *_DATA_RUN__, *_DATA_LOAD__;
extern u16 _DATA_SIZE__;

int rand();
void srand (unsigned seed);

// Entry point for OS. When called interrupts are disabled, zero-page is
// initialised to zero and the stack pointer is set up.
//
// This function should not exit.
void init(void);

// Idle loop routine. Called repeatedly until the end of time.
void idle(void);

#define PATTERN_TABLE_BASE 0x2000

#define IO_PORT (*((volatile u8*)0x8400))
#define VDP_REGISTER_SELECT (*((volatile u8*)0xC000))
#define VDP_REGISTER_DATA (*((volatile u8*)0xC001))
#define VDP_VRAM_DATA (*((volatile u8*)0xC002))

#define VDP_REG_READ_ADDR_L     0x00
#define VDP_REG_READ_ADDR_H     0x01
#define VDP_REG_WRITE_ADDR_L    0x02
#define VDP_REG_WRITE_ADDR_H    0x03
#define VDP_REG_H_DISPLAYED     0x04
#define VDP_REG_H_BLANK         0x05
#define VDP_REG_H_FRONT_PORCH   0x06
#define VDP_REG_V_DISPLAYED     0x07
#define VDP_REG_V_BLANK         0x08
#define VDP_REG_V_FRONT_PORCH   0x09
#define VDP_REG_SYNC_LENGTHS    0x0a
#define VDP_REG_PTRN_TBL_BASE_L 0x0b
#define VDP_REG_PTRN_TBL_BASE_H 0x0c
#define VDP_REG_NAME_TBL_BASE_L 0x0d
#define VDP_REG_NAME_TBL_BASE_H 0x0e
#define VDP_REG_ATTR_TBL_BASE_L 0x0f
#define VDP_REG_ATTR_TBL_BASE_H 0x10

void vdp_set_reg(u8 reg, u8 value);
void vdp_set_addr(u8 low_reg, u16 value);
void vdp_mode_640x480(void);
void vdp_mode_848x480(void);

void copy_font(void);
void clear_attribute(void);
void clear_palette(void);

void delay(u16 i);

void init(void) {
    IO_PORT = 0xff;

    // enable interrupts
    IRQ_ENABLE();

    vdp_set_addr(VDP_REG_READ_ADDR_L, 0x1234);
    vdp_set_addr(VDP_REG_WRITE_ADDR_L, 0x1234);
    VDP_VRAM_DATA = 0x5a;
    vdp_set_addr(VDP_REG_WRITE_ADDR_L, 0x0000);
    VDP_VRAM_DATA = 0x88;

    // Change screen mode
    vdp_mode_640x480();
    //vdp_mode_848x480();

    copy_font();
    //clear_attribute();
    clear_palette();

    vdp_set_addr(VDP_REG_WRITE_ADDR_L, 0x0000);
    vdp_set_addr(VDP_REG_READ_ADDR_L, 0x0000);
    vdp_set_addr(VDP_REG_NAME_TBL_BASE_L, 0x0000);
    vdp_set_addr(VDP_REG_ATTR_TBL_BASE_L, 0x2800);

    srand(1234);

    // loop forever
    while(1) { idle(); }
}

void vdp_set_reg(u8 reg, u8 value) {
    VDP_REGISTER_SELECT = reg;
    VDP_REGISTER_DATA = value;
}

void vdp_set_addr(u8 low_reg, u16 value) {
    vdp_set_reg(low_reg, value & 0xff);
    vdp_set_reg(low_reg + 1, (value >> 8) & 0xff);
}

void vdp_mode_640x480(void) {
    const u8 h_displayed_chars      = 80;
    const u8 h_blank_chars          = 22;
    const u8 h_sync_polarity        = 0;
    const u8 h_front_porch_chars    = 2;
    const u8 h_sync_len_chars       = 5;

    const u8 v_displayed_chars      = 60;
    const u8 v_blank_lines          = 40;
    const u8 v_sync_polarity        = 0;
    const u8 v_front_porch_lines    = 1;
    const u8 v_sync_len_lines       = 3;

    vdp_set_reg(VDP_REG_H_DISPLAYED, h_displayed_chars-1);
    vdp_set_reg(VDP_REG_H_BLANK, h_blank_chars-1);
    vdp_set_reg(VDP_REG_H_FRONT_PORCH,
        (h_sync_polarity ? 0x80 : 0x00) | (h_front_porch_chars - 1));
    vdp_set_reg(VDP_REG_V_DISPLAYED, v_displayed_chars-1);
    vdp_set_reg(VDP_REG_V_BLANK, v_blank_lines-1);
    vdp_set_reg(VDP_REG_V_FRONT_PORCH,
        (v_sync_polarity ? 0x80 : 0x00) | (v_front_porch_lines - 1));
    vdp_set_reg(VDP_REG_SYNC_LENGTHS,
        (v_sync_len_lines << 4) | h_sync_len_chars);
}

void vdp_mode_848x480(void) {
    const u8 h_displayed_chars      = 106;
    const u8 h_blank_chars          = 30;
    const u8 h_sync_polarity        = 1;
    const u8 h_front_porch_chars    = 2;
    const u8 h_sync_len_chars       = 14;

    const u8 v_displayed_chars      = 60;
    const u8 v_blank_lines          = 37;
    const u8 v_sync_polarity        = 1;
    const u8 v_front_porch_lines    = 6;
    const u8 v_sync_len_lines       = 8;

    vdp_set_reg(VDP_REG_H_DISPLAYED, h_displayed_chars-1);
    vdp_set_reg(VDP_REG_H_BLANK, h_blank_chars-1);
    vdp_set_reg(VDP_REG_H_FRONT_PORCH,
        (h_sync_polarity ? 0x80 : 0x00) | (h_front_porch_chars - 1));
    vdp_set_reg(VDP_REG_V_DISPLAYED, v_displayed_chars-1);
    vdp_set_reg(VDP_REG_V_BLANK, v_blank_lines-1);
    vdp_set_reg(VDP_REG_V_FRONT_PORCH,
        (v_sync_polarity ? 0x80 : 0x00) | (v_front_porch_lines - 1));
    vdp_set_reg(VDP_REG_SYNC_LENGTHS,
        (v_sync_len_lines << 4) | h_sync_len_chars);
}

void clear_attribute(void) {
    u16 i;

    vdp_set_addr(VDP_REG_WRITE_ADDR_L, 0x1000);

    for(i=0; i<4096; i++) {
        VDP_VRAM_DATA = rand();
    }
}

void clear_palette(void) {
    u16 i;

    vdp_set_addr(VDP_REG_WRITE_ADDR_L, 0x2800);

    for(i=0; i<0x2000; i++) {
        VDP_VRAM_DATA = i;
    }
}

void copy_font(void) {
    u16 i;
    const u8* font = font_bin;

    vdp_set_addr(VDP_REG_PTRN_TBL_BASE_L, PATTERN_TABLE_BASE);
    vdp_set_addr(VDP_REG_WRITE_ADDR_L, PATTERN_TABLE_BASE);

    for(i=0; i<2048; i++, font++) {
        VDP_VRAM_DATA = *font;
    }
}

void delay(u16 i) {
    while(i) {
        --i;
    }
}

static u16 ctr = 0, ctr2 = 0;
void idle(void) {
    if(ctr2 == 0x2000) {
        IO_PORT = (u8)(++ctr);
        vdp_set_addr(VDP_REG_WRITE_ADDR_L, 0x0000);
        vdp_set_addr(VDP_REG_READ_ADDR_L, 0x0000);
        //ctr2 = 1;
        //VDP_VRAM_DATA = rand();
    } else {
        VDP_VRAM_DATA = ctr2 & 0xff; // rand();
        ++ctr2;
        delay(0x2000);
    }
}
