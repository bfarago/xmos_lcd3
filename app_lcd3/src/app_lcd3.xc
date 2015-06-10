/*
 * app_lcd3.xc
 *
 *  Created on: 2015.05.27.
 *      Author: Barna
 */


#include <sdram.h>
#include <lcd.h>
#include <display_controller.h>
#include <screen.h>
#include <touch_controller_lib.h>
#include <i2c.h>

#define LCDTILE tile[0]
#define LCD_WIDTH (480)
#define LCD_HEIGHT (272)
#define LCD_ROW_WORDS (LCD_WIDTH)
#define LCD_BYTES_PER_PIXEL (2)
#define DISPLAY_CONTROLLER_IMAGE_COUNT (2)

/*
 XMOS XP-SKC-L2 (1V1, 1v2)
 Star: XA-SK-SDRAM
 Triangle: XA-SK-SCR480
*/
on LCDTILE : out buffered port:32 lcd_rgb = XS1_PORT_16B;
on LCDTILE : out port lcd_clk = XS1_PORT_1I;
on LCDTILE : out port ?lcd_data_enabled = XS1_PORT_1L;
on LCDTILE : out buffered port:32 ?lcd_h_sync = XS1_PORT_1J;
on LCDTILE : out port ?lcd_v_sync = XS1_PORT_1K;
on LCDTILE : clock lcd_cb = XS1_CLKBLK_1;

on LCDTILE : port ts_scl = XS1_PORT_1E;
on LCDTILE : port ts_sda = XS1_PORT_1H;
on LCDTILE : port ts_irq = XS1_PORT_1D;

on LCDTILE : out buffered port:32 sdram_dq_ah = XS1_PORT_16A;
on LCDTILE : out buffered port:32 sdram_cas = XS1_PORT_1B;
on LCDTILE : out buffered port:32 sdram_ras = XS1_PORT_1G;
on LCDTILE : out buffered port:8 sdram_we = XS1_PORT_1C;
on LCDTILE : out port sdram_clk = XS1_PORT_1F;
on LCDTILE : clock sdram_cb = XS1_CLKBLK_2;

//quick buffer, preliminary...
unsigned  row1[LCD_ROW_WORDS];

unsigned renderline(client interface app_to_cmd_buffer_i app2cmd, unsigned & fblcd, unsigned & line, unsigned* movable & p)
{
    unsigned fbid=1-fblcd;
    const unsigned woffs=0;
    if (!p) return 0;
    if (line== TEXTAREAINPIXELS) {
        display_controller_frame_buffer_commit(app2cmd, fbid);
        //fbid=1-fbid;
        line=0;
        return 1;
    }
    screen_rasterbkg(LCD_WIDTH, line, p);
    screen_rastertxt(line, p);
    display_controller_write(app2cmd, move(p), fbid, line, LCD_ROW_WORDS, woffs);
    line++;
    return 1;
}
unsigned*movable getres(client interface res_buf_to_app_i res2app){
    e_command_return_val ret;
    unsigned r;
    unsigned* movable p;
    { p, r}= res2app.pop();
    ret=r;
     switch (ret){
       case CMD_SUCCESS:
           if (!p) break;
           //renderline(app2cmd, line, move(p));
           //busy=1;
           break;
       case CMD_OUT_OF_RANGE:
       case CMD_MODIFY_CURRENT_FB:
           break;
     }
     return move(p);
}

