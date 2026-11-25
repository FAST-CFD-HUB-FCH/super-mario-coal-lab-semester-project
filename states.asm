; State handlers are dispatched through state_handlers in data.asm.

; NewGame(): reset persistent counters, then the complete level.
NewGame:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    call AudioStopAll
    mov word [score_low], 0
    mov word [score_high], 0
    mov word [coin_count], 0
    mov word [lives], 3
    mov word [win_time], 0
    mov word [time_bonus], 0
    call ResetLevel
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; StateTitle(): rising-edge menu navigation; Enter starts/exits, Esc exits.
StateTitle:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cmp byte [key_pressed+KEY_ESC], 0
    jne .exit
    cmp byte [key_pressed+KEY_UP], 0
    jne .toggle
    cmp byte [key_pressed+KEY_DOWN], 0
    je .enter
.toggle:
    xor word [menu_selection], 1
    push ax                         ; save argument scratch register
    mov ax, SFX_MENU
    push ax
    call PlaySound
    pop ax
.enter:
    cmp byte [key_pressed+KEY_ENTER], 0
    je .done
    cmp word [menu_selection], 0
    jne .exit
    call NewGame
    mov word [game_state], ST_PLAY
    push ax                         ; save argument scratch register
    mov ax, SFX_START
    push ax
    call PlaySound
    pop ax
    jmp .done
.exit:
    mov word [game_state], ST_EXIT
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; StatePlay(): required simulation ordering; early state changes freeze updates.
StatePlay:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cmp byte [key_pressed+KEY_ESC], 0
    jne .title
    cmp byte [key_pressed+KEY_P], 0
    jne .pause
    call DebugKeys
    cmp word [game_state], ST_PLAY
    jne .done
    call UpdatePlayer
    call UpdateActors
    call UpdateEffects
    call ResolveEntities
    cmp word [game_state], ST_PLAY
    jne .done
    call CountClock
    cmp word [player+A_Y], 192
    jge .pit
    cmp word [level_time], 0
    je .time
    call CollectMapItems
    call UpdateCamera
    jmp .done
.pit:
    push ax                         ; save argument scratch register
    mov ax, 1
    push ax
    call BeginDeath
    pop ax
    jmp .done
.time:
    push ax                         ; save argument scratch register
    mov ax, 0
    push ax
    call BeginDeath
    pop ax
    jmp .done
.title:
    call AudioStopAll
    mov word [game_state], ST_TITLE
    jmp .done
.pause:
    mov word [game_state], ST_PAUSE
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; StatePause(): simulation, game clock and camera stay frozen.
StatePause:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cmp byte [key_pressed+KEY_ESC], 0
    jne .title
    cmp byte [key_pressed+KEY_P], 0
    je .done
    mov word [game_state], ST_PLAY
    jmp .done
.title:
    call AudioStopAll
    mov word [game_state], ST_TITLE
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; StateDying(): collision-free hop/fall; life is deducted once after ~1.5s.
StateDying:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    inc word [state_frames]
    add word [player+A_VY], GRAVITY
    push ax                         ; save argument scratch register
    push word [player+A_VY]
    mov ax, player+A_Y
    push ax
    call Integrate
    pop ax
    cmp word [state_frames], DEATH_FRAMES
    jb .done
    dec word [lives]
    mov word [state_frames], 0
    mov word [game_state], ST_LIFE
    cmp word [lives], 0
    jne .done
    mov word [game_state], ST_OVER
    push ax                         ; save argument scratch register
    mov ax, SFX_OVER
    push ax
    call PlaySound
    pop ax
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; StateLife(): show lives for ~2s then reset world, preserving score and coins.
StateLife:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    inc word [state_frames]
    cmp word [state_frames], TWO_SECONDS
    jb .done
    call ResetLevel
    mov word [game_state], ST_PLAY
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; StateWin(): ~1s pole slide, ~1s walk, one-time time bonus on completion.
StateWin:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    inc word [state_frames]
    cmp word [state_frames], FPS_SECOND
    ja .walk
    call PlayerHeight
    add ax, [player+A_Y]
    cmp ax, 144
    jge .done
    add word [player+A_Y], 8
    add ax, 8
    cmp ax, 144
    jle .done
    call PlayerHeight
    mov dx, 144
    sub dx, ax
    mov [player+A_Y], dx
    jmp .done
.walk:
    add word [player+A_X], 2
    cmp word [state_frames], TWO_SECONDS
    jb .done
    mov ax, [win_time]
    mov bx, 50
    mul bx
    mov [time_bonus], ax
    push ax
    call AddScore
    mov word [game_state], ST_COMPLETE
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; StateComplete(): Enter returns to title; next start runs NewGame.
StateComplete:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cmp byte [key_pressed+KEY_ENTER], 0
    je .done
    call AudioStopAll
    mov word [game_state], ST_TITLE
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; StateOver(): same title transition, retaining final score for its display.
StateOver:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cmp byte [key_pressed+KEY_ENTER], 0
    je .done
    call AudioStopAll
    mov word [game_state], ST_TITLE
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; StateExit(): the main loop owns the single, shared cleanup path.
StateExit:
    ret

; DebugKeys(): documented demo shortcuts; all normal game rules still apply.
; F1: 5 seconds; F2: 99 coins; F3: mushroom effect; F4: stairs; F5: last life.
DebugKeys:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cmp byte [key_pressed+KEY_F1], 0
    je .coins
    mov word [level_time], 5
    mov word [second_low], 0
    mov word [second_high], 0
.coins:
    cmp byte [key_pressed+KEY_F2], 0
    je .grow
    mov word [coin_count], 99
.grow:
    cmp byte [key_pressed+KEY_F3], 0
    je .stairs
    ; AddScore(1000)
    push ax                         ; save argument scratch register
    mov ax, 1000
    push ax
    call AddScore
    pop ax
    push ax                         ; save argument scratch register
    mov ax, 2
    push ax
    call SetHealth
    pop ax
    push ax                         ; save argument scratch register
    mov ax, SFX_POWER
    push ax
    call PlaySound
    pop ax
.stairs:
    cmp byte [key_pressed+KEY_F4], 0
    je .last_life
    mov word [player+A_X], 816
    call PlayerHeight
    mov dx, 96
    sub dx, ax
    mov [player+A_Y], dx
    mov word [player+A_XF], 0
    mov word [player+A_YF], 0
    mov word [player+A_VX], 0
    mov word [player+A_VY], 0
    mov word [on_ground], 1
    call UpdateCamera
.last_life:
    cmp byte [key_pressed+KEY_F5], 0
    je .done
    mov word [lives], 1
    push ax                         ; save argument scratch register
    mov ax, 0
    push ax
    call BeginDeath
    pop ax
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
