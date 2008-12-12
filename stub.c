#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

/* Indirect through MBED_CAT* here so we don't end up with the literal
 * "MBED_PREFIXname"
 */
#define MBED_CAT_2(a, b) a ## b
#define MBED_CAT(a, b) MBED_CAT_2(a, b)
#define MBED_EXPORT(name) MBED_CAT(MBED_PREFIX, name)

struct ient {
	const char *filename;
	const void *start, *end;
};

extern const struct ient mbed_index[];
extern const int mbed_index_ct;

extern char mbed_data_start, mbed_data_end;
static void __attribute__ ((constructor)) protect_data(void) {

	size_t pagesz = sysconf(_SC_PAGE_SIZE);
	size_t len = &mbed_data_end - &mbed_data_start;
	assert(len % pagesz == 0);

	if(mprotect(&mbed_data_start, len, PROT_READ)) {
		perror("mprotecting embedded data");
		abort();
	}
}

static int lookup_cmp(const void *vp1, const void *vp2) {
	const struct ient *p1, *p2;
	p1 = vp1; p2 = vp2;
	return strcmp(p1->filename, p2->filename);
}

const void *MBED_EXPORT(lookup)(const char *name, size_t *out_filesize) {
	struct ient *p, key;
	key.filename = name;
	p = bsearch(&key, mbed_index, mbed_index_ct, sizeof(key), lookup_cmp);

	if (!p)
		return NULL;
	if (out_filesize)
		*out_filesize = (char *)p->end - (char *)p->start;
	return p->start;
}

void MBED_EXPORT(forall)(
		void (*iter)(const char *name, const void *data, size_t size)
		) {
	for (const struct ient *p = mbed_index; p->filename; p++) {
		iter(p->filename, p->start, (char *)p->end - (char *)p->start);
	}
}
