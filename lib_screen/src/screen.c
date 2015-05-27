#include "screen.h"
#include "font8x8.h"


unsigned char g_screen[SCREENMAXY][SCREENMAXX];
void screen_putc(unsigned x, unsigned y, char c){
	g_screen[y][x]=c;
}
void screen_puts(unsigned x, unsigned y, const char s[]){
	int pos=0;
	do{
		char c= s[pos];
		if (!c) return;
		g_screen[y][x+pos++]=c;
	}while(1);
}
void screen_init(){
	for (unsigned y=0; y< SCREENMAXY; y++){
		for (unsigned x=0; x< SCREENMAXX; x++){
			g_screen[y][x]=0;
		}
	}
}


void screen_line(unsigned y,  unsigned bufi[]){
	unsigned short* buf=(unsigned short*)bufi;
	if (!buf) return;
	if (y>=TEXTAREAINPIXELS){
		//if (y<10) for (int i=0; i<480; i++) buf[i]=0xFFFF;
		return;
	}
	unsigned cy= y >> 3;
	unsigned py= y & 0x07;
	const unsigned short color= 0x0000;
	unsigned bp=0;
	for (unsigned cx = 0; cx<SCREENMAXX; cx++){
		unsigned char c= g_screen[cy][cx];
		if ((!c) || (c==32)){
			bp+=8;
			continue;
		}
		//unsigned char c='A';
		unsigned char fmask=MASKCHARSET( c, py);
		//unsigned char fmask= 0x55;
//#pragma loop unroll(8)
		for (unsigned char px=0; px<8; px++){
			if ( fmask & (128>>px))
				{buf[bp]=color;}
			else{
				buf[bp]=0xFFFF;
			}
			bp++;
		}
	}
}
