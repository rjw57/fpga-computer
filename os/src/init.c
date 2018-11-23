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

void init(void) {
    IO_PORT = 0xff;

    // enable interrupts
    IRQ_ENABLE();

    srand(1234);

    // loop forever
    while(1) { idle(); }
}

static u16 name_addr = 0, tile_addr = 0;
void delay(void) {
    u16 i = 0x2000;
    while(i) {
        --i;
        NAME_TABLE[20] = rand();
        //NAME_TABLE[name_addr & 0x0FFF] = rand();
        ++name_addr;
    }
}

static u8 ctr = 0;
void idle(void) {
    IO_PORT = ++ctr;
    delay();
}
