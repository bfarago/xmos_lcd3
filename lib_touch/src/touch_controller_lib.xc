#include "touch_controller_lib.h"
#include <xs1.h>

//AD7879-1

//#define ENABLE_TOUCHPRESSURE

ts_data g_ts_data;

#define DEV_ADDR 0x2c
#define CNTL_REG1 0x01
#define CNTL_REG2 0x02
#define CNTL_REG3 0x03
#define Y_REG 0x08
#define X_REG 0x09
#define Z1_REG 0x0A
#define Z2_REG 0x0B
#define AUX_REG 0x0C
#define TEMP_REG 0x0D
#define REVID_REG 0X0E

#define SETREG1(pendis, chnadd, adcmode, acq, tmr )\
    (( (pendis&1)<<15 ) | ( (chnadd&7)<<12 ) | ((adcmode&3)<<10)  | ((acq&3)<<8) | (tmr&255) )
#define SETREG2(pm, gpioen, gpiodat, gpiodir, gpiopol, single,  avg, med, reset, fcd)\
    (( (pm&3)<<14 ) | ( (gpioen&1)<<13 ) | ((gpiodat&1)<<12)  | ((gpiodir&1)<<11) |((gpiopol&1)<<10) |((single&1)<<9)\
    |((avg&3)<<7) | ((med&3)<<5) |((reset&1)<<4) |(fcd&7) )
#define SETREG3(tm, am, intm, alert, auxl, auxh,  tl, th, x,y,z1,z2,aux,vbat,temp) \
    (( (tm&1)<<15 ) |( (am&1)<<14 ) | ( (intm&1)<<13 ) | ((alert&1)<<12)  | ((auxl&1)<<11) |((auxh&1)<<10) |((tl&1)<<9) |((th&1)<<8)\
    |((x&1)<<7)  |((y&1)<<6) | ((z1&1)<<5) |((z2&1)<<4)\
    |((aux&1)<<3)  |((vbat&1)<<2)  |((temp&1)<<1)  )

    // control register 1 setting
    // [15]=0 pen intr enabled;[14:12]=000 ADC channel for manual conversion, not applicable; [11:10]=11 ADC master mode;
    // [9:8]=ADC acquisition time to 16 microsec; [7:0]=0000 0011 conversion interval timer to 620 microsec

#define CNTL_WORD1_MS_BYTE 0x0f
#define CNTL_WORD1_LS_BYTE 0x03

    // control register 2 setting
    // Bits [15:14]=01 power save mode; [13:10]=0000 GPIO disabled; [9]=0 ratiometric conversion for greater accuracy;
    // [8:7]=01 4 middle values chosen for averaging filter; [6:5]=10 8 measurements for median filters;
    // These filters may be used for noise suppression. See pg.17 of AD7879/AD7889 spec
    // [4]=0 SW reset disabled; [3:0]=1111 ADC first conversion delay set to 4.096ms
    // To disable median filter, choose [8:5]=0000;  Eg. data[0]=0x40; data[1]=0x0f;

#define CNTL_WORD2_MS_BYTE 0x40
#define CNTL_WORD2_LS_BYTE 0xcf

    // control register 3 setting
    // [15]=1 temperature intr disabled; [14]=1 AUX interrupt disabled; [13]=1 INT but disbled if bit 15 of CR1 id 0 (fig.38)
    // [12]=1 GPIO intr disabled; [11:9]=0000 limit check disabled as not applicable; [7:6]=11 YX measurement enabled
    // [5:0]=000000 other measurements disabled

#define CNTL_WORD3_MS_BYTE 0xf0
#define CNTL_WORD3_LS_BYTE 0xc0

#pragma unsafe arrays
void touch_lib_init(client i2c_master_if i2c, in port tspinirq ) {
    unsigned time;
    timer t;
    i2c_regop_res_t res; //low byte, high byte
    //res= i2c.write_reg16_addr8(DEV_ADDR, CNTL_REG2, 0xcf40 );
    //res= i2c.write_reg16_addr8(DEV_ADDR, CNTL_REG3, 0xf0f0 );
    //res= i2c.write_reg16_addr8(DEV_ADDR, CNTL_REG1, 0x030f );
    res= i2c.write_reg16msbf_addr8(DEV_ADDR, CNTL_REG2, SETREG2(1, 0,0,0,0, 0, 1,2, 0,15 ));
#ifdef ENABLE_TOUCHPRESSURE
    res= i2c.write_reg16msbf_addr8(DEV_ADDR, CNTL_REG3, SETREG3(1,1,1,1,  0,0,  0,0,  1,1,1,1, 0,0,0));
#else
    res= i2c.write_reg16msbf_addr8(DEV_ADDR, CNTL_REG3, SETREG3(1,1,1,1,  0,0,  0,0,  1,1,0,0, 0,0,0));
#endif
    res= i2c.write_reg16msbf_addr8(DEV_ADDR, CNTL_REG1, SETREG1(0, 0,3,3,3));
    t :> time;
    t when timerafter(time+1000000):>void;  // wait for the touch screen controller to settle down
    tspinirq when pinseq(1) :> void;        // wait for pen interrupt to go high
    g_ts_data.xmax=g_ts_data.ymax=0;
    g_ts_data.xmin=TOUCH_LIB_TS_WIDTH;
    g_ts_data.xmin=TOUCH_LIB_TS_HEIGHT;
    g_ts_data.xmirror=1;
    g_ts_data.ymirror=1;
    g_ts_data.counter=0;
}

