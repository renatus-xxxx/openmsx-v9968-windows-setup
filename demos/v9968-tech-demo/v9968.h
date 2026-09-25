#ifndef V9968_DEMO_V9968_H
#define V9968_DEMO_V9968_H
typedef unsigned char u8;
typedef unsigned int u16;
extern volatile u16 ticks;
extern u8 back_page;
void reg(u8 r,u8 v);
void clock_poll(void);
void music_tick(void);
void silence(void);
void rect(int x,int y,int w,int h,u8 c);
void line(int x,int y,int xx,int yy,u8 c);
void flip(void);
void palette(u8 phase);
void orb_draw(int x,int y);

void panel_draw(const int *parameters);
void video_stop(void);
void background(void);
void background_load(u8 bank);
u8 video_init(void);
void timer_start(void);
u16 clock_ticks(void);
void textures_load(void);
void stream_spans(const u8 *packets);
void floor_draw(const int *parameters);
void water_prepare(u8 frame);
void water_work_reset(void);
void palette_glow(void);
void stream_spans_glow(const u8 *packets) __z88dk_fastcall;
void trail_clear(void);
void trail_decay(u8 mask,u8 page);
void feedback_shift(int dx,int dy);
void feedback_warp(int vx,int vy);
void feedback_capture(void);
void header_shadow(u8 scene);
void shallow_enter(void);
void shallow_leave(void);
void shallow_draw(u16 now);
void shallow_palette(void);
void water_draw(const u8 *parameters);
#endif


