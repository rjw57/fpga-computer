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

#define IO_PORT (*((u8*)0x8400))

#define NAME_TABLE ((u8*)0x8000)
#define TILE_TABLE ((u8*)0xA000)

void init(void) {
    // enable interrupts
    IRQ_ENABLE();

    srand(1234);

    // loop forever
    while(1) { idle(); }
}

void delay(void) {
    //u16 i = 0x2000;
    u16 i = 0x20;
    while(i) { --i; }
}

static u8 ctr = 0;
static u16 name_addr = 0, tile_addr = 0;
void idle(void) {
    //delay();
    IO_PORT = ++ctr;
    return;

    NAME_TABLE[(name_addr<<1)] = rand();
    NAME_TABLE[(name_addr<<1)+1] = rand();
    /*
    NAME_TABLE[(name_addr<<1)+1] = rand();
    TILE_TABLE[(tile_addr<<1)] = rand();
    TILE_TABLE[(tile_addr<<1)+1] = rand();
    */
    tile_addr = (tile_addr + 1) & 0x07ff;

    if(name_addr != 0x0fff) {
        name_addr = (name_addr + 1) & 0x0fff;
    }
}
