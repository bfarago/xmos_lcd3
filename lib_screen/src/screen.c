#include "screen.h"
#include "font8x8.h"

//global ascii memory, just a quick trial version...
unsigned char g_screen[SCREENMAXY][SCREENMAXX];
//some config parameters for the ascii mem.
s_screenTextConfig g_screenTextConfig=
    {.color=RGB(15,31,8), .background=0, .maxtw=SCREENMAXX, .maxth=SCREENMAXY, .offspx=0, .offspy=0};

//Windows/rectangles management globals
#define MAXREC (5)
s_screenRect g_screenBkg[MAXREC];
unsigned g_screenRecMax=1;


//add hex digits
void screen_puth(unsigned x, unsigned y, unsigned h, char digit)
{
    for (int i=0;i<digit; i++){
        unsigned char d= h&0x0f; h>>=4;
        screen_putc(x+(digit-i-1), y, d<10? '0'+d :'a'+d-10);
    }
}

/*
//TODO: deffinitely I need some similar later
void screen_putd(unsigned x, unsigned y, unsigned h, char digit)
{
    for (int i=0;i<digit; i++){
        unsigned char d= h&0x0f; h>>=4;
        screen_putc(x+(digit-i-1), y, d<10? '0'+d :'a'+d-10);
    }
}*/

//add one char somewhere to the screen
void screen_putc(unsigned x, unsigned y, char c){
	g_screen[y][x]=c;
}

//set characters on the screen like a text string
void screen_puts(unsigned x, unsigned y, const char s[]){
	int pos=0;
	do{
		char c= s[pos];
		if (!c) return;
		g_screen[y][x+pos++]=c;
	}while(1);
}

//Add a Rectangle, returns by the id of this record.
unsigned screenAddRec(unsigned x1, unsigned y1, unsigned x2, unsigned y2,unsigned color, unsigned background)
{
    if (g_screenRecMax>MAXREC) return 0;
    g_screenBkg[g_screenRecMax].x1=x1;
    g_screenBkg[g_screenRecMax].y1=y1;
    g_screenBkg[g_screenRecMax].x2=x2;
    g_screenBkg[g_screenRecMax].y2=y2;
    g_screenBkg[g_screenRecMax].color=color;
    g_screenBkg[g_screenRecMax].background=background;
    return g_screenRecMax++;
}

//Change rectangle coordinates and colors
void screenSetRec(unsigned id, unsigned x, unsigned y, unsigned width, unsigned height, unsigned color, unsigned background)
{
    if (id>MAXREC) return ;
    s_screenRect* p= &g_screenBkg[id];
    p->x1=x; p->y1=y;
    p->x2= p->x1+width;
    p->y2= p->y1+height;
    p->color=color; p->background=background;
}

//Init ascii mem, t
void screen_init(){
    s_screenTextConfig * cfg=&g_screenTextConfig;
    s_screenRect* rec= &g_screenBkg[0]; //fullscreen rectangle
    rec->color= cfg->color;
    rec->background= cfg->background;
    rec->y1= 0;
    rec->y2= 272;
    rec->x1= 0;
    rec->x2= 480;

	for (unsigned y=0; y< cfg->maxth; y++){
		for (unsigned x=0; x< cfg->maxtw; x++){
			g_screen[y][x]=0;
		}
	}

}
s_screenRect* screen_rec(unsigned x, unsigned y)
{
    s_screenRect *rec= & g_screenBkg[0];
    for (int i=0; i<g_screenRecMax; i++){
       s_screenRect *r= & g_screenBkg[i];
       if ( r->y1 >y) continue;
       if ( r->y2 <y) continue;
       if ( r->x1 >x) continue;
       if ( r->x2 <x) continue;
       rec=r;
    }
    return rec;
}
void screen_rasterbkg( unsigned pwidth, unsigned line, unsigned bufi[]){
    unsigned short* buf=(unsigned short*)bufi;
    unsigned background= g_screenTextConfig.background;
    for (unsigned x=0; x < pwidth ; x++){
        s_screenRect* rec=screen_rec( x, line);
        if (rec) background=rec->background;
                buf[x]=background;
    }
}
void screen_rastertxt(unsigned py,  unsigned bufi[]){
	unsigned short* buf=(unsigned short*)bufi;
	if (!buf) return;
	s_screenTextConfig* cfg=&g_screenTextConfig;
	unsigned y= py + cfg->offspy;
	unsigned maxy=cfg->maxth*8;
	if (y>=maxy)return;
	unsigned cy= y >> 3;
	unsigned ry= y & 0x07;
	 unsigned short color= cfg->color;
	 unsigned short background= cfg->background;

	unsigned btx= 0;
	unsigned bpx= 0;
	unsigned bp=cfg->offspx;
	if (cfg->offspx<0){
	    btx= (-cfg->offspx)>>3;
	    bp=0;
	    bpx= (-cfg->offspx)&7;
	}


	for (unsigned cx =btx; cx< cfg->maxtw; cx++){
		unsigned char c= g_screen[cy][cx];
		if ((!c) || (c==32)){
			bp+=8;
			continue;
		}
		unsigned char fmask=MASKCHARSET( c, ry);
//#pragma loop unroll(8)
		for (unsigned char px=bpx; px<8; px++){
		    s_screenRect* rec=screen_rec( bp, py);
		    if (rec) {
		        color=rec->color;
		        background=rec->background;
		    }
			if ( fmask & (128>>px))
				{buf[bp]=color;}
			else{
				buf[bp]=background;
			}
			bp++;
		}
		bpx=0;
	}
}

