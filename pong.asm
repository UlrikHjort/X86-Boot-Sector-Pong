; *************************************************************************** 
;                       Boot Sector Pong  
;
;           Copyright (C) 2026 By Ulrik Hørlyk Hjort
; 
; Permission is hereby granted, free of charge, to any person obtaining
; a copy of this software and associated documentation files (the
; "Software"), to deal in the Software without restriction, including
; without limitation the rights to use, copy, modify, merge, publish,
; distribute, sublicense, and/or sell copies of the Software, and to
; permit persons to whom the Software is furnished to do so, subject to
; the following conditions:
;
; The above copyright notice and this permission notice shall be
; included in all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
; WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
; ***************************************************************************   
	
BITS 16
ORG 0x7C00

start:
    ; Set up video mode (80x25 text mode) and hide cursor
    mov ax, 0x0003          ; Video mode 3 (text)
    int 0x10                ; BIOS video interrupt
    
    mov ah, 0x01            ; Set cursor shape
    mov ch, 0x20            ; Make cursor invisible
    int 0x10
    
    ; Initialize game variables
    mov byte [paddle_x], 35 ; Center paddle (screen is 80 chars wide)
    mov byte [ball_x], 40   ; Center ball horizontally
    mov byte [ball_y], 12   ; Center ball vertically
    mov byte [ball_dx], 1   ; Ball velocity X (moving right)
    mov byte [ball_dy], 1   ; Ball velocity Y (moving down)
    mov word [score], 0     ; Initialize score to 0
    
    call draw_score         ; Draw initial score display

main_loop:
    ; Check for keyboard input (non-blocking)
    mov ah, 0x01            ; Check keyboard status
    int 0x16                ; BIOS keyboard interrupt
    jz no_key               ; Jump if no key pressed
    
    ; Read the key that was pressed
    mov ah, 0x00            ; Read keyboard
    int 0x16
    
    ; Check which key was pressed
    cmp ah, 0x4B            ; Left arrow scan code
    je move_left
    cmp ah, 0x4D            ; Right arrow scan code
    je move_right
    cmp al, 'q'             ; Q to quit
    je end_program
    
no_key:
    ; Frame counter to slow down ball movement
    inc byte [frame_counter]
    mov al, [frame_counter]
    cmp al, 3               ; Update ball every 3 frames
    jb skip_ball            ; Skip ball update if counter < 3
    
    ; Reset frame counter and update ball
    mov byte [frame_counter], 0
    call erase_ball         ; Erase ball at old position
    call update_ball        ; Calculate new ball position
    
skip_ball:
    ; Draw game elements
    call draw_ball
    call draw_paddle
    
    ; Delay to control game speed
    mov cx, 0x0001          ; High word of microseconds
    xor dx, dx              ; Low word of microseconds
    mov ah, 0x86            ; Wait function
    int 0x15                ; BIOS time services
    
    jmp main_loop           ; Continue game loop

move_left:
    call erase_paddle       ; Erase paddle at old position
    mov al, [paddle_x]
    cmp al, 0               ; Check if at left edge
    je main_loop            ; Don't move if at edge
    dec byte [paddle_x]     ; Move paddle left
    jmp main_loop

move_right:
    call erase_paddle       ; Erase paddle at old position
    mov al, [paddle_x]
    add al, 10              ; paddle_x + paddle_width (10)
    cmp al, 80              ; Check if at right edge (screen width)
    jge main_loop           ; Don't move if at edge
    inc byte [paddle_x]     ; Move paddle right
    jmp main_loop

update_ball:
    ; Update ball X position
    mov al, [ball_x]
    add al, [ball_dx]       ; Add X velocity
    mov [ball_x], al
    
    ; Check left wall collision
    cmp al, 0
    jne .cr                 ; Not at left wall
    mov byte [ball_dx], 1   ; Bounce right
.cr:
    ; Check right wall collision
    cmp al, 79              ; Right edge of screen
    jne .uy                 ; Not at right wall
    mov byte [ball_dx], -1  ; Bounce left
    
.uy:
    ; Update ball Y position
    mov al, [ball_y]
    add al, [ball_dy]       ; Add Y velocity
    mov [ball_y], al
    
    ; Check top wall collision
    cmp al, 0
    jne .cp                 ; Not at top
    mov byte [ball_dy], 1   ; Bounce down
    
.cp:
    ; Check paddle collision
    cmp al, 23              ; Paddle Y position
    jne .cb                 ; Ball not at paddle height
    
    ; Check if ball X is within paddle range
    mov al, [ball_x]
    mov bl, [paddle_x]
    cmp al, bl              ; Ball left of paddle?
    jl .cb                  ; Yes, no collision
    
    add bl, 10              ; paddle_x + paddle_width
    cmp al, bl              ; Ball right of paddle?
    jge .cb                 ; Yes, no collision
    
    ; Ball hit paddle!
    mov byte [ball_dy], -1  ; Bounce up
    inc word [score]        ; Increment score
    call draw_score         ; Update score display
    
.cb:
    ; Check bottom (game over condition)
    mov al, [ball_y]
    cmp al, 24              ; Bottom of screen
    jne .done
    call game_over          ; Ball hit bottom, game over
    
.done:
    ret

draw_paddle:
    pusha                   ; Save all registers
    
    ; Set cursor position for paddle
    mov ah, 0x02            ; Set cursor position
    xor bh, bh              ; Page 0
    mov dh, 23              ; Y position (near bottom)
    mov dl, [paddle_x]      ; X position
    int 0x10
    
    ; Draw paddle as solid blocks
    mov ah, 0x09            ; Write character with attribute
    mov al, 0xDB            ; Block character █
    mov bl, 0x0F            ; White on black
    mov cx, 10              ; Width of paddle
    int 0x10
    
    popa                    ; Restore all registers
    ret

