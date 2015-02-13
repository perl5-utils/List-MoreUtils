#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "multicall.h"
#include "ppport.h"

#ifndef aTHX
#  define aTHX
#  define pTHX
#endif

#ifdef SVf_IVisUV
#  define slu_sv_value(sv) (SvIOK(sv)) ? (SvIOK_UV(sv)) ? (NV)(SvUVX(sv)) : (NV)(SvIVX(sv)) : (SvNV(sv))
#else
#  define slu_sv_value(sv) (SvIOK(sv)) ? (NV)(SvIVX(sv)) : (SvNV(sv))
#endif

/*
 * Perl < 5.18 had some kind of different SvIV_please_nomg
 */
#if PERL_VERSION < 18
#undef SvIV_please_nomg
#  define SvIV_please_nomg(sv) \
	(!SvIOKp(sv) && (SvNOK(sv) || SvPOK(sv)) \
	    ? (SvIV_nomg(sv), SvIOK(sv))	  \
	    : SvIOK(sv))
#endif

/* compare left and right SVs. Returns:
 * -1: <
 *  0: ==
 *  1: >
 *  2: left or right was a NaN
 */
static I32
ncmp(SV* left, SV * right)
{
    /* Fortunately it seems NaN isn't IOK */
    if(SvAMAGIC(left) || SvAMAGIC(right))
	return SvIVX(amagic_call(left, right, ncmp_amg, 0));

    if (SvIV_please_nomg(right) && SvIV_please_nomg(left)) {
	if (!SvUOK(left)) {
	    const IV leftiv = SvIVX(left);
	    if (!SvUOK(right)) {
		/* ## IV <=> IV ## */
		const IV rightiv = SvIVX(right);
		return (leftiv > rightiv) - (leftiv < rightiv);
	    }
	    /* ## IV <=> UV ## */
	    if (leftiv < 0)
		/* As (b) is a UV, it's >=0, so it must be < */
		return -1;
	    {
		const UV rightuv = SvUVX(right);
		return ((UV)leftiv > rightuv) - ((UV)leftiv < rightuv);
	    }
	}

	if (SvUOK(right)) {
	    /* ## UV <=> UV ## */
	    const UV leftuv = SvUVX(left);
	    const UV rightuv = SvUVX(right);
	    return (leftuv > rightuv) - (leftuv < rightuv);
	}
	/* ## UV <=> IV ## */
	{
	    const IV rightiv = SvIVX(right);
	    if (rightiv < 0)
		/* As (a) is a UV, it's >=0, so it cannot be < */
		return 1;
	    {
		const UV leftuv = SvUVX(left);
		return (leftuv > (UV)rightiv) - (leftuv < (UV)rightiv);
	    }
	}
	assert(0); /* NOTREACHED */
    }
    else
    {
#ifdef SvNV_nomg
        NV const rnv = SvNV_nomg(right);
        NV const lnv = SvNV_nomg(left);
#else
        NV const rnv = slu_sv_value(right);
        NV const lnv = slu_sv_value(left);
#endif

#if defined(NAN_COMPARE_BROKEN) && defined(Perl_isnan)
        if (Perl_isnan(lnv) || Perl_isnan(rnv)) {
	    return 2;
        }
        return (lnv > rnv) - (lnv < rnv);
#else
        if (lnv < rnv)
	    return -1;
        if (lnv > rnv)
	    return 1;
        if (lnv == rnv)
            return 0;
        return 2;
#endif
    }
}


#ifndef Drand01
#    define Drand01()           ((rand() & 0x7FFF) / (double) ((unsigned long)1 << 15))
#endif

#if PERL_VERSION < 5
#  ifndef gv_stashpvn
#    define gv_stashpvn(n,l,c) gv_stashpv(n,c)
#  endif
#  ifndef SvTAINTED

static bool
sv_tainted(SV *sv)
{
    if (SvTYPE(sv) >= SVt_PVMG && SvMAGIC(sv)) {
	MAGIC *mg = mg_find(sv, 't');
	if (mg && ((mg->mg_len & 1) || (mg->mg_len & 2) && mg->mg_obj == sv))
	    return TRUE;
    }
    return FALSE;
}

