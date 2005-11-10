#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef PERL_VERSION
#    include <patchlevel.h>
#    if !(defined(PERL_VERSION) || (SUBVERSION > 0 && defined(PATCHLEVEL)))
#        include <could_not_find_Perl_patchlevel.h>
#    endif
#    define PERL_REVISION	5
#    define PERL_VERSION	PATCHLEVEL
#    define PERL_SUBVERSION	SUBVERSION
#endif

#ifndef aTHX
#  define aTHX
#  define pTHX
#endif

/* Some platforms have strict exports. And before 5.7.3 cxinc (or Perl_cxinc)
   was not exported. Therefore platforms like win32, VMS etc have problems
   so we redefine it here -- GMB
*/
#if PERL_VERSION < 7
/* Not in 5.6.1. */
#  define SvUOK(sv)           SvIOK_UV(sv)
#  ifdef cxinc
#    undef cxinc
#  endif
#  define cxinc() my_cxinc(aTHX)
static I32
my_cxinc(pTHX)
{
    cxstack_max = cxstack_max * 3 / 2;
    Renew(cxstack, cxstack_max + 1, struct context);      /* XXX should fix CXINC macro */
    return cxstack_ix + 1;
}
#endif

#if PERL_VERSION < 6
#    define NV double
#    define LEAVESUB(cv)	    \
	{			    \
	    if (cv)		{   \
		SvREFCNT_dec(cv);   \
	    }			    \
	}
#endif

#ifdef SVf_IVisUV
#  define slu_sv_value(sv) (SvIOK(sv)) ? (SvIOK_UV(sv)) ? (NV)(SvUVX(sv)) : (NV)(SvIVX(sv)) : (SvNV(sv))
#else
#  define slu_sv_value(sv) (SvIOK(sv)) ? (NV)(SvIVX(sv)) : (SvNV(sv))
#endif

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

#ifndef call_sv
#  define call_sv perl_call_sv
#endif

#define WARN_OFF \
    SV *oldwarn = PL_curcop->cop_warnings; \
    PL_curcop->cop_warnings = pWARN_NONE;

#define WARN_ON \
    PL_curcop->cop_warnings = oldwarn;

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
    register int i, len;
    av_extend(av, (len = av_len(av) + 1));
    
    for (i = len; i > idx+1; i--) {
	SV **sv = av_fetch(av, i-1, FALSE);
	SvREFCNT_inc(*sv);
	av_store(av, i, *sv);
    }
    if (!av_store(av, idx+1, what))
	SvREFCNT_dec(what);

}
    
MODULE = List::MoreUtils		PACKAGE = List::MoreUtils		

void
any (code,...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i;
	HV *stash;
	CV *cv;
	OP *anyop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	if (items <= 1)
	    XSRETURN_UNDEF;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	anyop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = anyop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) {
	      POPBLOCK(cx,PL_curpm);
	      CATCH_SET(oldcatch);
	      LEAVESUB(cv);
	      XSRETURN_YES;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);
	XSRETURN_NO;
    }

void
all (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i;
	HV *stash;
	CV *cv;
	OP *allop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	if (items <= 1)
	    XSRETURN_UNDEF;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	allop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = allop;
	    CALLRUNOPS(aTHX);
	    if (!SvTRUE(*PL_stack_sp)) {
	      POPBLOCK(cx,PL_curpm);
	      CATCH_SET(oldcatch);
	      LEAVESUB(cv);
	      XSRETURN_NO;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);
	XSRETURN_YES;
    }


void
none (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i;
	HV *stash;
	CV *cv;
	OP *noneop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	if (items <= 1)
	    XSRETURN_UNDEF;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	noneop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = noneop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) {
	      POPBLOCK(cx,PL_curpm);
	      CATCH_SET(oldcatch);
	      LEAVESUB(cv);
	      XSRETURN_NO;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);
	XSRETURN_YES;
    }


