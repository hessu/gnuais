
#ifndef AUDIOUNIT_H
#define AUDIOUNIT_H
#ifdef HAVE_AUDIOUNIT

extern int audiounit_initialize(const char *device);
extern int audiounit_read(short *buffer, int len);

#endif
#endif