erase_paddle:
    pusha                   ; Save all registers
    
    ; Set cursor position for paddle
    mov ah, 0x02            ; Set cursor position
    xor bh, bh              ; Page 0
    mov dh, 23              ; Y position
    mov dl, [paddle_x]      ; X position
    int 0x10
    
    ; Erase paddle with spaces
    mov ah, 0x09            ; Write character with attribute
    mov al, ' '             ; Space character
    xor bl, bl              ; Black on black
    mov cx, 10              ; Width of paddle
    int 0x10
    
    popa                    ; Restore all registers
    ret

draw_ball:
    pusha                   ; Save all registers
    
    ; Set cursor position for ball
    mov ah, 0x02            ; Set cursor position
    xor bh, bh              ; Page 0
    mov dh, [ball_y]        ; Y position
    mov dl, [ball_x]        ; X position
    int 0x10
    
    ; Draw ball
    mov ah, 0x0A            ; Write character only
    mov al, 'O'             ; Ball character
    mov cx, 1               ; Write 1 character
    int 0x10
    
    popa                    ; Restore all registers
    ret

erase_ball:
    pusha                   ; Save all registers
    
    ; Set cursor position for ball
    mov ah, 0x02            ; Set cursor position
    xor bh, bh              ; Page 0
    mov dh, [ball_y]        ; Y position
    mov dl, [ball_x]        ; X position
    int 0x10
    
    ; Erase ball with space
    mov ah, 0x0A            ; Write character only
    mov al, ' '             ; Space character
    mov cx, 1               ; Write 1 character
    int 0x10
    
    popa                    ; Restore all registers
    ret

draw_score:
    pusha                   ; Save all registers
    
    ; Set cursor position at top left
    mov ah, 0x02            ; Set cursor position
    xor bh, bh              ; Page 0
    xor dh, dh              ; Y = 0 (top)
    mov dl, 2               ; X = 2 (left side)
    int 0x10
    
    ; Print "Score:" text
    mov si, msg             ; Point to message
.l1:
    lodsb                   ; Load byte from SI into AL
    test al, al             ; Check if null terminator
    jz .num                 ; If zero, start printing number
    mov ah, 0x0E            ; Teletype output
    int 0x10                ; Print character
    jmp .l1                 ; Next character
    
.num:
    ; Convert score to decimal digits
    mov ax, [score]         ; Load score value
    xor cx, cx              ; Digit counter = 0
    mov bx, 10              ; Divisor = 10
.c:
    xor dx, dx              ; Clear DX for division
    div bx                  ; Divide AX by 10
    push dx                 ; Save remainder (digit)
    inc cx                  ; Increment digit counter
    test ax, ax             ; Check if quotient is 0
    jnz .c                  ; Continue if not zero
    
.p:
    ; Print digits (in reverse order from stack)
    pop dx                  ; Get digit from stack
    add dl, '0'             ; Convert to ASCII
    mov ah, 0x0E            ; Teletype output
    mov al, dl
    int 0x10                ; Print digit
    loop .p                 ; Continue for all digits
    
    popa                    ; Restore all registers
    ret

game_over:
    ; Clear screen
    mov ax, 0x0003          ; Video mode 3
    int 0x10
    
    ; Position cursor in center
    mov ah, 0x02            ; Set cursor position
    xor bh, bh              ; Page 0
    mov dh, 12              ; Y = 12 (middle)
    mov dl, 32              ; X = 32 (centered)
    int 0x10
    
    ; Print "GAME OVER! Score:" message
    mov si, msg2            ; Point to game over message
.l:
    lodsb                   ; Load character
    test al, al             ; Check if null terminator
    jz .num                 ; If zero, print score
    mov ah, 0x0E            ; Teletype output
    int 0x10                ; Print character
    jmp .l                  ; Next character
    
.num:
    ; Convert and print final score
    mov ax, [score]         ; Load score
    xor cx, cx              ; Digit counter
    mov bx, 10              ; Divisor
.c:
    xor dx, dx              ; Clear DX
    div bx                  ; Divide by 10
    push dx                 ; Save digit
    inc cx                  ; Count digit
    test ax, ax             ; Check if done
    jnz .c                  ; Continue if not
    
.p:
    pop dx                  ; Get digit
    add dl, '0'             ; Convert to ASCII
    mov ah, 0x0E            ; Teletype output
    mov al, dl
    int 0x10                ; Print digit
    loop .p                 ; Print all digits
    
.w:
    xor ah, ah              ; Wait for keypress
    int 0x16
    jmp end_program

end_program:
    ; Restore cursor visibility
    mov ah, 0x01            ; Set cursor shape
    mov cx, 0x0607          ; Normal cursor
    int 0x10
    
    ; Clear screen
    mov ax, 0x0003          ; Video mode 3
    int 0x10
    
    ; Halt system
    cli                     ; Clear interrupts
    hlt                     ; Halt processor

; Game data variables
paddle_x: db 35             ; Paddle X position
ball_x: db 40               ; Ball X position
ball_y: db 12               ; Ball Y position
ball_dx: db 1               ; Ball X velocity
ball_dy: db 1               ; Ball Y velocity
frame_counter: db 0         ; Frame counter for ball speed
score: dw 0                 ; Score (16-bit)
msg: db 'Score:', 0         ; Score display text
msg2: db 'GAME OVER! Score:', 0  ; Game over text

; Boot sector signature (must be at byte 510-511)
times 510-($-$$) db 0       ; Pad with zeros
dw 0xAA55                   ; Boot signature
