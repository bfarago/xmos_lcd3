#ifndef TOUCH_CONTROLLER_LIB_H_
#define TOUCH_CONTROLLER_LIB_H_

/*
 *
 *
 */

#include <i2c.h>

#define TOUCH_LIB_TS_WIDTH 4096
#define TOUCH_LIB_TS_HEIGHT 4096
#define TOUCH_LIB_LCD_WIDTH 480
#define TOUCH_LIB_LCD_HEIGHT 272

interface ts2app_i {
    [[notification]] slave void touch();
    [[clears_notification]] {unsigned, unsigned, unsigned} pop(); //guarded,
    {unsigned} getTemp();
    {unsigned,unsigned} getZ();
};

//[[distributable]]
void ts_server(server interface ts2app_i  ts2app,client i2c_master_if i2c, in port tspinirq );

typedef struct {
    in port PENIRQ;     /**< The pen-down interrupt line */
}touch_controller_ports;

typedef struct {
    unsigned xmin;
    unsigned xmax;
    unsigned ymin;
    unsigned ymax;
    unsigned counter;
    unsigned char xmirror;
    unsigned char ymirror;
    //touch_controller_ports
} ts_data;
extern ts_data g_ts_data;
/*
 * Implementation Specific
 */

/** \brief The touch controller initialisation.
 *
 * \param ports The structure containing the touch controller port details.
 */
void touch_lib_init(client i2c_master_if i2c, in port tspinirq);

/** \brief Get the current touch coordinates from the touch controller.
 * The returned coordinates are not scaled.
 *
 * \param ports The structure containing the touch controller port details.
 * \param x The X coordinate of point of touch.
 * \param y The Y coordinate of point of touch.
 */
void touch_lib_get_touch_coords(client i2c_master_if i2c, unsigned &x, unsigned &y);

/** \brief A select function that will wait until the touch controller reports
 * a touch event.
 *
 * \param ports The structure containing the touch controller port details.
 */
select touch_lib_touch_event(in port penirq);


/** \brief This function will block until the controller reports a touch event at
 * which point it will return the coordinates of that event. The coordinates are
 * not scaled.
 *
 * \param ports The structure containing the touch controller port details.
 * \param x The X coordinate of point of touch.
 * \param y The Y coordinate of point of touch.
 */
void touch_lib_get_next_coord(client i2c_master_if i2c, in port irq, unsigned &x, unsigned &y);

/** \brief The function to scale coordinate values (from the touch point
 * coordinates to the LCD pixel coordinates)
 *
 * \param x The scaled X coordinate value
 * \param y The scaled Y coordinate value
 */
void touch_lib_scale_coords(unsigned &x, unsigned &y);

#endif /* TOUCH_CONTROLLER_LIB_H_ */
