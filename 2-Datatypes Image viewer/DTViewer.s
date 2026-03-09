**	$VER: DTViewer.s v1.0 release (March 2026)
**	Platform: Amiga 68K
**	Assemble command:
**				vasmm68k_mot DTViewer.s -Fhunkexe
**	
**	Author: Tomas Jacobsen - Bedroomcoders.com
**	Description: 
**
**			This code demontrates how to load a picture from file using DataTypes and display it in a Window.


			opt d+
			output ram:DTViewer

			incdir	"include:"
			include	"exec/exec.i"
			include	"exec/exec_lib.i"
			include	"intuition/intuition.i"
			include	"intuition/intuition_lib.i"
			include	"datatypes/datatypes_lib.i"
			include	"datatypes/pictureclass.i"
			include	"graphics/graphics_lib.i"
			

			IFND	MACROS_I
				include	"Macros.i"
			ENDC



PDTA_DestMode		equ	$800010fb							; Not defined in ApolloOS include files
PMODE_V43		equ	$1



DTV_WINDOW_WIDTH	equ 1150
DTV_WINDOW_HEIGHT	equ 600



		STRUCTURE	dtv,0
			LONG	dtv_Quit
			APTR	dtv_DatatypesBase
			APTR	dtv_IntuitionBase
			APTR	dtv_GraphicsBase
			APTR	dtv_Window
			APTR	dtv_UserPort
			APTR	dtv_RastPort
			APTR	dtv_ImageObject
			APTR	dtv_BitmapHeader
			APTR	dtv_DestBitmap
			LONG	dtv_ImageWidth
			LONG	dtv_ImageHeight
		LABEL	dtv_SIZEOF



			section code,Code


			;------------------------------------------------------------
			; dtv_Main
			;------------------------------------------------------------

dtv_Main		move.l	4.w,a6
			move.l	#dtv_SIZEOF,d0
			move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
			jsr	_LVOAllocMem(a6)
			move.l	d0,a5							; Internal DTV Struct in a5 at all times
			beq	.allocError
			
			lea	dtv_DatatypesName,a1
			moveq	#43,d0							; V43 = at least AmigaOS 3.5 - ApolloOS have version 45
			jsr	_LVOOpenLibrary(a6)					; Open datatypes.library
			move.l	d0,dtv_DatatypesBase(a5)
			beq	.dtlibError

			lea	dtv_IntuitionName,a1
			moveq	#0,d0
			jsr	_LVOOpenLibrary(a6)					; Open intuition.library
			move.l	d0,dtv_IntuitionBase(a5)
			beq	.intuitionError

			lea	dtv_GraphicsName,a1
			moveq	#0,d0
			jsr	_LVOOpenLibrary(a6)					; Open graphics.library
			move.l	d0,dtv_GraphicsBase(a5)
			beq	.graphicsError

			bsr	dtv_OpenWindow						; Open Window and populate pointers
			bne.s	.windowError
			
			bsr	dtv_LoadImage						; Load our image using datatypes
			bne.s	.imageError

			move.l	dtv_DestBitmap(a5),d0
			tst.l	d0							; No Bitmap, no fun!
			beq.s	.imageError

			bsr	dtv_CheckImageSize					; Is Image larger than window?
			bsr	dtv_DrawImage						; Draw Image to our windows rastport
			

			bsr	dtv_EventHandler					; Wait for user to close window
			

			bsr	dtv_FreeDatatypes
.imageError		bsr	dtv_CloseWindow


.windowError		movea.l	4.w,a6
			movea.l	dtv_GraphicsBase(a5),a1
			jsr	_LVOCloseLibrary(a6)

.graphicsError		movea.l	4.w,a6
			movea.l	dtv_IntuitionBase(a5),a1
			jsr	_LVOCloseLibrary(a6)
			
.intuitionError		movea.l	4.w,a6
			movea.l	dtv_DatatypesBase(a5),a1
			jsr	_LVOCloseLibrary(a6)

.dtlibError		movea.l	4.w,a6
			movea.l	a5,a1
			move.l	#dtv_SIZEOF,d0
			jsr	_LVOFreeMem(a6)

.allocError		rts



			;------------------------------------------------------------
			; dtv_CheckImageSize
			;------------------------------------------------------------

