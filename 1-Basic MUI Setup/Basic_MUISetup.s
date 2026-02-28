**	$VER: Basic_MUISetup.s v1.0 release (March 2026)
**	Platform: Amiga 68K with MUI
**	Assemble command:
**				vasmm68k_mot Basic_MUISetup.s -Fhunkexe
**	
**	Author: Tomas Jacobsen - Bedroomcoders.com
**	Description: 
**
**			This code demontrates how to build a simple MUI application that:
**			- have one Window containing one vertical layout group nested with two horizontal groups
**			- four text/buttons organized in two rows (2 buttons in each horizontal group)
**			- adds application quit notify to Quit button and the windows close gadget
**			- adds a callback hook to Button1 (performs a DisplayBeep)
**			- Button2 and Button3 have no action
**			- Extracts the Intuition compatible WindowBase and UserPort from the MUI window
**			- Loops in a minimal Eventhandler that only looks for Quit. All other functions are hooks.
**			


			opt d+
			output ram:Basic_MUISetup

			incdir	"include:"
			include	"exec/exec.i"
			include	"exec/exec_lib.i"
			include	"intuition/intuition.i"
			include	"intuition/intuition_lib.i"
			include	"libraries/mui.i"
			include	"lvo/mui_lib.i"

			IFND	MACROS_I
				include	"Macros.i"
			ENDC



MT_WINDOWID		equ 1
MT_WINDOWWIDTH		equ 300
MT_WINDOWHEIGHT		equ 300



		STRUCTURE	mt,0
			APTR	mt_MUIBase
			APTR	mt_IntuitionBase
			LONG	mt_Quit
			APTR	mt_Intui_Window
			APTR	mt_Intui_UserPort
			APTR	mt_MUI_Application
			APTR	mt_MUI_Window
			APTR	mt_MUI_Group
			APTR	mt_MUI_QuitButton
			APTR	mt_MUI_Button1
			APTR	mt_MUI_Button2
			APTR	mt_MUI_Button3
			APTR	mt_MUI_HGroup1
			APTR	mt_MUI_HGroup2
			APTR	mt_MUI_VGroup
		LABEL	mt_SIZEOF



			section code,Code


			;------------------------------------------------------------
			; mt_Main
			;------------------------------------------------------------

mt_Main			move.l	4.w,a6
			move.l	#mt_SIZEOF,d0
			move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
			jsr	_LVOAllocMem(a6)
			move.l	d0,a5					; Internal MT Struct in a5 at all times
			beq	.allocError
			move.l	d0,mt_StructPointer
			
			lea	mt_MUIName,a1
			moveq	#0,d0
			jsr	_LVOOpenLibrary(a6)			; Open muimaster.library
			move.l	d0,mt_MUIBase(a5)
			beq	.muilibError

			lea	mt_IntuitionName,a1
			moveq	#0,d0
			jsr	_LVOOpenLibrary(a6)			; Open intuition.library
			move.l	d0,mt_IntuitionBase(a5)
			beq	.intuitionError

			bsr	mt_BuildGui				; Create MUI - Application, Window, buttons, etc
			bne.s	.muiError

			bsr	mt_CreateHooks				; Create Notifications and Hooks
									
			movea.l	mt_IntuitionBase(a5),a6
			movea.l	mt_MUI_Window(a5),a0
			move.l	#MUIA_Window_Window,d0
			lea	mt_Intui_Window(a5),a1
			jsr	_LVOGetAttr(a6)				; Extract Intuition WindowBase from MUI Window
			beq.s	.intuiwinError
			
			movea.l	mt_Intui_Window(a5),a0
			move.l	wd_UserPort(a0),mt_Intui_UserPort(a5)	; Get UserPort the regular way


			bsr	mt_EventHandler				; Loops until quit


.intuiwinError
.muiError		movea.l	mt_MUIBase(a5),a6
			movea.l	mt_MUI_Application(a5),a0
			jsr	_LVOMUI_DisposeObject(a6)		
			
			movea.l	4.w,a6
			movea.l	mt_IntuitionBase(a5),a1
			jsr	_LVOCloseLibrary(a6)
			
.intuitionError		movea.l	4.w,a6
			movea.l	mt_MUIBase(a5),a1
			jsr	_LVOCloseLibrary(a6)

.muilibError		movea.l	4.w,a6
			movea.l	a5,a1
			move.l	#mt_SIZEOF,d0
			jsr	_LVOFreeMem(a6)

.allocError		rts



			;------------------------------------------------------------
			; mt_EventHandler
			;------------------------------------------------------------

mt_EventHandler		movem.l	d0/a0-a2/a6,-(sp)

