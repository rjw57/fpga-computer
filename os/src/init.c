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
#define VDP_REG_H_CHARS         0x11

#define BOX_VERT                0xB3
#define BOX_HORIZ               0xC4
#define BOX_TL                  0xDA
#define BOX_TR                  0xBF
#define BOX_BL                  0xC0
#define BOX_BR                  0xD9
#define BOX_L_BAR               0xB4
#define BOX_R_BAR               0xC3

static u8 scr_width, scr_height;
static u16 attr_base, name_base;

void vdp_set_reg(u8 reg, u8 value);
void vdp_set_addr(u8 low_reg, u16 value);
void vdp_mode_640x480(void);
void vdp_mode_848x480(void);

void copy_font(void);
void clear_attribute(void);

void delay(u16 i);

void box(u8 left, u8 top, u8 width, u8 height, u8 attr);

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
    clear_attribute();

    vdp_set_addr(VDP_REG_WRITE_ADDR_L, 0x0000);
    vdp_set_addr(VDP_REG_READ_ADDR_L, 0x0000);

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

    scr_width = h_displayed_chars;
    scr_height = v_displayed_chars >> 1;
    name_base = 0;
    attr_base = scr_width * scr_height;

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

    vdp_set_reg(VDP_REG_H_CHARS, scr_width);

    vdp_set_addr(VDP_REG_NAME_TBL_BASE_L, name_base);
    vdp_set_addr(VDP_REG_ATTR_TBL_BASE_L, attr_base);
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

    scr_width = h_displayed_chars;
    scr_height = v_displayed_chars >> 1;
    name_base = 0;
    attr_base = scr_width * scr_height;

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

    vdp_set_reg(VDP_REG_H_CHARS, scr_width);

    vdp_set_addr(VDP_REG_NAME_TBL_BASE_L, name_base);
    vdp_set_addr(VDP_REG_ATTR_TBL_BASE_L, attr_base);
}

void box(u8 left, u8 top, u8 width, u8 height, u8 attr) {
    u8 r, c;
    for(r=0; r<height; ++r) {
        vdp_set_addr(VDP_REG_WRITE_ADDR_L, name_base + ((r+top)*scr_width) + left);
        if(width > 0) {
            if(r == 0) {
                VDP_VRAM_DATA = BOX_TL;
            } else if(r == (height-1)) {
                VDP_VRAM_DATA = BOX_BL;
            } else {
                VDP_VRAM_DATA = BOX_VERT;
            }
        }
        if(((r==0) || (r==(height-1))) && (width > 2)) {
            for(c=0; c<width-2; ++c) {
                VDP_VRAM_DATA = BOX_HORIZ;
            }
        } else {
            for(c=0; c<width-2; ++c) {
                VDP_VRAM_DATA = ' ';
            }
        }
        if(width > 1) {
            if(r == 0) {
                VDP_VRAM_DATA = BOX_TR;
            } else if(r == (height-1)) {
                VDP_VRAM_DATA = BOX_BR;
            } else {
                VDP_VRAM_DATA = BOX_VERT;
            }
        }
        vdp_set_addr(VDP_REG_WRITE_ADDR_L, attr_base + ((r+top)*scr_width) + left);
        for(c=0; c<width; ++c) {
            VDP_VRAM_DATA = attr;
        }
    }
}

void clear_attribute(void) {
    u16 i;

    vdp_set_addr(VDP_REG_WRITE_ADDR_L, attr_base);

    for(i=0; i<scr_width*scr_height; i++) {
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

void at(u8 x, u8 y, u8 c, u8 attr) {
    vdp_set_addr(VDP_REG_WRITE_ADDR_L, name_base + x + (y * scr_width));
    VDP_VRAM_DATA = c;
    vdp_set_addr(VDP_REG_WRITE_ADDR_L, attr_base + x + (y * scr_width));
    VDP_VRAM_DATA = attr;
}

static u16 ctr = 0, ctr2 = 0, state = 0;
void idle(void) {
    box(0, 0, scr_width, scr_height, 0x4F);

    while(1) {
        at(
            1 + (rand() % (scr_width-2)),
            1 + (rand() % (scr_height-2)),
            rand() & 0xff,
            rand() & 0x0f | 0x40
        );

        if(ctr2 == 0x100) {
            IO_PORT = (u8)(++ctr);
            ctr2 = 0;
        } else {
            ++ctr2;
        }
    }
}