#    define SvTAINTED_on(sv) sv_magic((sv), Nullsv, 't', Nullch, 0)
#    define SvTAINTED(sv) (SvMAGICAL(sv) && sv_tainted(sv))
#  endif
#  define PL_defgv defgv
#  define PL_op op
#  define PL_curpad curpad
#  define CALLRUNOPS runops
#  define PL_curpm curpm
#  define PL_sv_undef sv_undef
#  define PERL_CONTEXT struct context
#endif
#if (PERL_VERSION < 5) || (PERL_VERSION == 5 && PERL_SUBVERSION <50)
#  ifndef PL_tainting
#    define PL_tainting tainting
#  endif
#  ifndef PL_stack_base
#    define PL_stack_base stack_base
#  endif
#  ifndef PL_stack_sp
#    define PL_stack_sp stack_sp
#  endif
#  ifndef PL_ppaddr
#    define PL_ppaddr ppaddr
#  endif
#endif

#ifndef PTR2UV
#  define PTR2UV(ptr) (UV)(ptr)
#endif

#ifndef SvPV_nolen
    STRLEN N_A;
#   define SvPV_nolen(sv) SvPV(sv, N_A)
#endif

#ifndef call_sv
#  define call_sv perl_call_sv
#endif

#define WARN_OFF \
    SV *oldwarn = PL_curcop->cop_warnings; \
    PL_curcop->cop_warnings = pWARN_NONE;

#define WARN_ON \
    PL_curcop->cop_warnings = oldwarn;

#define EACH_ARRAY_BODY \
	int i;										\
	arrayeach_args * args;								\
	HV *stash = gv_stashpv("List::MoreUtils_ea", TRUE);				\
	CV *closure = newXS(NULL, XS_List__MoreUtils__array_iterator, __FILE__);	\
											\
	/* prototype */									\
	sv_setpv((SV*)closure, ";$");							\
											\
	New(0, args, 1, arrayeach_args);						\
	New(0, args->avs, items, AV*);							\
	args->navs = items;								\
	args->curidx = 0;								\
											\
	for (i = 0; i < items; i++) {							\
	    if(!arraylike(ST(i)))							\
	       croak_xs_usage(cv,  "\\@;\\@\\@...");					\
	    args->avs[i] = (AV*)SvRV(ST(i));						\
	    SvREFCNT_inc(args->avs[i]);							\
	}										\
											\
	CvXSUBANY(closure).any_ptr = args;						\
	RETVAL = newRV_noinc((SV*)closure);						\
											\
	/* in order to allow proper cleanup in DESTROY-handler */			\
	sv_bless(RETVAL, stash)


/* #include "dhash.h" */

/* need this one for array_each() */
typedef struct {
    AV **avs;	    /* arrays over which to iterate in parallel */
    int navs;	    /* number of arrays */
    int curidx;	    /* the current index of the iterator */
} arrayeach_args;

/* used for natatime */
typedef struct {
    SV **svs;
    int nsvs;
    int curidx;
    int natatime;
} natatime_args;

void
insert_after (int idx, SV *what, AV *av) {
    int i, len;
    av_extend(av, (len = av_len(av) + 1));

    for (i = len; i > idx+1; i--) {
	SV **sv = av_fetch(av, i-1, FALSE);
	SvREFCNT_inc(*sv);
	av_store(av, i, *sv);
    }
    if (!av_store(av, idx+1, what))
	SvREFCNT_dec(what);
}

static int
is_like(SV *sv, const char *like)
{
    int likely = 0;
    if( sv_isobject( sv ) )
    {
        dSP;
        int count;

        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        XPUSHs( sv_2mortal( newSVsv( sv ) ) );
        XPUSHs( sv_2mortal( newSVpv( like, strlen(like) ) ) );
        PUTBACK;

        if( ( count = call_pv("overload::Method", G_SCALAR) ) )
        {
            I32 ax;
            SPAGAIN;

            SP -= count;
            ax = (SP - PL_stack_base) + 1;
            if( SvTRUE(ST(0)) )
                ++likely;
        }

        PUTBACK;
        FREETMPS;
        LEAVE;
    }

    return likely;
}

static int
is_array( SV *sv )
{
    return SvROK(sv) && ( SVt_PVAV == SvTYPE(SvRV(sv) ) );
}

static int
codelike(SV *code)
{
    if( SvMAGICAL(code) )
        mg_get(code);
    return SvROK(code) && ( ( SVt_PVCV == SvTYPE(SvRV(code)) ) || ( is_like(code, "&{}" ) ) );
}

