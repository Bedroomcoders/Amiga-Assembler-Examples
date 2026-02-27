	IFND	MACROS_I
MACROS_I SET	1

	IFND	UTILITY_TAGITEM_I
	include	"utility/tagitem.i"
	ENDC	; UTILITY_TAGITEM_I


			;------------------------------------------------------------
			; Stack Macros
			; Usage:
			;	- Start with INITSTACKTAG
			;	- Any number of STACKVALTAG, STACKREGTAG, and STACKADRTAG
			;	- Call funtion with CALLSTACKTAG
			;------------------------------------------------------------


INITSTACKTAG		MACRO						; No input or offset
			IFC	"\1",""
			pea	FALSE.w
			pea	TAG_DONE.w
STACKCOUNT		SET	8
			ENDC
			IFNC	"\1",""
STACKCOUNT		SET	\1
			ENDC
			ENDM

CALLSTACKTAG		MACRO						; Function, adress register
			movea.l	sp,\2					; Example: CALLSTACKTAG _LVOOpenWindowTaglist,a1
			jsr	\1(a6)
			lea	STACKCOUNT(sp),sp
			ENDM

STACKVALTAG		MACRO						; Value, ti_tag
			pea	\1
STACKCOUNT		SET	STACKCOUNT+8
			pea	\2
			ENDM

STACKREGTAG		MACRO						; Register,ti_tag
			move.l	\1,-(sp)
STACKCOUNT		SET	STACKCOUNT+8
			pea	\2
			ENDM

STACKADRTAG		MACRO						; Register,ti_tag
			pea	\1
STACKCOUNT		SET	STACKCOUNT+8
			pea	\2
			ENDM


	ENDC
