#ifndef _SCREEN_H_
#define _SCREEN_H_
#ifndef __XC__
#include "xccompat.h"
#endif

#define SCREENMAXX (60)
#define SCREENMAXY (34)
#define TEXTAREAINPIXELS (SCREENMAXY*8 +1)

#define RGB(r, g, b) (( (b)<<11 ) | ( (g)<<5 ) | (r))

//text array config. Somehow it will be integrated to rectangles later...
typedef struct {
    unsigned short color;
    unsigned short background;
    unsigned short maxtw; //textual width
    unsigned short maxth; //textual height
    int offspx; //pixel offset x
    int offspy; //pixel offset y
} s_screenTextConfig;

typedef struct {
    unsigned short x1;
    unsigned short y1;
    unsigned short x2; // x2>x1 !
    unsigned short y2; // y2>y1 !
    unsigned short z;  //not used yet, Add function must be called in z order...
    unsigned short background;
    unsigned short color;
} s_screenRect;

extern s_screenTextConfig g_screenTextConfig;

void screen_init();

//put something to ascii screen memory
void screen_puth(unsigned x, unsigned y, unsigned h, char digit); //hex digits
void screen_putc(unsigned x, unsigned y, char c);           //only one ascii character
void screen_puts(unsigned x, unsigned y, const char s[]);   //ascii string

//render one h raster line
void screen_rasterbkg( unsigned pwidth,unsigned line, unsigned bufi[]);
void screen_rastertxt(unsigned y, unsigned buf[]);

//color memory/rectangles
unsigned screenAddRec(unsigned x1, unsigned y1, unsigned x2, unsigned y2,unsigned color, unsigned background);
void screenSetRec(unsigned id, unsigned x, unsigned y, unsigned width, unsigned height, unsigned color, unsigned background);

#endif