static int
arraylike(SV *array)
{
    if( SvMAGICAL(array) )
        mg_get(array);
    return is_array(array) || is_like( array, "@{}" );
}

MODULE = List::MoreUtils_ea             PACKAGE = List::MoreUtils_ea

void
DESTROY(sv)
    SV *sv;
    CODE:
    {
	int i;
	CV *code = (CV*)SvRV(sv);
	arrayeach_args *args = CvXSUBANY(code).any_ptr;
	if (args) {
	    for (i = 0; i < args->navs; ++i)
		SvREFCNT_dec(args->avs[i]);
	    Safefree(args->avs);
	    Safefree(args);
	    CvXSUBANY(code).any_ptr = NULL;
	}
    }


MODULE = List::MoreUtils_na             PACKAGE = List::MoreUtils_na

void
DESTROY(sv)
    SV *sv;
    CODE:
    {
	int i;
	CV *code = (CV*)SvRV(sv);
	natatime_args *args = CvXSUBANY(code).any_ptr;
	if (args) {
	    for (i = 0; i < args->nsvs; ++i)
		SvREFCNT_dec(args->svs[i]);
	    Safefree(args->svs);
	    Safefree(args);
	    CvXSUBANY(code).any_ptr = NULL;
	}
    }

MODULE = List::MoreUtils		PACKAGE = List::MoreUtils

void
any (code,...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    GV *gv;
    HV *stash;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_NO;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (SvTRUE(*PL_stack_sp)) {
	    POP_MULTICALL;
	    XSRETURN_YES;
	}
    }
    POP_MULTICALL;
    XSRETURN_NO;
}

void
all (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_YES;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; i++) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (!SvTRUE(*PL_stack_sp)) {
	    POP_MULTICALL;
	    XSRETURN_NO;
	}
    }
    POP_MULTICALL;
    XSRETURN_YES;
}


void
none (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_YES;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (SvTRUE(*PL_stack_sp)) {
	    POP_MULTICALL;
	    XSRETURN_NO;
	}
    }
    POP_MULTICALL;
    XSRETURN_YES;
}

void
notall (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_NO;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (!SvTRUE(*PL_stack_sp)) {
	    POP_MULTICALL;
	    XSRETURN_YES;
	}
    }
    POP_MULTICALL;
    XSRETURN_NO;
}

void
any_u (code,...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    GV *gv;
    HV *stash;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_UNDEF;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (SvTRUE(*PL_stack_sp)) {
	    POP_MULTICALL;
	    XSRETURN_YES;
	}
    }
    POP_MULTICALL;
    XSRETURN_NO;
}

void
all_u (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_UNDEF;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; i++) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (!SvTRUE(*PL_stack_sp)) {
	    POP_MULTICALL;
	    XSRETURN_NO;
	}
    }
    POP_MULTICALL;
    XSRETURN_YES;
}


void
none_u (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_UNDEF;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (SvTRUE(*PL_stack_sp)) {
	    POP_MULTICALL;
	    XSRETURN_NO;
	}
    }
    POP_MULTICALL;
    XSRETURN_YES;
}

void
notall_u (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_UNDEF;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (!SvTRUE(*PL_stack_sp)) {
	    POP_MULTICALL;
	    XSRETURN_YES;
	}
    }
    POP_MULTICALL;
    XSRETURN_NO;
}

int
true (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    I32 count = 0;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	goto done;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (SvTRUE(*PL_stack_sp))
	    count++;
    }
    POP_MULTICALL;

    done:
    RETVAL = count;
}
OUTPUT:
    RETVAL

int
false (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    I32 count = 0;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	goto done;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (!SvTRUE(*PL_stack_sp))
	    count++;
    }
    POP_MULTICALL;

    done:
    RETVAL = count;
}
OUTPUT:
    RETVAL

int
firstidx (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    RETVAL = -1;

    if (items > 1) {
	_cv = sv_2cv(code, &stash, &gv, 0);
	PUSH_MULTICALL(_cv);
	SAVESPTR(GvSV(PL_defgv));

	for (i = 1 ; i < items ; ++i) {
	    GvSV(PL_defgv) = args[i];
	    MULTICALL;
	    if (SvTRUE(*PL_stack_sp)) {
		RETVAL = i-1;
		break;
	    }
	}
	POP_MULTICALL;
    }
}
OUTPUT:
    RETVAL