dtv_CheckImageSize	movem.l	d0-d3/a0,-(sp)

			moveq	#0,d0
			moveq	#0,d1
			move.l	#DTV_WINDOW_WIDTH,d2
			move.l	#DTV_WINDOW_HEIGHT,d3
			
			movea.l	dtv_BitmapHeader(a5),a0
			move.w	(a0)+,d0						; d0 = Bitmap width
			move.w	(a0)+,d1						; d1 = Bitmap height
			
			cmp.w	d2,d0							; Is bitmap wider than window?
			ble.s	.noshrinkWidth
			move.w	d2,d0

.noshrinkWidth		cmp.w	d3,d1							; Is bitmap higher than window?
			ble.s	.noshrinkHeight
			move.w	d3,d1

.noshrinkHeight		move.l	d0,dtv_ImageWidth(a5)
			move.l	d1,dtv_ImageHeight(a5)
			
			movem.l	(sp)+,d0-d3/a0
			rts



			;------------------------------------------------------------
			; dtv_DrawImage
			;------------------------------------------------------------

dtv_DrawImage		movem.l	d0-d6/a0-a1/a6,-(sp)
			movea.l	dtv_GraphicsBase(a5),a6

			movea.l	dtv_DestBitmap(a5),a0
			moveq	#0,d0							; Source X
			moveq	#0,d1							; Source Y
			movea.l	dtv_RastPort(a5),a1
			moveq	#0,d2							; Destination X
			moveq	#0,d3							; Destination Y
			move.l	dtv_ImageWidth(a5),d4
			move.l	dtv_ImageHeight(a5),d5
			move.l	#$cc,d6							; Minterm = SRCCOPY
			jsr	_LVOBltBitMapRastPort(a6)

			movem.l	(sp)+,d0-d6/a0-a1/a6
			rts



			;------------------------------------------------------------
			; dtv_LoadImage
			;------------------------------------------------------------
			;
			; Result:
			;	d0 = 0 (OK)


dtv_LoadImage		movem.l	d5/a0-a3/a6,-(sp)
			moveq	#1,d5
			
			movea.l	dtv_DatatypesBase(a5),a6
			
			move.l	#dtv_ImageFile,d0					; Filename of image to load
			INITSTACKTAG
			STACKVALTAG	GID_PICTURE,DTA_GroupID				; Only load objects of picture.class (no sound, no text, etc)
			STACKVALTAG	FALSE,PDTA_Remap				; Do not remap image yet
			STACKVALTAG	PMODE_V43,PDTA_DestMode				; Specify high color mode for AmigaOS (ApolloOS handles this automatically)
			CALLSTACKTAG	_LVONewDTObjectA,a0				; Load image from file
			move.l	d0,dtv_ImageObject(a5)
			beq	.error

			movea.l	dtv_ImageObject(a5),a0
			suba.l	a1,a1
			suba.l	a2,a2
			lea	dtv_ProcLayoutMsg,a3
			jsr	_LVODoDTMethodA(a6)					; Process layout to generate bitmap

			movea.l	dtv_ImageObject(a5),a0
			INITSTACKTAG
			STACKADRTAG	dtv_DestBitmap(a5),PDTA_DestBitMap
			STACKADRTAG	dtv_BitmapHeader(a5),PDTA_BitMapHeader
			CALLSTACKTAG	_LVOGetDTAttrsA,a2				; Fetch Bitmap and Bitmap header
			
			moveq	#0,d5
			
.error			move.l	d5,d0
			movem.l	(sp)+,d5/a0-a3/a6
			tst.l	d0
			rts



			;------------------------------------------------------------
			; dtv_FreeDatatypes
			;------------------------------------------------------------

dtv_FreeDatatypes	movem.l	d0-d1/a0-a1/a6,-(sp)

			movea.l	dtv_DatatypesBase(a5),a6
			
			movea.l	dtv_Window(a5),a0
			movea.l	dtv_ImageObject(a5),a1
			jsr	_LVORemoveDTObject(a6)
			
			movea.l	dtv_ImageObject(a5),a0
			jsr	_LVODisposeDTObject(a6)

			movem.l	(sp)+,d0-d1/a0-a1/a6
			rts



			;------------------------------------------------------------
			; dtv_EventHandler
			;------------------------------------------------------------

dtv_EventHandler	movem.l d0-d3/a0-a2/a6,-(sp)
			move.l	#0,dtv_Quit(a5)
			
.WaitLoop		movea.l	4.w,a6
			movea.l	dtv_UserPort(a5),a0
			jsr	_LVOWaitPort(a6)