void app(
        client interface app_to_cmd_buffer_i app2cmd,
        client interface res_buf_to_app_i res2app,
        client interface dc_vsync_interface_i vsync,
        client interface ts2app_i ts2app)
{
   //touch_lib_init(i2c, ts_irq);
   unsigned ts_x=0;
   unsigned ts_y=0;
   unsigned ts_t=0;
   unsigned ts_z1=0;
   unsigned ts_z2=0;
   screen_init();
   screen_puts(0,0,"Hello World!");
   screen_puts(0,1,"This is a test application.");
   screen_puth(0,2,0x1234abc, 7);
   screen_puth(10,2,0x1234abc, 7);
   screen_puth(20,2,0x1234abc, 7);
   screenAddRec(10,40,400,70, RGB(15,0,0) , RGB(0,0,15)); //some test rectangles
   screenAddRec(12,42,398,68, RGB(15,0,0) , RGB(0,31,0));
   unsigned cursorid=screenAddRec(12,42,398,68, RGB(15,0,0) , RGB(15,31,15)); //cursor
   for (int i=3; i<SCREENMAXY; i++) screen_puth(0,i,i,2);//line numbers

   unsigned line=0;
   //buffer
#define MAXQUICKBUF (2)
   unsigned * movable buffers[MAXQUICKBUF]={row1};
   unsigned * movable ptr=move(buffers[0]);
   //state variables
   unsigned rvsync=0;   //vertical syncron received.
   unsigned busy=1;     //buffer ptr is busy / moved to DC
   unsigned resready=1; //res ready? hmm
   //statistical variables
   unsigned cmdcounter=0;
   unsigned vsynccounter=0;
   unsigned rescounter=0;
   unsigned ts_temp=0;
   /*   display_controller_read( app2cmd, move(ptr), fbid, line, LCD_ROW_WORDS, woffs);
   */
   timer tmr;
   unsigned time;
   tmr :> time;
   while (1){
#pragma ordered
        select {
            case vsync.update():
                vsynccounter++;
                rvsync=vsync.vsync();
                if (!resready && busy){
                    busy=renderline(app2cmd, rvsync, line, ptr);
                    //update screen
                    screen_puth(0,2,vsynccounter, 7);
                    screen_puth(10,2,ts_x, 7);
                    screen_puth(20,2,ts_y, 7);
                    screen_puth(30,2,ts_z1, 7);
                    screen_puth(40,2,ts_z2, 7);
                    screen_puth(50,2,ts_temp, 7);
                    {ts_temp}=ts2app.getTemp();
                    //g_screenTextConfig.offspy=-127+((vsynccounter>>2)&0xFF); //test. Move the ascii overlay on the screen.
                    //g_screenTextConfig.offspx=-127+((vsynccounter>>2)&0xFF) ;
                    //move cursor
                    screenSetRec(cursorid, ts_x, ts_y, 10, 10, 0, RGB(vsynccounter&15, vsynccounter&15, vsynccounter&15));
                }
               break;
//send next cmnd
            case  (resready > 0) =>app2cmd.ready():{
                if (ptr) {
                    busy=renderline(app2cmd, rvsync, line, ptr);
                }
                cmdcounter++;
                resready--;
               }
               break;
//get last result
            case (!resready) => res2app.ready():{
                resready++;  rescounter++;
                ptr=getres(res2app);
                }
                break;
//preliminary, the touch thread must be somewhere else, it takes a lot of time in this actual implementation...
            case ts2app.touch():// when pinseq(0):>int:
            {
                {ts_x, ts_y, ts_t}=ts2app.pop();
                {ts_z1, ts_z2}=ts2app.getZ();

            }break;
        }
    }
}

int main(){
    interface app_to_cmd_buffer_i app_to_cmd_buffer;
    interface cmd_buffer_to_dc_i cmd_buffer_to_dc;
    interface dc_to_res_buf_i dc_to_res_buf;
    interface res_buf_to_app_i res_buf_to_app;
    interface dc_vsync_interface_i vsync_interface;
    interface memory_address_allocator_i to_memory_alloc[1];
    i2c_master_if i2c[1];
    interface ts2app_i ts2app;
    streaming chan c_lcd;
    streaming chan c_sdram[DISPLAY_CONTROLLER_IMAGE_COUNT];
    par {
        on LCDTILE: [[distribute]] memory_address_allocator( 1, to_memory_alloc, 0, 1024*1024*8); //8Mbyte
        on LCDTILE: [[distribute]] command_buffer(app_to_cmd_buffer, cmd_buffer_to_dc);
        on LCDTILE: display_controller(
                cmd_buffer_to_dc, dc_to_res_buf, vsync_interface,
                DISPLAY_CONTROLLER_IMAGE_COUNT, LCD_HEIGHT, LCD_WIDTH, LCD_BYTES_PER_PIXEL,
                to_memory_alloc[0], c_sdram[0], c_sdram[1], c_lcd);
        on LCDTILE: [[distribute]] response_buffer(dc_to_res_buf, res_buf_to_app);
        on LCDTILE: sdram_server(c_sdram, 2, sdram_dq_ah, sdram_cas, sdram_ras, sdram_we, sdram_clk, sdram_cb, 2, 128, 16, 8,12, 2, 64, 4096, 4);
        on LCDTILE: lcd_server( c_lcd, lcd_rgb, lcd_clk, lcd_data_enabled, lcd_h_sync, lcd_v_sync, lcd_cb, LCD_WIDTH, LCD_HEIGHT, 5, 40, 1, 8, 8, 1, data16_port16, 3);
        on LCDTILE: i2c_master(i2c, 1, ts_scl, ts_sda, 400);
        on LCDTILE: ts_server(ts2app, i2c[0], ts_irq);
        on LCDTILE: app(app_to_cmd_buffer, res_buf_to_app, vsync_interface, ts2app);
    }
    return 0;
}