int
lastidx (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    RETVAL = -1;

    if (items > 1) {
	_cv = sv_2cv(code, &stash, &gv, 0);
	PUSH_MULTICALL(_cv);
	SAVESPTR(GvSV(PL_defgv));

	for (i = items-1 ; i > 0 ; --i) {
	    GvSV(PL_defgv) = args[i];
	    MULTICALL;
	    if (SvTRUE(*PL_stack_sp)) {
		RETVAL = i-1;
		break;
	    }
	}
	POP_MULTICALL;
    }
}
OUTPUT:
    RETVAL

int
insert_after (code, val, avref)
    SV *code;
    SV *val;
    SV *avref;
PROTOTYPE: &$\@
CODE:
{
    dMULTICALL;
    int i;
    int len;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    CV *_cv;
    AV *av;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, val, \\@area_of_operation");
    if(!arraylike(avref))
       croak_xs_usage(cv,  "code, val, \\@area_of_operation");

    av = (AV*)SvRV(avref);
    len = av_len(av);
    RETVAL = 0;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for (i = 0; i <= len ; ++i) {
	GvSV(PL_defgv) = *av_fetch(av, i, FALSE);
	MULTICALL;
	if (SvTRUE(*PL_stack_sp)) {
	    RETVAL = 1;
	    break;
	}
    }

    POP_MULTICALL;

    if (RETVAL) {
	SvREFCNT_inc(val);
	insert_after(i, val, av);
    }
}
OUTPUT:
    RETVAL

int
insert_after_string (string, val, avref)
	SV *string;
	SV *val;
	SV *avref;
    PROTOTYPE: $$\@
    CODE:
    {
	int i;
	AV *av;
	int len;
	SV **sv;
	STRLEN slen = 0, alen;
	char *str;
	char *astr;
	RETVAL = 0;

	if(!arraylike(avref))
	   croak_xs_usage(cv,  "string, val, \\@area_of_operation");

	av = (AV*)SvRV(avref);
	len = av_len(av);

	if (SvTRUE(string))
	    str = SvPV(string, slen);
	else
	    str = NULL;

	for (i = 0; i <= len ; i++) {
	    sv = av_fetch(av, i, FALSE);
	    if (SvTRUE(*sv))
		astr = SvPV(*sv, alen);
	    else {
		astr = NULL;
		alen = 0;
	    }
	    if (slen == alen && memcmp(astr, str, slen) == 0) {
		RETVAL = 1;
		break;
	    }
	}
	if (RETVAL) {
	    SvREFCNT_inc(val);
	    insert_after(i, val, av);
	}

    }
    OUTPUT:
	RETVAL

void
apply (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    CV *_cv;
    SV **args = &PL_stack_base[ax];

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_EMPTY;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	GvSV(PL_defgv) = newSVsv(args[i]);
	MULTICALL;
	args[i-1] = GvSV(PL_defgv);
    }
    POP_MULTICALL;

    for(i = 1 ; i < items ; ++i)
        sv_2mortal(args[i-1]);

    XSRETURN(items-1);
}

void
after (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i, j;
    HV *stash;
    CV *_cv;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_EMPTY;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for (i = 1; i < items; i++) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (SvTRUE(*PL_stack_sp)) {
	    break;
	}
    }

    POP_MULTICALL;

    for (j = i + 1; j < items; ++j)
	args[j-i-1] = args[j];

    XSRETURN(items-i-1);
}

void
after_incl (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i, j;
    HV *stash;
    CV *_cv;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_EMPTY;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for (i = 1; i < items; i++) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (SvTRUE(*PL_stack_sp)) {
	    break;
	}
    }

    POP_MULTICALL;

    for (j = i; j < items; j++)
	args[j-i] = args[j];

    XSRETURN(items-i);
}

void
before (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_EMPTY;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for (i = 1; i < items; i++) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (SvTRUE(*PL_stack_sp)) {
	    break;
	}
	args[i-1] = args[i];
    }

    POP_MULTICALL;

    XSRETURN(i-1);
}

void
before_incl (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_EMPTY;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for (i = 1; i < items; ++i) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	args[i-1] = args[i];
	if (SvTRUE(*PL_stack_sp)) {
	    ++i;
	    break;
	}
    }

    POP_MULTICALL;

    XSRETURN(i-1);
}