void
notall (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i;
	HV *stash;
	CV *cv;
	OP *notallop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	if (items <= 1)
	    XSRETURN_UNDEF;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	notallop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = notallop;
	    CALLRUNOPS(aTHX);
	    if (!SvTRUE(*PL_stack_sp)) {
	      POPBLOCK(cx,PL_curpm);
	      CATCH_SET(oldcatch);
	      LEAVESUB(cv);
	      XSRETURN_YES;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);
	XSRETURN_NO;
    }


int
true (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i;
	HV *stash;
	CV *cv;
	OP *trueop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;
	I32 count = 0;
	
	if (items <= 1)
	    goto done;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	trueop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = trueop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) 
		count++;
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);

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
	register int i;
	HV *stash;
	CV *cv;
	OP *falseop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	RETVAL = 0;
	
	if (items <= 1)
	    goto done;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	falseop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = falseop;
	    CALLRUNOPS(aTHX);
	    if (!SvTRUE(*PL_stack_sp)) 
		RETVAL++;
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);
	
	done:
	;
    }
    OUTPUT:
	RETVAL

int
firstidx (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i;
	HV *stash;
	CV *cv;
	OP *firstidxop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	RETVAL = -1;
	
	if (items > 1) {
	    SAVESPTR(GvSV(PL_defgv));
	    cv = sv_2cv(code, &stash, &gv, 0);
	    firstidxop = CvSTART(cv);
	    SAVESPTR(CvROOT(cv)->op_ppaddr);
	    CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	    PAD_SET_CUR(CvPADLIST(cv),1);
#else
	    SAVESPTR(PL_curpad);
	    PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	    SAVETMPS;
	    SAVESPTR(PL_op);
	    CATCH_SET(TRUE);
	    PUSHBLOCK(cx, CXt_SUB, SP);
	    PUSHSUB(cx);
		
	    for (i = 1 ; i < items ; i++) {
		GvSV(PL_defgv) = ST(i);
		PL_op = firstidxop;
		CALLRUNOPS(aTHX);
		if (SvTRUE(*PL_stack_sp)) {
		    RETVAL = i-1;
		    break;
		}
	    }
	    POPBLOCK(cx,PL_curpm);
	    CATCH_SET(oldcatch);
	    LEAVESUB(cv);
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
	register int i;
	HV *stash;
	CV *cv;
	OP *lastidxop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	RETVAL = -1;
	
	if (items > 1) {
	    SAVESPTR(GvSV(PL_defgv));
	    cv = sv_2cv(code, &stash, &gv, 0);
	    lastidxop = CvSTART(cv);
	    SAVESPTR(CvROOT(cv)->op_ppaddr);
	    CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	    PAD_SET_CUR(CvPADLIST(cv),1);
#else
	    SAVESPTR(PL_curpad);
	    PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	    SAVETMPS;
	    SAVESPTR(PL_op);
	    CATCH_SET(TRUE);
	    PUSHBLOCK(cx, CXt_SUB, SP);
	    PUSHSUB(cx);
		
	    for (i = items-1 ; i > 0 ; i--) {
		GvSV(PL_defgv) = ST(i);
		PL_op = lastidxop;
		CALLRUNOPS(aTHX);
		if (SvTRUE(*PL_stack_sp)) {
		    RETVAL = i-1;
		    break;
		}
	    }
	    POPBLOCK(cx,PL_curpm);
	    CATCH_SET(oldcatch);
	    LEAVESUB(cv);
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
	register int i;
	HV *stash;
	CV *cv;
	OP *insertafterop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	AV *av = (AV*)SvRV(avref);
	int len = av_len(av);
	RETVAL = 0;
	
	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	insertafterop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
	    
	for (i = 0; i <= len ; i++) {
	    GvSV(PL_defgv) = *av_fetch(av, i, FALSE);
	    PL_op = insertafterop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) {
		RETVAL = 1;
		break;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);
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
	register int i;
	AV *av = (AV*)SvRV(avref);
	int len = av_len(av);
	register SV **sv;
	STRLEN slen = 0, alen;
	register char *str;
	register char *astr;
	RETVAL = 0;
	
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
	register int i;
	HV *stash;
	CV *cv;
	OP *applyop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;
	I32 count = 0;
	
	if (items <= 1)
	    XSRETURN_EMPTY;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	applyop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = newSVsv(ST(i));
	    PL_op = applyop;
	    CALLRUNOPS(aTHX);
	    ST(i-1) =  GvSV(PL_defgv);
	}
	POPBLOCK(cx,PL_curpm)
	CATCH_SET(oldcatch);
	LEAVESUB(cv);

	done:
	XSRETURN(items-1);
    }

void
after (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i, j;
	HV *stash;
	CV *cv;
	OP *afterop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	if (items <= 1)
	    XSRETURN_EMPTY;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	afterop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
	    
	for (i = 1; i < items; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = afterop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) {
		break;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);

	for (j = i + 1; j < items; j++)
	    ST(j-i-1) = ST(j);
	XSRETURN(items-i-1);
    }

void
after_incl (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i, j;
	HV *stash;
	CV *cv;
	OP *afterop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	if (items <= 1)
	    XSRETURN_EMPTY;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	afterop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
	    
	for (i = 1; i < items; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = afterop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) {
		break;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);

	for (j = i; j < items; j++)
	    ST(j-i) = ST(j);
	
	XSRETURN(items-i);
    }

void
before (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i;
	HV *stash;
	CV *cv;
	OP *beforeop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	if (items <= 1)
	    XSRETURN_EMPTY;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	beforeop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
	    
	for (i = 1; i < items; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = beforeop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) {
		break;
	    }
	    ST(i-1) = ST(i);
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv); 

	XSRETURN(i-1);
    }

