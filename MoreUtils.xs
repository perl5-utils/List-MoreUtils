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
	if (!CvDEPTH(cv))
	    SvREFCNT_inc(cv);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = anyop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) {
	      POPBLOCK(cx,PL_curpm);
	      CATCH_SET(oldcatch);
	      XSRETURN_YES;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
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
	if (!CvDEPTH(cv))
	    SvREFCNT_inc(cv);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = allop;
	    CALLRUNOPS(aTHX);
	    if (!SvTRUE(*PL_stack_sp)) {
	      POPBLOCK(cx,PL_curpm);
	      CATCH_SET(oldcatch);
	      XSRETURN_NO;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
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
	if (!CvDEPTH(cv))
	    SvREFCNT_inc(cv);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = noneop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) {
	      POPBLOCK(cx,PL_curpm);
	      CATCH_SET(oldcatch);
	      XSRETURN_NO;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
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
	if (!CvDEPTH(cv))
	    SvREFCNT_inc(cv);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = notallop;
	    CALLRUNOPS(aTHX);
	    if (!SvTRUE(*PL_stack_sp)) {
	      POPBLOCK(cx,PL_curpm);
	      CATCH_SET(oldcatch);
	      XSRETURN_YES;
	    }
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
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
	if (!CvDEPTH(cv))
	    SvREFCNT_inc(cv);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = trueop;
	    CALLRUNOPS(aTHX);
	    if (SvTRUE(*PL_stack_sp)) 
		count++;
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	
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
	if (!CvDEPTH(cv))
	    SvREFCNT_inc(cv);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = ST(i);
	    PL_op = falseop;
	    CALLRUNOPS(aTHX);
	    if (!SvTRUE(*PL_stack_sp)) 
		RETVAL++;
	}
	POPBLOCK(cx,PL_curpm);
	CATCH_SET(oldcatch);
	
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
	    if (!CvDEPTH(cv))
		SvREFCNT_inc(cv);
		
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
	    if (!CvDEPTH(cv))
		SvREFCNT_inc(cv);
		
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
	if (!CvDEPTH(cv))
	    SvREFCNT_inc(cv);
	    
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
	if (!CvDEPTH(cv))
	    SvREFCNT_inc(cv);
		
	for(i = 1 ; i < items ; i++) {
	    GvSV(PL_defgv) = newSVsv(ST(i));
	    PL_op = applyop;
	    CALLRUNOPS(aTHX);
	    ST(i-1) =  GvSV(PL_defgv);
	}
	POPBLOCK(cx,PL_curpm)
	CATCH_SET(oldcatch);
	
	done:
	XSRETURN(items-1);
    }
