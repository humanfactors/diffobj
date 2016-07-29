#ifndef MBA_DIFF_H
#define MBA_DIFF_H

/* diff - compute a shortest edit script (SES) given two sequences
 */

#ifdef __cplusplus
extern "C" {
#endif

/*
#ifndef LIBMBA_API
#ifdef WIN32
# ifdef LIBMBA_EXPORTS
#  define LIBMBA_API  __declspec(dllexport)
# else // LIBMBA_EXPORTS
#  define LIBMBA_API  __declspec(dllimport)
# endif // LIBMBA_EXPORTS
#else // WIN32
# define LIBMBA_API extern
#endif // WIN32
#endif // LIBMBA_API
*/

typedef enum {
        DIFF_NULL = 0,
	DIFF_MATCH,
	DIFF_DELETE,
	DIFF_INSERT
} diff_op;

struct diff_edit {
	short op;
	int off; /* off into s1 if MATCH or DELETE but s2 if INSERT */
	int len;
};

/* consider alternate behavior for each NULL parameter
 */
int diff(SEXP a, int aoff, int n,
  SEXP b, int boff, int m,
  void *context, int dmax,
  struct diff_edit *ses, int *sn
);

#ifdef __cplusplus
}
#endif

#endif /* MBA_DIFF_H */
