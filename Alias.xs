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

/* multicall.h is all nice and 
 * fine but wont work on perl < 5.6.0 */

#if PERL_VERSION > 5
#   include "multicall.h"
#else
#   define dMULTICALL						\
	OP *_op;						\
	PERL_CONTEXT *cx;					\
	SV **newsp;						\
	U8 hasargs = 0;						\
	bool oldcatch = CATCH_GET
#   define PUSH_MULTICALL(cv)					\
	_op = CvSTART(cv);					\
	SAVESPTR(CvROOT(cv)->op_ppaddr);			\
	CvROOT(cv)->op_ppaddr = PL_ppaddr[OP_NULL];		\
	SAVESPTR(PL_curpad);					\
	PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(cv))[1]);	\
	SAVETMPS;						\
	SAVESPTR(PL_op);					\
	CATCH_SET(TRUE);					\
	PUSHBLOCK(cx, CXt_SUB, SP);				\
	PUSHSUB(cx)
#   define MULTICALL						\
	PL_op = _op;						\
	CALLRUNOPS()
#   define POP_MULTICALL					\
	POPBLOCK(cx,PL_curpm);					\
	CATCH_SET(oldcatch);					\
	SPAGAIN
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

#ifndef SvPV_nolen
    STRLEN N_A;
#   define SvPV_nolen(sv) SvPV(sv, N_A)
#endif

#ifndef call_sv
#  define call_sv perl_call_sv
#endif

MODULE = List::MoreUtils::Impl::Alias		PACKAGE = List::MoreUtils::Impl::Alias

void
any (code,...)
    SV *code;
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    register int i;
    GV *gv;
    HV *stash;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *cv;

    if (items <= 1)
	XSRETURN_NO;

    cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(cv);
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
    register int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *cv;

    if (items <= 1)
	XSRETURN_YES;

    cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(cv);
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
    register int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *cv;

    if (items <= 1)
	XSRETURN_YES;

    cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(cv);
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
    register int i;
    HV *stash;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *cv;

    if (items <= 1)
	XSRETURN_NO;

    cv = sv_2cv(code, &stash, &gv, 0);
    PUSH_MULTICALL(cv);
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
