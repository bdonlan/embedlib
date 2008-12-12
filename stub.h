#ifndef H_##HEADERNAME##
#define H_##HEADERNAME##

#include <stdlib.h>

const void *##PREFIX##lookup(const char *name, size_t *out_filesize);
void ##PREFIX##forall(
		void (*iter)(const char *name, const void *data, size_t size)
		);

#endif /* H_##HEADERNAME## */