void
before_incl (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i;
	HV *stash;
	CV *cv;
	OP *beforeop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	if (items <= 1)
	    XSRETURN_EMPTY;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	beforeop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
	    
	for (i = 1; i < items; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = beforeop;
	    CALLRUNOPS(aTHX);
	    ST(i-1) = ST(i);
	    if (SvTRUE(*PL_stack_sp)) {
		i++;
		break;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);

	XSRETURN(i-1);
    }

void
indexes (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i, j;
	HV *stash;
	CV *cv;
	OP *indexop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	if (items <= 1)
	    XSRETURN_EMPTY;

	SAVESPTR(GvSV(PL_defgv));
	cv = sv_2cv(code, &stash, &gv, 0);
	indexop = CvSTART(cv);
	SAVESPTR(CvROOT(cv)->op_ppaddr);
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	PAD_SET_CUR(CvPADLIST(cv),1);
#else
	SAVESPTR(PL_curpad);
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	SAVETMPS;
	SAVESPTR(PL_op);
	CATCH_SET(TRUE);
	PUSHBLOCK(cx, CXt_SUB, SP);
	PUSHSUB(cx);
	    
	
	for (i = 1, j = 0; i < items; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = indexop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) {
		ST(j) = sv_2mortal(newSViv(i-1));
		/* need to artificially increase ref-count here
		 * because POPBLOCK further below would otherwise
		 * free the items in SP */
		SvREFCNT_inc(ST(j));
		j++;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	LEAVESUB(cv);
	
	XSRETURN(j);
    }

SV *
lastval (code, ...)
	SV *code;
    PROTOTYPE: &@
    CODE:
    {
	register int i;
	HV *stash;
	CV *cv;
	OP *lastvalop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	RETVAL = &PL_sv_undef;
	
	if (items > 1) {
	    SAVESPTR(GvSV(PL_defgv));
	    cv = sv_2cv(code, &stash, &gv, 0);
	    lastvalop = CvSTART(cv);
	    SAVESPTR(CvROOT(cv)->op_ppaddr);
	    CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	    PAD_SET_CUR(CvPADLIST(cv),1);
#else
	    SAVESPTR(PL_curpad);
	    PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	    SAVETMPS;
	    SAVESPTR(PL_op);
	    CATCH_SET(TRUE);
	    PUSHBLOCK(cx, CXt_SUB, SP);
	    PUSHSUB(cx);
		
	    for (i = items-1 ; i > 0 ; i--) {
		GvSV(PL_defgv) = ST(i);
		PL_op = lastvalop;
		CALLRUNOPS(aTHX);
		if (SvTRUE(*PL_stack_sp)) {
		    /* see comment in indexes() */
		    SvREFCNT_inc(RETVAL = ST(i));
		    break;
		}
	    }
	    POPBLOCK(cx,PL_curpm);
	    CATCH_SET(oldcatch);
	    LEAVESUB(cv);
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
	register int i;
	HV *stash;
	CV *cv;
	OP *firstvalop;
	PERL_CONTEXT *cx;
	GV *gv;
	SV **newsp;
	I32 gimme = G_SCALAR;
	U8 hasargs = 0;
	bool oldcatch = CATCH_GET;

	RETVAL = &PL_sv_undef;
	
	if (items > 1) {
	    SAVESPTR(GvSV(PL_defgv));
	    cv = sv_2cv(code, &stash, &gv, 0);
	    firstvalop = CvSTART(cv);
	    SAVESPTR(CvROOT(cv)->op_ppaddr);
	    CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];
#ifdef PAD_SET_CUR
	    PAD_SET_CUR(CvPADLIST(cv),1);
#else
	    SAVESPTR(PL_curpad);
	    PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);
#endif
	    SAVETMPS;
	    SAVESPTR(PL_op);
	    CATCH_SET(TRUE);
	    PUSHBLOCK(cx, CXt_SUB, SP);
	    PUSHSUB(cx);
		
	    for (i = 1; i < items; i++) {
		GvSV(PL_defgv) = ST(i);
		PL_op = firstvalop;
		CALLRUNOPS(aTHX);
		if (SvTRUE(*PL_stack_sp)) {
		    /* see comment in indexes() */
		    SvREFCNT_inc(RETVAL = ST(i));
		    break;
		}
	    }
	    POPBLOCK(cx,PL_curpm);
	    CATCH_SET(oldcatch);
	    LEAVESUB(cv);
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
	register int i;
	int exhausted = 1;
	
	/* 'cv' is the hidden argument with which XS_List__MoreUtils__array_iterator (this XSUB)
	 * is called. The closure_arg struct is stored in this CV. */
#define ME_MYSELF_AND_I cv
	
	arrayeach_args *args = (arrayeach_args*)CvXSUBANY(ME_MYSELF_AND_I).any_ptr;
	
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
		SvREFCNT_inc(ST(i));
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
	register int i;
	arrayeach_args * args;
	HV *stash = gv_stashpv("List::MoreUtils_ea", TRUE);
	CV *closure = newXS(NULL, XS_List__MoreUtils__array_iterator, __FILE__);

	/* prototype */
	sv_setpv((SV*)closure, ";$");

	New(0, args, 1, arrayeach_args);
	New(0, args->avs, items, AV*);
	args->navs = items;
	args->curidx = 0;

	for (i = 0; i < items; i++) 
	    args->avs[i] = (AV*)SvRV(ST(i));
	
	CvXSUBANY(closure).any_ptr = args;
	RETVAL = newRV_noinc((SV*)closure);

	/* in order to allow proper cleanup in DESTROY-handler */
	sv_bless(RETVAL, stash);
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
	
	register int i;
	AV *avs[2];
	SV **oldsp;
	
	int nitems = 0, maxitems = 0;

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
	
	register int i, j;
	AV *avs[2];
	SV **oldsp;
	register SV **buf, **p;	/* gather return values here and later copy down to SP */
	int alloc;
	
	int nitems = 0, maxitems = 0;
	register int d;
	
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
	    SPAGAIN;
	    nitems += nret;
	    if (nitems > alloc) {
		alloc <<= 2;
		Renew(buf, alloc, SV*);
	    }
	    for (j = nret-1; j >= 0; j--) {
		/* POPs would return elements in reverse order */
		buf[d] = sp[-j];
		SvREFCNT_inc(buf[d]);
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
	register int i;
	int nret;

	/* 'cv' is the hidden argument with which XS_List__MoreUtils__array_iterator (this XSUB)
	 * is called. The closure_arg struct is stored in this CV. */
#define ME_MYSELF_AND_I cv
	
	natatime_args *args = (natatime_args*)CvXSUBANY(ME_MYSELF_AND_I).any_ptr;
	
	nret = args->natatime;
	
	EXTEND(SP, nret);

	for (i = 0; i < args->natatime; i++) {
	    if (args->nsvs) {
		ST(i) = sv_2mortal(newSVsv(args->svs[args->curidx++]));
		args->nsvs--;
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
	register int i;
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
	register int i, j, maxidx = -1;
	AV **avs;
	New(0, avs, items, AV*);
	
	for (i = 0; i < items; i++) {
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
	register int i, count = 0;
	HV *hv = newHV();
	
	/* don't build return list in scalar context */
	if (GIMME == G_SCALAR) {
	    for (i = 0; i < items; i++) {
		if (!hv_exists_ent(hv, ST(i), 0)) {
		    count++;
		    hv_store_ent(hv, ST(i), &PL_sv_yes, 0);
		}
	    }
	    SvREFCNT_dec(hv);
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
	SvREFCNT_dec(hv);
	XSRETURN(count);
    }

void
minmax (...)
    PROTOTYPE: @
    CODE:
    {
	register int i;
	register SV *minsv, *maxsv, *asv, *bsv;
	register double min, max, a, b;
	
	if (!items)
	    XSRETURN_EMPTY;

	minsv = maxsv = ST(0);
	min = max = slu_sv_value(minsv);

	for (i = 1; i < items; i += 2) {
	    asv = ST(i-1);
	    bsv = ST(i);
	    a = slu_sv_value(asv);
	    b = slu_sv_value(bsv);
	    if (a <= b) {
		if (min > a) {
		    min = a;
		    minsv = asv;
		}
		if (max < b) {
		    max = b;
		    maxsv = bsv;
		}
	    } else {
		if (min > b) {
		    min = b;
		    minsv = bsv;
		}
		if (max < a) {
		    max = a;
		    maxsv = asv;
		}
	    }
	}

	if (items & 1) {
	    asv = ST(items-2);
	    bsv = ST(items-1);
	    a = slu_sv_value(asv);
	    b = slu_sv_value(bsv);
	    if (a <= b) {
		if (min > a) {
		    min = a;
		    minsv = asv;
		}
		if (max < b) {
		    max = b;
		    maxsv = bsv;
		}
	    } else {
		if (min > b) {
		    min = b;
		    minsv = bsv;
		}
		if (max < a) {
		    max = a;
		    maxsv = asv;
		}
	    }
	}
	ST(0) = minsv;
	ST(1) = maxsv;

	XSRETURN(2);
    }

void
_XScompiled ()
    CODE:
	XSRETURN_YES;


MODULE = List::MoreUtils                PACKAGE = List::MoreUtils_ea

void
DESTROY(sv)
    SV *sv;
    CODE:
    {
	CV *code = (CV*)SvRV(sv);
	arrayeach_args *args = CvXSUBANY(code).any_ptr;
	if (args) {
	    Safefree(args->avs);
	    Safefree(args);
	    CvXSUBANY(code).any_ptr = NULL;
	}
    }


MODULE = List::MoreUtils                PACKAGE = List::MoreUtils_na

void
DESTROY(sv)
    SV *sv;
    CODE:
    {
	CV *code = (CV*)SvRV(sv);
	natatime_args *args = CvXSUBANY(code).any_ptr;
	if (args) {
	    Safefree(args->svs);
	    Safefree(args);
	    CvXSUBANY(code).any_ptr = NULL;
	}
    }