void
indexes (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i, j;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items <= 1)
	XSRETURN_EMPTY;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for (i = 1, j = 0; i < items; i++) {
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	if (SvTRUE(*PL_stack_sp))
            /* POP_MULTICALL can free mortal temporaries, so we defer
             * mortalising the returned values till after that's been
             * done */
	    args[j++] = newSViv(i-1);
    }

    POP_MULTICALL;

    for (i = 0; i < j; i++)
        sv_2mortal(args[i]);

    XSRETURN(j);
}

SV *
lastval (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    RETVAL = &PL_sv_undef;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items > 1) {
	_cv = sv_2cv(code, &stash, &gv, 0);
	PUSH_MULTICALL(_cv);
	SAVESPTR(GvSV(PL_defgv));

	for (i = items-1 ; i > 0 ; --i) {
	    GvSV(PL_defgv) = args[i];
	    MULTICALL;
	    if (SvTRUE(*PL_stack_sp)) {
		/* see comment in indexes() */
		SvREFCNT_inc(RETVAL = args[i]);
		break;
	    }
	}
	POP_MULTICALL;
    }
}
OUTPUT:
    RETVAL

SV *
firstval (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    RETVAL = &PL_sv_undef;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items > 1) {
	_cv = sv_2cv(code, &stash, &gv, 0);
	PUSH_MULTICALL(_cv);
	SAVESPTR(GvSV(PL_defgv));

	for (i = 1; i < items; ++i) {
	    GvSV(PL_defgv) = args[i];
	    MULTICALL;
	    if (SvTRUE(*PL_stack_sp)) {
		/* see comment in indexes() */
		SvREFCNT_inc(RETVAL = args[i]);
		break;
	    }
	}
	POP_MULTICALL;
    }
}
OUTPUT:
    RETVAL

void
_array_iterator (method = "")
    char *method;
    PROTOTYPE: ;$
    CODE:
    {
	int i;
	int exhausted = 1;

	/* 'cv' is the hidden argument with which XS_List__MoreUtils__array_iterator (this XSUB)
	 * is called. The closure_arg struct is stored in this CV. */

	arrayeach_args *args = (arrayeach_args*)CvXSUBANY(cv).any_ptr;

	if (strEQ(method, "index")) {
	    EXTEND(SP, 1);
	    ST(0) = args->curidx > 0 ? sv_2mortal(newSViv(args->curidx-1)) : &PL_sv_undef;
	    XSRETURN(1);
	}

	EXTEND(SP, args->navs);

	for (i = 0; i < args->navs; i++) {
	    AV *av = args->avs[i];
	    if (args->curidx <= av_len(av)) {
		ST(i) = sv_2mortal(newSVsv(*av_fetch(av, args->curidx, FALSE)));
		exhausted = 0;
		continue;
	    }
	    ST(i) = &PL_sv_undef;
	}

	if (exhausted)
	    XSRETURN_EMPTY;

	args->curidx++;
	XSRETURN(args->navs);
    }

SV *
each_array (...)
    PROTOTYPE: \@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@
    CODE:
    {
	EACH_ARRAY_BODY;
    }
    OUTPUT:
	RETVAL

SV *
each_arrayref (...)
    CODE:
    {
	EACH_ARRAY_BODY;
    }
    OUTPUT:
	RETVAL

#if 0
void
_pairwise (code, ...)
	SV *code;
    PROTOTYPE: &\@\@
    PPCODE:
    {
#define av_items(a) (av_len(a)+1)

	int i;
	AV *avs[2];
	SV **oldsp;

	int nitems = 0, maxitems = 0;

	if(!codelike(code))
	   croak_xs_usage(cv,  "code, ...");

	/* deref AV's for convenience and
	 * get maximum items */
	avs[0] = (AV*)SvRV(ST(1));
	avs[1] = (AV*)SvRV(ST(2));
	maxitems = av_items(avs[0]);
	if (av_items(avs[1]) > maxitems)
	    maxitems = av_items(avs[1]);

	if (!PL_firstgv || !PL_secondgv) {
	    SAVESPTR(PL_firstgv);
	    SAVESPTR(PL_secondgv);
	    PL_firstgv = gv_fetchpv("a", TRUE, SVt_PV);
	    PL_secondgv = gv_fetchpv("b", TRUE, SVt_PV);
	}

	oldsp = PL_stack_base;
	EXTEND(SP, maxitems);
	ENTER;
	for (i = 0; i < maxitems; i++) {
	    int nret;
	    SV **svp = av_fetch(avs[0], i, FALSE);
	    GvSV(PL_firstgv) = svp ? *svp : &PL_sv_undef;
	    svp = av_fetch(avs[1], i, FALSE);
	    GvSV(PL_secondgv) = svp ? *svp : &PL_sv_undef;
	    PUSHMARK(SP);
	    PUTBACK;
	    nret = call_sv(code, G_EVAL|G_ARRAY);
            if (SvTRUE(ERRSV))
                croak("%s", SvPV_nolen(ERRSV));
	    SPAGAIN;
	    nitems += nret;
	    while (nret--) {
		SvREFCNT_inc(*PL_stack_sp++);
	    }
	}
	PL_stack_base = oldsp;
	LEAVE;
	XSRETURN(nitems);
    }