.loop			movea.l	mt_MUI_Application(a5),a2				; MUI Objects are of ICLASS Type
			movea.l	-4(a2),a0						; Offset to Hook Struct (Is this undocumented?)
			movea.l	h_Entry(a0),a6						; Find entry to execute method
			lea	mt_Method_Input,a1
			jsr	(a6)							; DoMethod();

			cmp.l	#MUIV_Application_ReturnID_Quit,d0
			beq.s	.exit
    
			movea.l	4.w,a6
			move.l	mt_Signals,d0
			beq.s	.loop
			jsr	_LVOWait(a6)
			bra.s	.loop

.exit			movem.l	(sp)+,d0/a0-a2/a6
			rts



			;------------------------------------------------------------
			; mt_CreateHooks
			;------------------------------------------------------------

mt_CreateHooks		movem.l	a0-a2/a6,-(sp)

			movea.l	mt_MUI_Window(a5),a2
			movea.l	-4(a2),a0
			movea.l	h_Entry(a0),a6
			lea	mt_Method_WindowSetup,a1
			jsr	(a6)							; Set notify on close button

			movea.l	mt_MUI_QuitButton(a5),a2
			movea.l	-4(a2),a0
			movea.l	h_Entry(a0),a6
			lea	mt_Method_QuitButton,a1
			jsr	(a6)							; Set notify on quit button

			movea.l	mt_MUI_Button1(a5),a2
			movea.l	-4(a2),a0
			movea.l	h_Entry(a0),a6
			lea	mt_Method_Button1,a1
			jsr	(a6)							; Set hook to run mt_Button1Pressed

			movem.l	(sp)+,a0-a2/a6
			rts



			;------------------------------------------------------------
			; mt_Button1Pressed
			;------------------------------------------------------------

mt_Button1Pressed	movem.l	a0/a5-a6,-(sp)

			movea.l	mt_StructPointer,a5					; a5 is not preserved in a hook. Reload our struct in a5.
			movea.l	mt_IntuitionBase(a5),a6
			suba.l	a0,a0
			jsr	_LVODisplayBeep(a6)

			movem.l	(sp)+,a0/a5-a6
			rts
			


			;------------------------------------------------------------
			; mt_BuildGUI
			;------------------------------------------------------------
			; Result:
			; 	OK	d0 = 1
			;	Error 	d0 = 1

