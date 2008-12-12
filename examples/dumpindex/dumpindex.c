/* Simple example program to list off an archive's contents */

#include <stdio.h>
#include <stdlib.h>
#include "earc.h"

static void showidx(const char *filename, const void *data, size_t len) {
	printf("%s (%d bytes)\n", filename, (int)len);
	if (earc_lookup(filename, NULL))
		printf("found\n");
}

void mbed_index() { }

int main(void) {
	earc_forall(showidx);
}
