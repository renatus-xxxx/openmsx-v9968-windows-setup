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
void stream_spans(const u8 *packets) __z88dk_fastcall;
void floor_draw(const int *parameters);
void water_capture(void);
void scene_label(u8 scene);
void title_restore(void);
void water_draw(const u8 *parameters);
#endif