.GetMsg			movea.l	dtv_UserPort(a5),a0
			jsr	_LVOGetMsg(a6)
			tst.l	d0
			beq.s	.WaitLoop

			move.l	d0,a1
			move.l	im_Class(a1),d2				d2 = im_Class
			moveq	#0,d3
			move.w	im_Code(a1),d3				d3 = im_Code
			move.l	im_IAddress(a1),a2			a2 = IAddress
			jsr	_LVOReplyMsg(a6)
			
			cmp.l	#IDCMP_CLOSEWINDOW,d2			; Handle Windows Close button
			bne.s	.notClose
			move.l	#1,dtv_Quit(a5)

.notClose		cmp.l	#IDCMP_REFRESHWINDOW,d2
			bne.s	.notRefresh
			bsr	dtv_DrawImage

.notRefresh		cmp.l	#IDCMP_NEWSIZE,d2
			bne.s	.notNewsize
			bsr	dtv_DrawImage
			

.notNewsize		move.l	dtv_Quit(a5),d0
			tst.l	d0
			beq	.GetMsg
			bsr	dtv_DrainIDCMP
			movem.l	(sp)+,d0-d3/a0-a2/a6
			rts
			


			;------------------------------------------------------------
			; dtv_DrainIDCMP
			;------------------------------------------------------------

dtv_DrainIDCMP		movem.l	d0-d1/a0-a1/a6,-(sp)
			movea.l	4.w,a6

.drain			movea.l	dtv_UserPort(a5),a0
			jsr	_LVOGetMsg(a6)
			tst.l	d0
			beq.s	.done
			move.l	d0,a1
			jsr	_LVOReplyMsg(a6)
			bra.s	.drain
    
.done			movem.l (sp)+,d0-d1/a0-a1/a6
			rts




			;------------------------------------------------------------
			; dtv_OpenWindow
			;------------------------------------------------------------
			;
			; Result:
			;	d0 = 0 (OK)

dtv_OpenWindow		movem.l	d5/a0-a1/a6,-(sp)

			moveq	#1,d5							; Error until OK is confirmed
			movea.l	dtv_IntuitionBase(a5),a6

			sub.l	a0,a0
			INITSTACKTAG
			STACKVALTAG	100,WA_MinWidth
			STACKVALTAG	100,WA_MinHeight
			STACKVALTAG	0,WA_Top
			STACKVALTAG	0,WA_Left
			STACKVALTAG	DTV_WINDOW_WIDTH,WA_Width
			STACKVALTAG	DTV_WINDOW_HEIGHT,WA_Height
			STACKADRTAG	dtv_WindowTitle,WA_Title
			STACKVALTAG	IDCMP_CLOSEWINDOW|IDCMP_NEWSIZE|IDCMP_REFRESHWINDOW,WA_IDCMP
			STACKVALTAG	TRUE.w,WA_Activate
			STACKVALTAG	WFLG_CLOSEGADGET|WFLG_DRAGBAR|WFLG_DEPTHGADGET|WFLG_SIZEGADGET|WFLG_SIZEBBOTTOM|WFLG_SMART_REFRESH|WFLG_NOCAREREFRESH|WFLG_GIMMEZEROZERO|WFLG_ACTIVATE,WA_Flags
			CALLSTACKTAG	_LVOOpenWindowTagList,a1			; Open our window
			move.l	d0,dtv_Window(a5)
			beq.s	.error
			
			movea.l	d0,a0
			move.l	wd_UserPort(a0),dtv_UserPort(a5)			; Extract windows UserPort
			move.l	wd_RPort(a0),dtv_RastPort(a5)				; Extract windows RastPort
			moveq	#0,d5							; All OK
			
.error			move.l	d5,d0
			movem.l	(sp)+,d5/a0-a1/a6
			tst.l	d0
			rts



			;------------------------------------------------------------
			; dtv_CloseWindow
			;------------------------------------------------------------

dtv_CloseWindow
			movem.l	a0/a6,-(sp)

			movea.l	dtv_IntuitionBase(a5),a6
			movea.l	dtv_Window(a5),a0
			jsr	_LVOCloseWindow(a6)

			movem.l	(sp)+,a0/a6
			rts



			section data,Data

dtv_DatatypesName	dc.b	"datatypes.library",0
dtv_IntuitionName	dc.b	"intuition.library",0
dtv_GraphicsName	dc.b	"graphics.library",0
dtv_WindowTitle		dc.b	"Datatypes image viewer",0
dtv_ImageFile		dc.b	"NioCars.png",0
			even

dtv_ProcLayoutMsg	dc.l	DTM_PROCLAYOUT				; Method
			dc.l	0					; GInfo
			dc.l	1					; Initial
