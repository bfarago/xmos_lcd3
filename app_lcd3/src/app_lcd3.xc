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

on LCDTILE : out buffered port:32 sdram_dq_ah = XS1_PORT_16A;
on LCDTILE : out buffered port:32 sdram_cas = XS1_PORT_1B;
on LCDTILE : out buffered port:32 sdram_ras = XS1_PORT_1G;
on LCDTILE : out buffered port:8 sdram_we = XS1_PORT_1C;
on LCDTILE : out port sdram_clk = XS1_PORT_1F;
on LCDTILE : clock sdram_cb = XS1_CLKBLK_2;

//quick buffers
unsigned  row1[LCD_ROW_WORDS];
unsigned  row2[LCD_ROW_WORDS];
void app(client interface app_to_cmd_buffer_i app2cmd, client interface res_buf_to_app_i res2app, client interface dc_vsync_interface_i vsync)
{
   unsigned fbid=1;
   screen_init();
   screen_puts(0,0,"Hello World!");
   unsigned woffs=0;
   unsigned line=TEXTAREAINPIXELS;
   //buffer
#define MAXQUICKBUF (2)
   unsigned * movable buffers[MAXQUICKBUF]={row1, row2};
   unsigned * movable ptr=move(buffers[0]);
   //state variables
   unsigned rvsync=0;   //vertical syncron received.
   unsigned busy=1;     //buffer ptr is busy / moved to DC
   unsigned resready=0; //res ready? hmm
   //statistical variables
   unsigned cmdcounter=0;
   unsigned vsynccounter=0;
   unsigned rescounter=0;
   /*   display_controller_read( app2cmd, move(ptr), fbid, line, LCD_ROW_WORDS, woffs);
        screen_line(line, ptr);
        display_controller_write(app2cmd, move(ptr), fbid, line, LCD_ROW_WORDS, woffs);
        display_controller_frame_buffer_commit(app2cmd, fbid);
   */
   timer tmr;
   unsigned time;
   tmr :> time;
   while (1){
        select {
            case tmr when timerafter(time) :> unsigned time:
               { //temporary test code, to feed the dc somehow ?!
                if (!busy&& rvsync){
                    if (!ptr) break;
                    if (!line) {
                        display_controller_frame_buffer_commit(app2cmd, fbid);
                        fbid=1-fbid;
                        rvsync=0;
                        busy=1;
                        line=TEXTAREAINPIXELS;
                        break;
                    }
                    line--;
                    screen_line(line, ptr);
                    display_controller_write(app2cmd, move(ptr), fbid, line, LCD_ROW_WORDS, woffs);
                    busy=1;
                }
                time+=100;
               }break;
            case vsync.update():
                rvsync=1; vsynccounter++;
                break;

            case app2cmd.ready():{
                //this called once before init (see: display_controller)
                busy=0; //we can send one ( or more ) commands
                cmdcounter++;
               }
            break;

            case res2app.ready():{
                //response, but never arrives here?
                e_command_return_val ret;
                unsigned* movable p;
                { p, ret}= res2app.pop();
                resready=1; rescounter++;
                if (!p){
                   ptr=move(p);
                }
               /* switch (ret){
                    case CMD_SUCCESS:
                        if (!line) break;
                        line--;
                        screen_line(line, ptr);
                        display_controller_write(app2cmd, move(ptr), fbid, line, LCD_ROW_WORDS, woffs);
                        break;
                    case CMD_OUT_OF_RANGE:
                    case CMD_MODIFY_CURRENT_FB:
                        break;
                  }
                */
                }
                break;
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

        on LCDTILE: app(app_to_cmd_buffer, res_buf_to_app, vsync_interface);
    }
    return 0;
}
