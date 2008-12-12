#include "nullsub.h"
#include <stdio.h>
#include <stdlib.h>

int main() {
	size_t s;
	void *p;
	void (*fp)();
	p = earc_lookup("null-sub.x64", &s);
	if (!p) {
		printf("Can't find null-sub.x64 in archive!");
		return 0;
	}
	printf("Found null sub at %p (%zu bytes)\n", p, s);
	printf("Now trying to execute it...\n");
	fp = (void (*)())p;
	fp();
	printf("Looks like execute prevention didn't work!\n");
	return 0;
}
