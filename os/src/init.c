#include "interrupt.h"
#include "types.h"

// Defined by linker
extern u8 *_DATA_RUN__, *_DATA_LOAD__;
extern u16 _DATA_SIZE__;

// Entry point for OS. When called interrupts are disabled, zero-page is
// initialised to zero and the stack pointer is set up.
//
// This function should not exit.
void init(void);

// Idle loop routine. Called repeatedly until the end of time.
void idle(void);

#define IO_PORT (*((u8*)0x8400))

void init(void) {
    // enable interrupts
    IRQ_ENABLE();

    // loop forever
    while(1) { idle(); }
}

void delay(void) {
    u16 i = 0x2000;
    while(i) { --i; }
}

static u8 ctr = 0;
void idle(void) {
    delay();
    IO_PORT = ++ctr;
}