#endif

void
pairwise (code, ...)
	SV *code;
    PROTOTYPE: &\@\@
    PPCODE:
    {
#define av_items(a) (av_len(a)+1)

	/* This function is not quite as efficient as it ought to be: We call
	 * 'code' multiple times and want to gather its return values all in
	 * one list. However, each call resets the stack pointer so there is no
	 * obvious way to get the return values onto the stack without making
	 * intermediate copies of the pointers.  The above disabled solution
	 * would be more efficient. Unfortunately it doesn't work (and, as of
	 * now, wouldn't deal with 'code' returning more than one value).
	 *
	 * The current solution is a fair trade-off. It only allocates memory
	 * for a list of SV-pointers, as many as there are return values. It
	 * temporarily stores 'code's return values in this list and, when
	 * done, copies them down to SP. */

	int i, j;
	AV *avs[2];
	SV **buf, **p;	/* gather return values here and later copy down to SP */
	int alloc;

	int nitems = 0, maxitems = 0;
	int d;

	if(!codelike(code))
	   croak_xs_usage(cv,  "code, list, list");
	if(!arraylike(ST(1)))
	   croak_xs_usage(cv,  "code, list, list");
	if(!arraylike(ST(2)))
	   croak_xs_usage(cv,  "code, list, list");

	/* deref AV's for convenience and
	 * get maximum items */
	avs[0] = (AV*)SvRV(ST(1));
	avs[1] = (AV*)SvRV(ST(2));
	maxitems = av_items(avs[0]);
	if (av_items(avs[1]) > maxitems)
	    maxitems = av_items(avs[1]);

	if (!PL_firstgv || !PL_secondgv) {
	    SAVESPTR(PL_firstgv);
	    SAVESPTR(PL_secondgv);
	    PL_firstgv = gv_fetchpv("a", TRUE, SVt_PV);
	    PL_secondgv = gv_fetchpv("b", TRUE, SVt_PV);
	}

	New(0, buf, alloc = maxitems, SV*);

	ENTER;
	for (d = 0, i = 0; i < maxitems; i++) {
	    int nret;
	    SV **svp = av_fetch(avs[0], i, FALSE);
	    GvSV(PL_firstgv) = svp ? *svp : &PL_sv_undef;
	    svp = av_fetch(avs[1], i, FALSE);
	    GvSV(PL_secondgv) = svp ? *svp : &PL_sv_undef;
	    PUSHMARK(SP);
	    PUTBACK;
	    nret = call_sv(code, G_EVAL|G_ARRAY);
            if (SvTRUE(ERRSV)) {
                Safefree(buf);
                croak("%s", SvPV_nolen(ERRSV));
            }
	    SPAGAIN;
	    nitems += nret;
	    if (nitems > alloc) {
		alloc <<= 2;
		Renew(buf, alloc, SV*);
	    }
	    for (j = nret-1; j >= 0; j--) {
		/* POPs would return elements in reverse order */
		buf[d] = sp[-j];
		d++;
	    }
	    sp -= nret;
	}
	LEAVE;
	EXTEND(SP, nitems);
	p = buf;
	for (i = 0; i < nitems; i++)
	    ST(i) = *p++;

	Safefree(buf);
	XSRETURN(nitems);
    }

void
_natatime_iterator ()
    PROTOTYPE:
    CODE:
    {
	int i;
	int nret;

	/* 'cv' is the hidden argument with which XS_List__MoreUtils__array_iterator (this XSUB)
	 * is called. The closure_arg struct is stored in this CV. */

	natatime_args *args = (natatime_args*)CvXSUBANY(cv).any_ptr;

	nret = args->natatime;

	EXTEND(SP, nret);

	for (i = 0; i < args->natatime; i++) {
	    if (args->curidx < args->nsvs) {
		ST(i) = sv_2mortal(newSVsv(args->svs[args->curidx++]));
	    }
	    else {
		XSRETURN(i);
	    }
	}

	XSRETURN(nret);
    }