mt_BuildGui		movem.l	d5/a0-a1/a6,-(sp)

			movea.l	mt_MUIBase(a5),a6
			moveq	#1,d5
			
			lea	MUIC_Text,a0
			INITSTACKTAG
			STACKADRTAG	mt_QuitButtonTitle, MUIA_Text_Contents
			STACKVALTAG	MUIV_InputMode_RelVerify, MUIA_InputMode
			STACKVALTAG	MUII_ButtonBack, MUIA_Background
			STACKVALTAG	MUIV_Frame_Button, MUIA_Frame
			CALLSTACKTAG	_LVOMUI_NewObjectA,a1
			move.l	d0,mt_MUI_QuitButton(a5)				; Create Quit Button
			beq	.error

			lea	MUIC_Text,a0
			INITSTACKTAG
			STACKADRTAG	mt_Button1Title, MUIA_Text_Contents
			STACKVALTAG	MUIV_InputMode_RelVerify, MUIA_InputMode
			STACKVALTAG	MUII_ButtonBack, MUIA_Background
			STACKVALTAG	MUIV_Frame_Button, MUIA_Frame
			CALLSTACKTAG	_LVOMUI_NewObjectA,a1
			move.l	d0,mt_MUI_Button1(a5)					; Create Button1
			beq	.error

			lea	MUIC_Text,a0
			INITSTACKTAG
			STACKADRTAG	mt_Button2Title, MUIA_Text_Contents
			STACKVALTAG	MUIV_InputMode_RelVerify, MUIA_InputMode
			STACKVALTAG	MUII_ButtonBack, MUIA_Background
			STACKVALTAG	MUIV_Frame_Button, MUIA_Frame
			CALLSTACKTAG	_LVOMUI_NewObjectA,a1
			move.l	d0,mt_MUI_Button2(a5)					; Create Button2
			beq	.error

			lea	MUIC_Text,a0
			INITSTACKTAG
			STACKADRTAG	mt_Button3Title, MUIA_Text_Contents
			STACKVALTAG	MUIV_InputMode_RelVerify, MUIA_InputMode
			STACKVALTAG	MUII_ButtonBack, MUIA_Background
			STACKVALTAG	MUIV_Frame_Button, MUIA_Frame
			CALLSTACKTAG	_LVOMUI_NewObjectA,a1
			move.l	d0,mt_MUI_Button3(a5)					; Create Button3
			beq	.error

			lea	MUIC_Group,a0
			INITSTACKTAG
			STACKREGTAG	mt_MUI_QuitButton(a5), MUIA_Group_Child
			STACKREGTAG	mt_MUI_Button3(a5), MUIA_Group_Child
			STACKVALTAG	TRUE, MUIA_Group_Horiz
			CALLSTACKTAG	_LVOMUI_NewObjectA,a1
			move.l	d0,mt_MUI_HGroup1(a5)					; Create MUI Horizontal Group 1
			beq	.error

			lea	MUIC_Group,a0
			INITSTACKTAG
			STACKREGTAG	mt_MUI_Button2(a5), MUIA_Group_Child
			STACKREGTAG	mt_MUI_Button1(a5), MUIA_Group_Child
			STACKVALTAG	TRUE, MUIA_Group_Horiz
			CALLSTACKTAG	_LVOMUI_NewObjectA,a1
			move.l	d0,mt_MUI_HGroup2(a5)					; Create MUI Horizontal Group 2
			beq	.error

			lea	MUIC_Group,a0
			INITSTACKTAG
			STACKREGTAG	mt_MUI_HGroup1(a5), MUIA_Group_Child
			STACKREGTAG	mt_MUI_HGroup2(a5), MUIA_Group_Child
			STACKVALTAG	FALSE, MUIA_Group_Horiz
			CALLSTACKTAG	_LVOMUI_NewObjectA,a1
			move.l	d0,mt_MUI_VGroup(a5)					; Create MUI Vertical Group
			beq	.error

			lea	MUIC_Window,a0
			INITSTACKTAG
			STACKREGTAG	d0,MUIA_Window_RootObject
			STACKVALTAG	1,MUIA_Window_ID
			STACKADRTAG	mt_WindowTitle,MUIA_Window_Title
			STACKVALTAG	MT_WINDOWWIDTH, MUIA_Window_Width
			STACKVALTAG	MT_WINDOWHEIGHT, MUIA_Window_Height
			STACKVALTAG	TRUE, MUIA_Window_CloseGadget
			CALLSTACKTAG	_LVOMUI_NewObjectA,a1				; Create MUI Window
			move.l	d0,mt_MUI_Window(a5)
			beq	.error
			
			lea	MUIC_Application,a0
			INITSTACKTAG
			STACKREGTAG	d0,MUIA_Application_Window
			STACKADRTAG	mt_ApplicationTitle, MUIA_Application_Title
			STACKADRTAG	mt_AppBase, MUIA_Application_Base
			CALLSTACKTAG	_LVOMUI_NewObjectA,a1				; Create MUI Application
			move.l	d0,mt_MUI_Application(a5)
			beq.s	.error

			movea.l	mt_IntuitionBase(a5),a6
			movea.l	mt_MUI_Window(a5),a0
			INITSTACKTAG
			STACKVALTAG	1,MUIA_Window_Open
			CALLSTACKTAG	_LVOSetAttrsA,a1				; Open our window and draw gadgets

			moveq	#0,d5

.error			move.l	d5,d0
			movem.l	(sp)+,d5/a0-a1/a6
			tst.l	d0
			rts



			section data,Data

mt_MUIName		dc.b	"muimaster.library",0
mt_IntuitionName	dc.b	"intuition.library",0
mt_WindowTitle		dc.b	"My MUI Window",0
mt_QuitButtonTitle	dc.b	"Quit",0
mt_Button1Title		dc.b	"Button 1",0
mt_Button2Title		dc.b	"Button 2",0
mt_Button3Title		dc.b	"Button 3",0
mt_ApplicationTitle	dc.b	"My MUI application",0
mt_AppBase		dc.b	"MYAPP",0

MUIC_Application	dc.b	"Application.mui",0
MUIC_Window		dc.b	"Window.mui",0
MUIC_Group		dc.b	"Group.mui",0
MUIC_Text		dc.b	"Text.mui",0
			even

mt_StructPointer	dc.l	0

mt_Method_Input		dc.l	MUIM_Application_NewInput,mt_Signals
			dc.l	0

mt_Signals		ds.l	1							; Referenced from mt_Method_Input structure


mt_Method_WindowSetup	dc.l	MUIM_Notify,MUIA_Window_CloseRequest,TRUE
			dc.l	MUIV_Notify_Application,2
			dc.l	MUIM_Application_ReturnID,MUIV_Application_ReturnID_Quit

mt_Method_QuitButton	dc.l	MUIM_Notify,MUIA_Pressed,FALSE
			dc.l	MUIV_Notify_Application,2
			dc.l	MUIM_Application_ReturnID,MUIV_Application_ReturnID_Quit

mt_Method_Button1	dc.l	MUIM_Notify,MUIA_Pressed,FALSE
			dc.l	MUIV_Notify_Window,2
			dc.l	MUIM_CallHook,mt_Hook_Button1

mt_Hook_Button1		ds.b	MLN_SIZE
			dc.l	mt_Button1Pressed					; h_entry - Pointing to routine to be executed
			dc.l	0,0							; h_SubEntry, h_data


