//   Magic Desk Compatible Cartridge Generator (c) 2013-2019  Žarko Živanov
//   Cartridge schematics and PCB design (c) 2013-2014 Marko Šolajić
//   E-mails: zzarko and msolajic at gmail

//   This program is free software: you can redistribute it and/or modify
//   it under the terms of the GNU General Public License as published by
//   the Free Software Foundation, either version 3 of the License, or
//   (at your option) any later version.

//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License for more details.

//   You should have received a copy of the GNU General Public License
//   along with this program.  If not, see <http://www.gnu.org/licenses/>.

//BasicUpstart2(init_menu)

// ZP usage:
// ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **
// 02 14 15 16 17 18 19 1A 1B 1C 1D 1E 1F 20 21 22 23 24 25 26 27 28 29 2A FB FC FD FE
// ** ** ** ** ** **
// 52 57 58 59 5A 5B 5C 5D 5E 5F 60 61 62 63 64 65 66 67 68 69 6A 6B 6C 6D 6E

//--------------------------------
// RAM and ROM
//--------------------------------

.label SCREEN   = $0400
.label COLORR   = $D800 //$D800
.label CHROUT   = $FFD2
.label GETIN    = $FFE4
.label SCNKEY   = $FF9F
.label COLDRES  = $FCE2
.label BORDER   = $D020
.label PAPER    = $D021
.label IRQ_Vector = $0314
.label IRQ_Kernel = $EA31
.label CursorColor = $0286

.label drive    = $BA
.label status   = $90
.label LISTEN   = $FFB1
.label SECOND   = $FF93
.label UNLSTN   = $FFAE

//--------------------------------
// menu variables
//--------------------------------

// current menu variables
.label current_menu     = $25
.label prev_menu        = $5C
.label cmenu_offset     = $1A   // 2B offset from screen start
.label cmenu_offset_it  = $1C   // 2B offset from screen start for items
.label cmenu_offset_key = $26   // 2B offset from screen start for item key
.label cmenu_width      = $1E   // 1B menu inside width
.label cmenu_height     = $1F   // 1B menu inside height
.label cmenu_iwidth     = $20   // 1B menu inside width minus chars for key
.label cmenu_items_no   = $21   // 1B number of items
.label cmenu_max_first  = $22   // 1B max value for first item
.label cmenu_items      = $23   // 1B pointer to list of items
.label cmenu_first_idx  = $19   // 1B index of first item to show
.label cmenu_item_adr   = $14   // 2B pointer to current item text
.label cmenu_item_idx   = $16   // 1B current item index
.label cmenu_spacing    = $2A   // 1B menu items spacing (0-no spacing,1-1 line)

// misc menu variables
.label temp             = $02   // 1B temorary value
.label chrmem           = $FB   // 2B pointer to addres on screen
.label colmem           = $FD   // 2B pointer to addres in color ram
.label chrkeymem        = $28   // 2B pointer to addres on screen for key
.label drawm_line       = $17   // 1B current line when drawing items
.label drawm_idx        = $18   // 1B current item index when drawing items

//--------------------------------
// IRQ variables
//--------------------------------

.const SCR_FirstLine = 58
.const SCR_LastLine  = 242

// IRQ wave variables
.const WaveSpeed     = 2
.label CurrentLine   = $58
.label CurrentWave   = $59
.label FirstWave     = $5A
.label WavePause     = $5B

//--------------------------------
// cartridge start
//--------------------------------

* = $8000
//* = $0820
.word cold_start
.word prepare_run
.byte $c3,$c2,$cd,$38,$30 // cartridge magic bytes, CBM80

cold_start:
        stx $d016
        jsr $FDA3       // IOINIT, init CIA,IRQ
        jsr $FD50       // RAMTAS, init memory
        jsr $FD15       // RESTOR, init I/O
        jsr $FF5B       // SCINIT, init video
        cli
        jsr $E453       // load BASIC vectors
        jsr $E3BF       // init BASIC RAM
        jsr $E422       // print BASIC start up messages
        ldx #$FB        // init BASIC stack
        txs

        // debug
        // lda #5
        // sta current_menu
        // lda #12
        // jmp prepare_run

        jmp prepare_run

//--------------------------------
// memory copy
//--------------------------------

.label TableAddress  = $FB

prepare_run:
        jsr $E453       // load BASIC vectors
        jsr $E3BF       // init BASIC RAM
        //jsr $A68E       // set current character pointer to start of basic - 1
        //jsr $E422       // print BASIC start up messages
        //ldx #$FB
        //txs                     

