#ifndef __KLIB_H__
#define __KLIB_H__

#include <stddef.h>

#define KPRN_INFO   0
#define KPRN_WARN   1
#define KPRN_ERR    2
#define KPRN_DBG    3

char *kstrcpy(char *, char *);
size_t kstrlen(char *);
int kstrcmp(char *, char *);
int kstrncmp(char *, char *, size_t);
void kprint(int type, char *fmt, ...);

void *kmemset(void *, int, size_t);
void *kmemcpy(void *, void*, size_t);
int kmemcmp(void *, void *, size_t);
void *memmove(void *, void *, size_t);


#endif
