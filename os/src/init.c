#include "interrupt.h"
#include "types.h"

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
#define VDP_REGISTER_SELECT (*((volatile u8*)0xF7FC))
#define VDP_REGISTER_DATA (*((volatile u8*)0xF7FD))
#define VDP_VRAM_DATA (*((volatile u8*)0xF7FE))

#define VDP_REG_WRITE_ADDR_L 0x00
#define VDP_REG_WRITE_ADDR_H 0x01
#define VDP_REG_READ_ADDR_L 0x02
#define VDP_REG_READ_ADDR_H 0x03

void init(void) {
    IO_PORT = 0xff;

    // enable interrupts
    IRQ_ENABLE();

    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_L;
    VDP_REGISTER_DATA = 0x00;
    VDP_REGISTER_SELECT = VDP_REG_WRITE_ADDR_H;
    VDP_REGISTER_DATA = 0x00;

    VDP_REGISTER_SELECT = VDP_REG_READ_ADDR_L;
    VDP_REGISTER_DATA = 0x00;
    VDP_REGISTER_SELECT = VDP_REG_READ_ADDR_H;
    VDP_REGISTER_DATA = 0x00;

    VDP_VRAM_DATA = 0x00;

    srand(1234);

    // loop forever
    while(1) { idle(); }
}

static u16 name_addr = 0, tile_addr = 0;
void delay(void) {
    u16 i = 0x1000;
    while(i) {
        --i;
        ++name_addr;
    }
}

static u8 ctr = 0;
void idle(void) {
    IO_PORT = ++ctr;
    VDP_VRAM_DATA = rand();
    //VDP_VRAM_DATA = VDP_VRAM_DATA;
    delay();
}