SV *
natatime (n, ...)
    int n;
    PROTOTYPE: $@
    CODE:
    {
	int i;
	natatime_args * args;
	HV *stash = gv_stashpv("List::MoreUtils_na", TRUE);

	CV *closure = newXS(NULL, XS_List__MoreUtils__natatime_iterator, __FILE__);

	/* must NOT set prototype on iterator:
	 * otherwise one cannot write: &$it */
	/* !! sv_setpv((SV*)closure, ""); !! */

	New(0, args, 1, natatime_args);
	New(0, args->svs, items-1, SV*);
	args->nsvs = items-1;
	args->curidx = 0;
	args->natatime = n;

	for (i = 1; i < items; i++)
	    SvREFCNT_inc(args->svs[i-1] = ST(i));

	CvXSUBANY(closure).any_ptr = args;
	RETVAL = newRV_noinc((SV*)closure);

	/* in order to allow proper cleanup in DESTROY-handler */
	sv_bless(RETVAL, stash);
    }
    OUTPUT:
	RETVAL

void
mesh (...)
    PROTOTYPE: \@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@
    CODE:
    {
	int i, j, maxidx = -1;
	AV **avs;
	New(0, avs, items, AV*);

	for (i = 0; i < items; i++) {
	    if(!arraylike(ST(i)))
	       croak_xs_usage(cv,  "\\@;\\@\\@...");
	    avs[i] = (AV*)SvRV(ST(i));
	    if (av_len(avs[i]) > maxidx)
		maxidx = av_len(avs[i]);
	}

	EXTEND(SP, items * (maxidx + 1));
	for (i = 0; i <= maxidx; i++)
	    for (j = 0; j < items; j++) {
		SV **svp = av_fetch(avs[j], i, FALSE);
		ST(i*items + j) = svp ? sv_2mortal(newSVsv(*svp)) : &PL_sv_undef;
	    }

	Safefree(avs);
	XSRETURN(items * (maxidx + 1));
    }

void
uniq (...)
    PROTOTYPE: @
    CODE:
    {
	int i, count = 0;
	HV *hv = newHV();
	sv_2mortal(newRV_noinc((SV*)hv));

	/* don't build return list in scalar context */
	if (GIMME_V == G_SCALAR) {
	    for (i = 0; i < items; i++) {
		if (!hv_exists_ent(hv, ST(i), 0)) {
		    count++;
		    hv_store_ent(hv, ST(i), &PL_sv_yes, 0);
		}
	    }
	    ST(0) = sv_2mortal(newSViv(count));
	    XSRETURN(1);
	}

	/* list context: populate SP with mortal copies */
	for (i = 0; i < items; i++) {
	    if (!hv_exists_ent(hv, ST(i), 0)) {
		ST(count) = sv_2mortal(newSVsv(ST(i)));
		count++;
		hv_store_ent(hv, ST(i), &PL_sv_yes, 0);
	    }
	}
	XSRETURN(count);
    }

void
minmax (...)
    PROTOTYPE: @
    CODE:
    {
	I32 i;
	SV *minsv, *maxsv;

	if (!items)
	    XSRETURN_EMPTY;

	minsv = maxsv = ST(0);

        if (items == 1) {
            EXTEND(SP, 1);
            ST(0) = ST(1) = minsv;
            XSRETURN(2);
        }

	for (i = 1; i < items; i += 2) {
	    SV *asv = ST(i-1);
	    SV *bsv = ST(i);
	    int cmp = ncmp(asv, bsv);
	    if (cmp < 0) {
		int min_cmp = ncmp(minsv, asv);
		int max_cmp = ncmp(maxsv, bsv);
		if (min_cmp > 0) {
		    minsv = asv;
		}
		if (max_cmp < 0) {
		    maxsv = bsv;
		}
	    } else {
		int min_cmp = ncmp(minsv, bsv);
		int max_cmp = ncmp(maxsv, asv);
		if (min_cmp > 0) {
		    minsv = bsv;
		}
		if (max_cmp < 0) {
		    maxsv = asv;
		}
	    }
	}

	if (items & 1) {
	    SV *rsv = ST(items-1);
	    if (ncmp(minsv, rsv) > 0) {
		minsv = rsv;
	    }
	    else if (ncmp(maxsv, rsv) < 0) {
		maxsv = rsv;
	    }
	}
	ST(0) = minsv;
	ST(1) = maxsv;

	XSRETURN(2);
    }

