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

MODULE = List::MoreUtils::Impl::Modern		PACKAGE = List::MoreUtils::Impl::Modern
void
first(block,...)
    SV *block
PROTOTYPE: &@
CODE:
{
    int index;
    GV *gv;
    HV *stash;
    SV **args = &PL_stack_base[ax];
    CV *cv    = sv_2cv(block, &stash, &gv, 0);

    if(cv == Nullcv)
        croak("Not a subroutine reference");

    if(items <= 1)
        XSRETURN_UNDEF;

    SAVESPTR(GvSV(PL_defgv));
#ifdef dMULTICALL
    if(!CvISXSUB(cv)) {
        dMULTICALL;
        I32 gimme = G_SCALAR;
        PUSH_MULTICALL(cv);

        for(index = 1 ; index < items ; index++) {
            GvSV(PL_defgv) = args[index];
            MULTICALL;
            if(SvTRUEx(*PL_stack_sp)) {
#  ifdef PERL_HAS_BAD_MULTICALL_REFCOUNT
                if(CvDEPTH(multicall_cv) > 1)
                    SvREFCNT_inc_simple_void_NN(multicall_cv);
#  endif
                POP_MULTICALL;
                ST(0) = ST(index);
                XSRETURN(1);
            }
        }
#  ifdef PERL_HAS_BAD_MULTICALL_REFCOUNT
        if(CvDEPTH(multicall_cv) > 1)
            SvREFCNT_inc_simple_void_NN(multicall_cv);
#  endif
        POP_MULTICALL;
    }
    else
#endif
    {
        for(index = 1 ; index < items ; index++) {
            dSP;
            GvSV(PL_defgv) = args[index];

            PUSHMARK(SP);
            call_sv((SV*)cv, G_SCALAR);
            if(SvTRUEx(*PL_stack_sp)) {
                ST(0) = ST(index);
                XSRETURN(1);
            }
        }
    }
    XSRETURN_UNDEF;
}


void
any(block,...)
    SV *block
ALIAS:
    none   = 0
    all    = 1
    any    = 2
    notall = 3
PROTOTYPE: &@
PPCODE:
{
    int ret_true = !(ix & 2); /* return true at end of loop for none/all; false for any/notall */
    int invert   =  (ix & 1); /* invert block test for all/notall */
    GV *gv;
    HV *stash;
    SV **args = &PL_stack_base[ax];
    CV *cv    = sv_2cv(block, &stash, &gv, 0);

    if(cv == Nullcv)
        croak("Not a subroutine reference");

    SAVESPTR(GvSV(PL_defgv));
#ifdef dMULTICALL
    if(!CvISXSUB(cv)) {
        dMULTICALL;
        I32 gimme = G_SCALAR;
        int index;

        PUSH_MULTICALL(cv);
        for(index = 1; index < items; index++) {
            GvSV(PL_defgv) = args[index];

            MULTICALL;
            if(SvTRUEx(*PL_stack_sp) ^ invert) {
                POP_MULTICALL;
                ST(0) = ret_true ? &PL_sv_no : &PL_sv_yes;
                XSRETURN(1);
            }
        }
        POP_MULTICALL;
    }
    else
#endif
    {
        int index;
        for(index = 1; index < items; index++) {
            dSP;
            GvSV(PL_defgv) = args[index];

            PUSHMARK(SP);
            call_sv((SV*)cv, G_SCALAR);
            if(SvTRUEx(*PL_stack_sp) ^ invert) {
                ST(0) = ret_true ? &PL_sv_no : &PL_sv_yes;
                XSRETURN(1);
            }
        }
    }

    ST(0) = ret_true ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