#pragma unsafe arrays
void touch_lib_get_touch_coords(client i2c_master_if i2c, unsigned &x, unsigned &y){
    i2c_regop_res_t res;
    y=i2c.read_reg16_addr8(DEV_ADDR, Y_REG, res);
    x=i2c.read_reg16_addr8(DEV_ADDR, X_REG, res);
    /*i2c_regop_res_t res;
    unsigned z1, z2, aux, temp;
    z1=i2c.read_reg16_addr8(DEV_ADDR, Z1_REG, res);
    z2=i2c.read_reg16_addr8(DEV_ADDR, Z2_REG, res);
    aux=i2c.read_reg16_addr8(DEV_ADDR, AUX_REG, res);
    temp=i2c.read_reg16_addr8(DEV_ADDR, TEMP_REG, res);*/
}

select touch_lib_touch_event(in port penirq){
  case penirq when pinseq(0):>int:
  break;
}

void touch_lib_get_next_coord(client i2c_master_if i2c, in port irq, unsigned &x, unsigned &y)
{
  touch_lib_touch_event(irq);
  touch_lib_get_touch_coords(i2c, x, y);
}

void touch_lib_scale_coords(unsigned &x, unsigned &y){
    if (x>g_ts_data.xmax)g_ts_data.xmax=x;
    if (y>g_ts_data.ymax)g_ts_data.ymax=y;
    if (x<g_ts_data.xmin)g_ts_data.xmin=x;
    if (y<g_ts_data.ymin)g_ts_data.ymin=y;
    int xsize= g_ts_data.xmax-g_ts_data.xmin;
    int ysize= g_ts_data.ymax-g_ts_data.ymin;
    x-=g_ts_data.xmin;
    y-=g_ts_data.ymin;
    if (xsize<1) xsize=TOUCH_LIB_TS_WIDTH;
    if (ysize<1) ysize=TOUCH_LIB_TS_HEIGHT;
    x = (x*TOUCH_LIB_LCD_WIDTH)/xsize;	// corresponds to column
	y = (y*TOUCH_LIB_LCD_HEIGHT)/ysize;	// corresponds to row
	if (g_ts_data.xmirror) x=TOUCH_LIB_LCD_WIDTH-x;
	if (g_ts_data.ymirror) y=TOUCH_LIB_LCD_HEIGHT-y;
}
//[[distributable]]
void ts_server(server interface ts2app_i  ts2app, client i2c_master_if i2c, in port tspinirq ){
    touch_lib_init(i2c, tspinirq);
    i2c_regop_res_t res;
    unsigned ts_x=0;
    unsigned ts_y=0;
    unsigned ts_z1=0;
    unsigned ts_z2=0;
    unsigned ts_temp=0;
    timer tmr;
    unsigned t;
    unsigned period=10000;
    while(1){
        select{
         case tspinirq when pinseq(0):>int:
                   {
                       touch_lib_get_touch_coords(i2c, ts_x, ts_y);
#ifdef ENABLE_TOUCHPRESSURE
                       ts_z1=i2c.read_reg16_addr8(DEV_ADDR, Z1_REG, res);
                       ts_z2=i2c.read_reg16_addr8(DEV_ADDR, Z2_REG, res);
#endif
                       touch_lib_scale_coords(ts_x, ts_y);
                       ts2app.touch();

                   }break;
         case ts2app.pop() -> {unsigned x, unsigned y, unsigned t}: {
                      x=ts_x;
                      y=ts_y;
                      t=1;
                      break;
                  }
         case ts2app.getTemp()->{unsigned temp}:{
             temp=ts_temp;
             break;
         }
         case ts2app.getZ()->{unsigned z1, unsigned z2}:{
             z1=ts_z1;
             z2=ts_z2;
             break;
         }
         case period=> tmr when timerafter(t):>void:
             ts_temp=i2c.read_reg16_addr8(DEV_ADDR, TEMP_REG, res);
             tmr:>t;
             t+=period;
             break;
        }
    }
}
