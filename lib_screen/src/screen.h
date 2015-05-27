#ifndef _SCREEN_H_
#define _SCREEN_H_
#ifndef __XC__
#include "xccompat.h"
#endif

#define SCREENMAXX (60)
#define SCREENMAXY (2)
#define TEXTAREAINPIXELS (SCREENMAXY*8 +1)

void screen_init();
void screen_putc(unsigned x, unsigned y, char c);
void screen_puts(unsigned x, unsigned y, const char s[]);
void screen_line(unsigned y, unsigned buf[]);

#endif
