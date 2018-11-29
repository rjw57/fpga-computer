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

#define IO_PORT (*((volatile u8*)0x8400))
#define VDP_REGISTER_SELECT (*((volatile u8*)0xC000))
#define VDP_REGISTER_DATA (*((volatile u8*)0xC001))
#define VDP_VRAM_DATA (*((volatile u8*)0xC002))

#define VDP_REG_WRITE_ADDR_L 0x00
#define VDP_REG_WRITE_ADDR_H 0x01
#define VDP_REG_READ_ADDR_L 0x02
#define VDP_REG_READ_ADDR_H 0x03
#define VDP_NAME_TABLE_BASE_L 0x04
#define VDP_NAME_TABLE_BASE_H 0x05
#define VDP_ATTRIBUTE_TABLE_BASE_L 0x06
#define VDP_ATTRIBUTE_TABLE_BASE_H 0x07
#define VDP_PATTERN_TABLE_BASE_L 0x08
#define VDP_PATTERN_TABLE_BASE_H 0x09
#define VDP_PALETTE_TABLE_BASE_L 0x0A
#define VDP_PALETTE_TABLE_BASE_H 0x0B

void copy_font(void);
void clear_attribute(void);
void clear_palette(void);

void init(void) {
    IO_PORT = 0xff;

    // enable interrupts
    IRQ_ENABLE();

    copy_font();
    clear_attribute();
    clear_palette();

    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_L;
    VDP_REGISTER_DATA = 0x00;
    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_H;
    VDP_REGISTER_DATA = 0x00;

    VDP_REGISTER_SELECT = VDP_REG_READ_ADDR_L;
    VDP_REGISTER_DATA = 0x00;
    VDP_REGISTER_SELECT = VDP_REG_READ_ADDR_H;
    VDP_REGISTER_DATA = 0x01;

    srand(1234);

    // loop forever
    while(1) { idle(); }
}

void clear_attribute(void) {
    u16 i;

    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_L;
    VDP_REGISTER_DATA = 0x00;
    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_H;
    VDP_REGISTER_DATA = 0x10;

    for(i=0; i<4096; i++) {
        VDP_VRAM_DATA = rand();
    }
}

void clear_palette(void) {
    u16 i;

    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_L;
    VDP_REGISTER_DATA = 0x00;
    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_H;
    VDP_REGISTER_DATA = 0x28;

    for(i=0; i<64; i++) {
        VDP_VRAM_DATA = rand();
        VDP_VRAM_DATA = 0x00;
    }
}

void copy_font(void) {
    u16 i;
    const u8* font = font_bin;

    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_L;
    VDP_REGISTER_DATA = 0x00;
    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_H;
    VDP_REGISTER_DATA = 0x20;

    for(i=0; i<2048; i++, font++) {
        VDP_VRAM_DATA = *font;
    }
}

static u16 name_addr = 0, tile_addr = 0;
void delay(void) {
    u16 i = 0x0800;
    while(i) {
        --i;
        ++name_addr;
    }
}

static u16 ctr = 0, ctr2 = 0;
void idle(void) {
    IO_PORT = (u8)(++ctr);
    ++ctr2;

    if(ctr == 0x2000) {
        ctr = 0;
        VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_L;
        VDP_REGISTER_DATA = 0x00;
        VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_H;
        VDP_REGISTER_DATA = 0x00;

        VDP_REGISTER_SELECT = VDP_REG_READ_ADDR_L;
        VDP_REGISTER_DATA = 0x01;
        VDP_REGISTER_SELECT = VDP_REG_READ_ADDR_H;
        VDP_REGISTER_DATA = 0x00;
    }

    VDP_VRAM_DATA = rand();
    //VDP_VRAM_DATA = ctr;
    //VDP_VRAM_DATA = VDP_VRAM_DATA;

    /*
    if(ctr == 0x1000) {
        ctr = 0;
        VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_L;
        VDP_REGISTER_DATA = 0x00;
        VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_H;
        VDP_REGISTER_DATA = 0x00;
    }
    VDP_VRAM_DATA = ((ctr & 0x1000) ? 0x0f : 0xff) & rand();
    //VDP_VRAM_DATA = VDP_VRAM_DATA;
    */
    //delay();
}