startCopy:
        ldy #CartCopyLen    // copy routine to 0340
!:      lda CartCopy0340,y
        sta $0340,y
        dey
        bne !-
        // last copy
        lda CartCopy0340
        sta $0340
        lda ProgramTable
        sta TableAddress
        lda ProgramTable+1
        sta TableAddress+1
        ldy #0
        lda (TableAddress),y    //set values in copy routine
        sta CartBank
        iny;lda (TableAddress),y
        sta CartAddr
        iny;lda (TableAddress),y
        sta CartAddr+1
        iny;lda (TableAddress),y
        sta PrgLenLo
        iny;lda (TableAddress),y
        sta PrgLenHi
        iny;lda (TableAddress),y
        sta MemAddr
        iny;lda (TableAddress),y
        sta MemAddr+1
        iny;lda (TableAddress),y
        sta pstart+1
        iny;lda (TableAddress),y
        sta pstart+2
        beq sc3     //if high byte of start address != 0
        lda #$4c    //change lda to jmp
        sta pstart  //else, run as basic
sc3:    jmp $0340

CartCopy0340:
.pseudopc $0340 {
        ldx PrgLenLo:#00    //program length lo
        ldy PrgLenHi:#00    //program length hi
cbank:  lda CartBank:#00    //cartridge start bank
        sta $de00           //cartridge bank switching address
caddr:  lda CartAddr:$8200  //cartridge start adr
        sta MemAddr:$0801   //c64 memory start adr
        dex
        cpx #$ff
        bne cc1
        dey
        cpy #$ff
        beq crtoff
cc1:    inc MemAddr
        bne cc2
        inc MemAddr+1
        // IO area check
        lda MemAddr+1
        cmp #$d0
        bne cc2
        // skip IO area
        // 1. inc cart addr
        inc CartAddr
        bne caddr_1
        inc CartAddr+1
caddr_1:
        // 2. update index ref
        tya
        sec
        sbc #$10
        tay
        // 3. Update mem address
        lda #$e0
        sta MemAddr+1
        // 4. Update cart address
        lda CartAddr+1
        clc
        adc #$10
        sta CartAddr+1
        // 5. prepare bank switching
        cmp #$a0
        bcc caddr
        sbc #$a0
        clc
        adc #$80
        sta CartAddr+1
        jmp cbank
cc2:    inc CartAddr
        bne caddr
        inc CartAddr+1
        lda CartAddr+1
        cmp #$a0        //next bank?
        bne caddr
        inc CartBank
        lda #$80        //cartridge bank is on $8000-$9fff
        sta CartAddr+1
        jmp cbank
crtoff: lda #$ff        //turn off cartridge
        sta $de00
        lda MemAddr     //set end of program (var start)
        sta $2d
        sta $2f
        sta $31
        sta $ae
        lda MemAddr+1
        sta $2e
        sta $30
        sta $32
        sta $af
pstart: lda $0801       //start the program
        lda #00         // basic start
        jsr $A871       // clr
        jsr $A533       // re-link
        jsr $A68E       // set current character pointer to start of basic - 1
        jmp $A7AE       // run
}
.label CartCopyLen = *-CartCopy0340

// I couldn't remove this, sorry
*=* "Menu Data" virtual

ProgramTable:   .word programs

// program run colors
RunBorderColor: .byte 12 //14
RunPaperColor:  .byte 6 //6 15
RunInkColor:    .byte 0  //14
DoWave:         .byte 0  //menu waving
DoSound:        .byte 0  //menu sound

// menu data for 8 menus
menu_items_no:  .byte 1,0,0,0,0,0,0,0
menu_offset:    .word 85,0,0,0,0,0,0,0
menu_width:     .byte 15,0,0,0,0,0,0,0
menu_height:    .byte 10,0,0,0,0,0,0,0
menu_spacing:   .byte 1,0,0,0,0,0,0,0

menu_names:     .word menu_name1,0,0,0,0,0,0,0
menu_items:     .word menu_items1,0,0,0,0,0,0,0

menu_help:      .text "(Shift)CRSR: Scroll, Fn/Ret: Menu select"

menu_name1:     .text "            Testing...                  "

menu_items1:
        .text @"Testing1\$00"
        .text @"Testing2\$00"

programs:
// program table
// .byte bank
// .word address in bank
// .word length
// .word load address
// .word start address
//     if hi byte=0, then run as basic

// ne radi
// f4/6 64tester
// f4/c basic 64 compiler
// f5/e turbocopy 5
// f5/h turbo nibbler 5