void
part (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *_cv;

    AV **tmp = NULL;
    int last = 0;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items == 1)
	XSRETURN_EMPTY;

    _cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(_cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	int idx;
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	idx = SvIV(*PL_stack_sp);

	if (idx < 0 && (idx += last) < 0)
	    croak("Modification of non-creatable array value attempted, subscript %i", idx);

	if (idx >= last) {
	    int oldlast = last;
	    last = idx + 1;
	    Renew(tmp, last, AV*);
	    Zero(tmp + oldlast, last - oldlast, AV*);
	}
	if (!tmp[idx])
	    tmp[idx] = newAV();
	av_push(tmp[idx], args[i]);
	SvREFCNT_inc(args[i]);
    }
    POP_MULTICALL;

    EXTEND(SP, last);
    for (i = 0; i < last; ++i) {
        if (tmp[i])
            ST(i) = sv_2mortal(newRV_noinc((SV*)tmp[i]));
        else
            ST(i) = &PL_sv_undef;
    }

    Safefree(tmp);
    XSRETURN(last);
}

#if 0
void
part_dhash (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    /* We might want to keep this dhash-implementation.
     * It is currently slower than the above but it uses less
     * memory for sparse parts such as
     *   @part = part { 10_000_000 } 1 .. 100_000;
     * Maybe there's a way to optimize dhash.h to get more speed
     * from it.
     */
    dMULTICALL;
    int i, j, lastidx = -1;
    int max;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    I32 count = 0;
    SV **args = &PL_stack_base[ax];
    CV *cv;

    dhash_t *h = dhash_init();

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items == 1)
	XSRETURN_EMPTY;

    cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(cv);
    SAVESPTR(GvSV(PL_defgv));

    for(i = 1 ; i < items ; ++i) {
	int idx;
	GvSV(PL_defgv) = args[i];
	MULTICALL;
	idx = SvIV(*PL_stack_sp);

	if (idx < 0 && (idx += h->max) < 0)
	    croak("Modification of non-creatable array value attempted, subscript %i", idx);

	dhash_store(h, idx, args[i]);
    }
    POP_MULTICALL;

    dhash_sort_final(h);

    EXTEND(SP, max = h->max+1);
    i = 0;
    lastidx = -1;
    while (i < h->count) {
	int retidx = h->ary[i].key;
	int fill = retidx - lastidx - 1;
	for (j = 0; j < fill; j++) {
	    ST(retidx - j - 1) = &PL_sv_undef;
	}
	ST(retidx) = newRV_noinc((SV*)h->ary[i].val);
	i++;
	lastidx = retidx;
    }

    dhash_destroy(h);
    XSRETURN(max);
}

#endif

SV *
bsearch (code, ...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    HV *stash;
    GV *gv;
    I32 gimme = GIMME_V; /* perl-5.5.4 bus-errors out later when using GIMME
                            therefore we save its value in a fresh variable */
    SV **args = &PL_stack_base[ax];

    long i, j;
    int val = -1;

    if(!codelike(code))
       croak_xs_usage(cv,  "code, ...");

    if (items > 1) {
	CV *_cv = sv_2cv(code, &stash, &gv, 0);
	PUSH_MULTICALL(_cv);
	SAVESPTR(GvSV(PL_defgv));

        i = 0;
        j = items - 1;
        do {
            long k = (i + j) / 2;

            if (k >= items-1)
                break;

            GvSV(PL_defgv) = args[1+k];
            MULTICALL;
            val = SvIV(*PL_stack_sp);

            if (val == 0) {
                POP_MULTICALL;
                if (gimme != G_ARRAY) {
                    XSRETURN_YES;
		}
                SvREFCNT_inc(RETVAL = args[1+k]);
                goto yes;
            }
            if (val < 0) {
                i = k+1;
            } else {
                j = k-1;
            }
        } while (i <= j);
        POP_MULTICALL;
    }

    if (gimme == G_ARRAY)
        XSRETURN_EMPTY;
    else
        XSRETURN_UNDEF;
yes:
    ;
}
OUTPUT:
    RETVAL

void
_XScompiled ()
    CODE:
       XSRETURN_YES;
