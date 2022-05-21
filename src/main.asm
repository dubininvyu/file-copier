.386

BR_CLUSTER_SIZE                             EQU 0Dh                     ; cluster syze (1 byte)
BR_RESERVED_SECTORS                         EQU 0Eh                     ; numbe of sectors up to the FAT-table (2 bytes)
BR_ROOT_CATALOG_SIZE                        EQU 11h                     ; root size in records (2 bytes)
BR_FAT_SIZE                                 EQU 16h                     ; FAT sizes (2 bytes)

BR_FILE_SYSTEM                              EQU 36h                     ; file system (8 bytes, 'FAT16   ')

SR_ATTRIBUTE                                EQU 0Bh                     ; offset from the beginning of a standard record to the attribute byte 
SR_CLUSTER_BEGIN                            EQU 1Ah                     ; offset from the beginning of a standard record to the cluster begin

; ========== data segment
dseg segment use16
    sector1                                 db  512 dup (0)             ; for placing a sector
    sector2                                 db  512 dup (0)             ; for placing a sector
    sector3                                 db  512 dup (0)             ; for placing a sector  
   
    ; input areas
    msg_inp_path                            db  80, 81 dup (0)          ; input area for sourse file
    msg_inp_copy_path                       db  80, 81 dup (0)          ; input area for target file

    ; datas
    names_array                             db  7 dup (11 dup (' '))    ; array of names with the file path
    names_array_copy                        db  7 dup (11 dup (' '))    ; array of names with the directory path

    file_dirs                               db  0                       ; number of dirs in the file path
    file_cluster_begin                      dw  0                       ; number of the beginning the file cluster
    file_cluster_size                       dw  0                       ; file size in clusters
   
    copy_dirs                               db  0                       ; number of dirs in the copy file path
    copy_cluster_begin                      dw  0                       ; beginning sector number
    copy_cluster_size                       dw  0                       ; file copy size in clusters  
 
    ; saved records
    record_file                             db  32 dup (0)              ; 32-byte record
    
    ; others
    last_dscrpt                             dw  0                       ; for storing temp variables
    counter1                                dw  0                       ; for storing a counter
    temp_sec_num                            dd  0                       ; for storing temp data
    
    next_cluster1                           dw  0                       ; for storing the number of the next cluster
    next_cluster2                           dw  0                       ; for storing the number of the next cluster
    
    next_sector1                            dd  0                       ; for storing the number of the next sector
    next_sector2                            dd  0                       ; for storing the number of the next sector
   
    ; system structures
    ld_number                               db  0                       ; logical disk number (for procedures 25h, 26h)
    cluster_size                            db  0                       ; cluster size
    root_begin                              dd  0                       ; number of the first sector of the root
    root_size                               dw  0                       ; the root size in sectors
    fat1_begin                              dd  0                       ; number of the beginning sector of the first FAT
    fat2_begin                              dd  0                       ; number of the beginning sector of the second FAT
    fat_size                                dw  0                       ; FAT size in sectors
    sec1_begin                              dd  0                       ; number of the sector with the beginning of the cluster area
    s_reserved_sectors                      dw  0                       ; number of reserved sectors
    
    ; packet of params for the find_record procedure
    packet_proc                             dw  ld_number               ; address of the logical disk number
                                            dw  cluster_size            ; address of the cluster size
                                            dw  root_begin              ; address of the sector number with the beginning of the root
                                            dw  root_size               ; address of the root size in sectors
                                            dw  sec1_begin              ; address of the sector number with the beginning of the cluster area
    pp_dir_count                            dw  file_dirs               ; address of the number of dirs in the path to the object
    pp_names_array                          dw  names_array             ; address of the array of names
    
    ; packet of params for the int 25h, int 26h
    packet_int                              dd  0                       ; sector number for reading
                                            dw  1                       ; number of sectors
    pi_sector                               dw  sector1                 ; address for reading/writing (from/to)
    pi_pointer                              dw  dseg                    ; point to the segment
    
    ; constants
    file_system                             db  'FAT16'                 ; in which file system it can work
    
    ; messages
    msg_success                             db  0Dh, 0Ah, 'A copy of the file was created$'

    msg_ent_path                            db  0Dh, 0Ah, 'Please, enter the path: $'
    
    msg_err_path                            db  0Dh, 0Ah, 'The path to your file is wrong$'
    msg_err_copy_path                       db  0Dh, 0Ah, 'The path to your directory is wrong$'
    msg_err_too_much_dirs                   db  0Dh, 0Ah, 'Your path consists too much directories$'
    msg_err_sector_reading                  db  0Dh, 0Ah, 'Invalid sector reading...$'
    msg_err_sector_writing                  db  0Dh, 0Ah, 'Invalid sector writing...$'
    msg_err_file_system                     db  0Dh, 0Ah, 'This logical disk is not FAT16$'
    msg_err_no_space                        db  0Dh, 0Ah, 'There is no so much space in your logical disk$'
    msg_err_diff_ld                         db  0Dh, 0Ah, 'Both paths have different logical disks$'
    msg_err_unexpected                      db  0Dh, 0Ah, 'An unknown error occurred...$'
    msg_err_file_exists                     db  0Dh, 0Ah, 'Selected file already exists in this directory$'
dseg ends

; ========== macros
print_msg MACRO message	; print message
	mov AH, 9h
	lea DX, message
	int 21h
endm

enter_msg MACRO area                                                    ; enter message
    mov AH, 0Ah
	lea DX, area
	int 21h
endm

throw_c MACRO message	                                                ; throw if CF = 1
	lea DX, message
	jc cs_end
endm

throw_z MACRO message	                                                ; throw if CF = 1
	lea DX, message
	jz cs_end
endm

throw_g MACRO message                                                   ; throw if greater
    lea DX, message
    jg cs_end
endm

throw_ne MACRO message                                                  ; throw if not equals
    lea DX, message
    jne cs_end
endm

read_sector MACRO ld_number, packet, message
    mov AL, ld_number
    mov CX, 0FFFFh
    lea BX, packet
    int 25h
    
    pop CX
    
    throw_c message
endm

write_sector MACRO ld_number, packet, message
    mov AL, ld_number
    mov CX, 0FFFFh
    lea BX, packet
    int 26h
    
    pop CX
    
    throw_c message
endm

; ========== code segment
cseg segment use16
assume  cs:cseg, ds:dseg
start:
    mov AX, dseg
	mov DS, AX

; ========== entering the file path
    print_msg msg_ent_path                                              ; user enters the path
    enter_msg msg_inp_path
    
; ========== converting a disk letter to a digit
    mov AL, DS:[msg_inp_path+2]
    mov DS:ld_number, AL
    
    lea SI, ld_number
    call far ptr get_ld_number
    
    throw_c DS:msg_err_path                                             ; throw if the letter is wrong

; ========== creating names array
    clc                                                                 ; check a dot existing
    lea SI, msg_inp_path                                                ; pushing the input area address
    lea BP, names_array                                                 ; pushing the names array
    call far ptr gen_names_array                                        ; converting a path to a names array
    
    throw_c DS:msg_err_path                                             ; throw if anything wrong
    
; ========== checking a number of catalogs and saving the number
    mov DS:file_dirs, BL                                                ; saving the number of catalogs

    cmp DS:file_dirs, byte ptr 5h
    throw_g DS:msg_err_too_much_dirs                                    ; throw if number of catalogs is greater than 5

; ========== getting info about logical disk
    mov DS:packet_int, dword ptr 0                                      ; reading a boot sector of logical disk
    lea SI, sector1
    mov DS:pi_sector, SI                                                ; reading sector1 into the pi_sector area
    read_sector DS:ld_number, packet_int, DS:msg_err_path

    ; checking the file system
    lea SI, file_system                                                 ; pushing the correct file system
    lea DI, [sector1+BR_FILE_SYSTEM]                                    ; pushing the file system of this disk
    
    mov AX, DS                                                          ; ES = DS
    mov ES, AX
    
    cld                                                                 ; DF = 0
    
    mov CX, 5
    rep cmpsb
    throw_ne DS:msg_err_file_system                                     ; throw if these file systems aren't the same
    
    ; pop the cluster size
    mov AL, byte ptr DS:[sector1+BR_CLUSTER_SIZE]
    mov DS:cluster_size, AL

    ; pop the number of reserved sectors
    mov AX, word ptr DS:[sector1+BR_RESERVED_SECTORS]
    mov DS:s_reserved_sectors, AX
    
    ; pop the root catalog size
    mov AX, word ptr DS:[sector1+BR_ROOT_CATALOG_SIZE]
    shr AX, 4
    mov DS:root_size, AX
    
    ; pop the AT-table size
    mov AX, word ptr DS:[sector1+BR_FAT_SIZE]
    mov DS:fat_size, AX

; ========== calculating of system data
    
    ; a sector of the first FAT-table number
    movzx EAX, word ptr DS:s_reserved_sectors   
    mov DS:fat1_begin, EAX                                              ; fat1 = reserved_sectors    
    
    ; a sector of the second FAT-table number
    movzx EAX, word ptr DS:fat_size           
    add EAX, DS:fat1_begin
    mov DS:fat2_begin, EAX                                              ; fat2 = fat1 + fat_size        
    
    ; the first sector of the root catalog number
    movzx EAX, word ptr DS:fat_size           
    shl EAX, 1                                  
    add EAX, DS:fat1_begin                          
    mov DS:root_begin, EAX                                              ; root = fat1 + 2*fat_size
    
    ; the first sector of the first cluster number                
    movzx EAX, DS:root_size
    add EAX, DS:root_begin
    mov DS:sec1_begin, EAX                                              ; sec1 = root + root_size/16

; ========== looking for a sector with the record about the last item of names array
    lea SI, file_dirs
    mov pp_dir_count, SI                                                ; pushing the number of dirs address
    lea SI, names_array             
    mov pp_names_array, SI                                              ; pushing the names array address

    stc
    lea SI, packet_proc
    call far ptr find_record
    
    jc cs_end                                                           ; throw if anything wrong
    
; ========== saving the standard record about the file
    mov SI, BP                                                          ; pushing a source adress (SI)
    lea DI, record_file                                                 ; pushing a destination address (DI)
            
    mov AX, DS
    mov ES, AX                                                          ; ES = DS
    
    cld                                                                 ; clear a direct flag (for incrementing)
    mov CX, 8                                                           ; number of repeats (32/4 = 8)
    rep movsd                                                           ; saving the standard record

; ========== saving data from the standard record

    ; the beginning cluster of the file number
    mov AX, word ptr DS:[record_file + SR_CLUSTER_BEGIN]
    mov DS:file_cluster_begin, AX

; ========== counting the number of the file clusters
    mov AX, word ptr DS:[file_cluster_begin]                            ; beginning file descriptor
    mov DS:last_dscrpt, AX

cs_cycle1:
    ; which sector of the FAT-table this cluster is in?
    mov EAX, dword ptr DS:fat1_begin                                    ; beginning FAT-table sector number
    add AL, byte ptr DS:[last_dscrpt+1]                                 ; offset from the beginning sector to the end

    ; reading the calculated sector
    lea SI, sector1
    mov DS:pi_sector, SI                                                ; the reading sector into address
    
    mov DS:packet_int, EAX
    read_sector DS:ld_number, packet_int, DS:msg_err_sector_reading 
    
    ; calculation the offset from the beginning cluster to the last one
    movzx BP, byte ptr DS:last_dscrpt                                   ; the lowest byte is the offset within the sector
    shl BP, 1                                                           ; cluster number * 2 = address (in the FAT-table)
    
    ; reading the descriptor with the calculated number
    mov AX, word ptr DS:[sector1+BP]
    mov DS:last_dscrpt, AX
    
    ; increasing the file size counter (in clusters)
    inc word ptr DS:file_cluster_size
    
    cmp DS:last_dscrpt, word ptr 0FFEFh                                 ; if <, then there is a continuation
    jb short cs_cycle1

; ========== looking for free clusters in the FAT-table and linking them
    mov AX, DS:fat_size
    mov DS:counter1, AX                                                 ; checking all descriptors in the FAT-table
    
    ; sector reading
    lea SI, sector1
    mov DS:pi_sector, SI                                                ; address for reading the sector
    
    mov EAX, DS:fat1_begin                                              ; the initial sector of the FAT table
    mov DS:packet_int, EAX                                              ; pushing the sector number for reading
   
    ; getting sectors number for linking
    mov AX, DS:file_cluster_size
    mov DS:copy_cluster_size, AX
    
    mov DS:last_dscrpt, word ptr 0                                      ; clear temporary cell
    
cs_cycle2:
    read_sector DS:ld_number, packet_int, DS:msg_err_sector_reading 
    
    ; preparing parameters for the cycle
    mov CX, 256                                                         ; number of descriptors in each sector
    lea SI, sector1                                                     ; address of the beginning of the read sector
    
cs_cycle2_int:   
    cmp DS:SI, word ptr 0h
    jne cs_cycle2_int_continue                                          ; this is not an empty descriptor, so looking further
    
    ; determining the number of the current descriptor
    mov AX, SI
    shr AX, 1                                                           ; cuz SI is 2 doubled
        
    ; save the number of the initial cluster?
    cmp DS:copy_cluster_begin, word ptr 0
    jne short cs_cycle2_continue
    
    ; saving  the number of the initial cluster
    mov DS:copy_cluster_begin, AX
    
cs_cycle2_continue:    

    ; in the previous descriptor, save the number of the current one
    cmp DS:last_dscrpt, word ptr 0                                      ; is it not last iteration?
    je short cs_cycle2_continue2                                        ; it's not last one => continuing
    
    mov BP, DS:last_dscrpt
    shl BP, 1                                                           ; cuz BP is doubled
    mov DS:[BP], AX
    
cs_cycle2_continue2:
    ; saving the number of the currect descriptor  
    mov DS:last_dscrpt, AX
    
    ; stop or continue?
    dec byte ptr DS:copy_cluster_size
    jz cs_cycle2_end                                                    ; it was the last descriptor
        
cs_cycle2_int_continue:
    inc SI
    inc SI                                                              ; go to the next descriptor
    loop cs_cycle2_int                                                  ; go the the cycle begining
   
cs_cycle2_int_ws:
    ; saveing the sector into storage
    mov EAX, DS:packet_int
    mov DS:packet_int, EAX                                              ; writing the sector with the number that already was there
    
    lea SI, sector1
    mov DS:pi_sector, SI                                                ; writing destination address
    
    write_sector DS:ld_number, packet_int, DS:msg_err_sector_writing
    
    ; go to the next sector of the FAT-table
    dec DS:counter1
    throw_z DS:msg_err_no_space                                         ; there is no free space in the disk
    
    inc dword ptr DS:packet_int                                         ; the next sector for the reading
    jmp cs_cycle2                                                       ; go to the cycle beginning
    
cs_cycle2_end:
    ; it is the last one
    mov DS:[SI], word ptr 0FFFFh                                        ; break the train of clusters

    ; writing the sector
    mov EAX, DS:packet_int
    mov DS:packet_int, EAX 
    
    lea SI, sector1
    mov DS:pi_sector, SI                                                ; writing the destination address
    
    write_sector DS:ld_number, packet_int, DS:msg_err_sector_writing

; ========== enter the copying file name
    print_msg msg_ent_path_copy
    enter_msg msg_inp_copy_path

; ========== checking letter of the disk
    mov AL, DS:[msg_inp_copy_path+2]
    sub AL, 65                                                          ; converting the disk letter into a digit
    
    cmp AL, DS:ld_number
    throw_ne DS:msg_err_diff_ld

; ========== creating an array of names from a file path
    stc                                                                 ; flag for ignoring point search
    lea SI, msg_inp_copy_path                                           ; pushing the address of the input area
    lea BP, names_array_copy                                            ; pushing the address of the array of names
    call far ptr gen_names_array                                        ; converting the path to an array of names
    
    throw_c DS:msg_err_copy_path                                        ; throw if anything is wrong
    
; ========== checking the catalog number and saving the number
    mov DS:copy_dirs, BL                                                ; saving the catalog number

    cmp DS:copy_dirs, byte ptr 5h
    throw_g DS:msg_err_too_much_dirs                                    ; throw if catalog number is greater than 5
            
; ========== looking for a record about the destination directory
    lea SI, copy_dirs
    mov pp_dir_count, SI                                                ; pushing the address with the number of directories
    lea SI, names_array_copy
    mov pp_names_array, SI                                              ; pushing the address of the array of names
        
    clc
    lea SI, packet_proc
    call far ptr find_record                                            ; BP has the address of the standard record
    
    jc cs_end
    
; ========== copying of a standard entry into the receiver catalog

    ; calculation of the sector number
    movzx CX, byte ptr DS:cluster_size
    mov AX, word ptr DS:[BP + SR_CLUSTER_BEGIN]
    mov EBX, DS:sec1_begin
    call far ptr get_sector_number
    
    mov DS:temp_sec_num, EBX
    
    ; pushing the cycle counter (= cluster size)
    movzx CX, DS:cluster_size
    
cs_cycle3_ext:
    ; initializing values
    lea DI, sector2
    mov byte ptr DS:counter1, 16
    
    ; reading the sector
    mov EAX, DS:temp_sec_num
    lea SI, sector2
    mov DS:pi_sector, SI
    mov DS:packet_int, EAX                                              ; pushing the sector number for reading
    read_sector DS:ld_number, packet_int, DS:msg_err_sector_reading
     
cs_cycle3_int:    
    ; is the file name already in the receiver catalog?
    mov EAX, DS:[record_file]
    cmp EAX, DS:[DI] 
    jne short cs_cycle3_chk
    
    mov EAX, DS:[record_file+4]
    cmp EAX, DS:[DI+4]
    jne short cs_cycle3_chk
    
    mov EAX, DS:[record_file+7]
    cmp EAX, DS:[DI+7]
    jne short cs_cycle3_chk
    
    lea DX, DS:msg_err_file_exists
    jmp cs_end
    
cs_cycle3_chk:    
    cmp DS:[DI], dword ptr 0   
    jne cs_cycle3_next
    
    ; it's the empty record
    mov AX, DS
    mov ES, AX
    lea SI, DS:record_file
    
    ; copying the descriptor
    mov CX, 8
    rep movsd
    
    ; updating beginning cluster number
    sub DI, 32                                                          ; movsd killed my pointer
    
    mov AX, DS:copy_cluster_begin
    mov DS:[DI+SR_CLUSTER_BEGIN], AX
      
    jmp short cs_cycle3_end

    ; continuing the cycle
cs_cycle3_next:
    dec DS:counter1                                                     ; is it the end of records?
    jz short cs_cycle3_next_sec                                         ; go to read the next sector
    
    add DI, 32                                                          ; to to the next reacord
    jmp short cs_cycle3_int                                             ; looking for an empty record again
    
cs_cycle3_next_sec:
    inc byte ptr DS:temp_sec_num
    loop cs_cycle3_ext
    
    lea DX, DS:msg_err_unexpected
    jmp cs_end
    
cs_cycle3_end:
; ========== writing an updated sector
    mov EAX, DS:temp_sec_num
    mov DS:packet_int, EAX                                              ; pushing the sector number
    
    lea SI, sector2
    mov DS:pi_sector, SI                                                ; pushing the destination address
    
    write_sector DS:ld_number, packet_int, DS:msg_err_sector_writing
    
; ========== copying sectors of the second file (file copy)
    
    ; pushing the source data
    mov AX, DS:file_cluster_begin   
    mov DS:next_cluster1, AX
    
    cmp AX, 0                                                           ; does the file include any sectors?
    je cs_cycle4_end                                                    ; there is no sense in copying
    
    mov AX, DS:copy_cluster_begin
    mov DS:next_cluster2, AX
    
cs_cycle4_continue_ext:
    ; calculating the beginning file sector
    movzx CX, byte ptr DS:cluster_size
    mov AX, DS:next_cluster1
    mov EBX, DS:sec1_begin
    call far ptr get_sector_number
    mov DS:next_sector1, EBX
    
    ; calculating the new file sector
    movzx CX, byte ptr DS:cluster_size
    mov AX, DS:next_cluster2
    mov EBX, DS:sec1_begin
    call far ptr get_sector_number
    mov DS:next_sector2, EBX

    ; calculating the FAT-table sector of the next sector (for the file)
    mov EAX, DS:fat1_begin
    mov BL, byte ptr DS:[next_cluster1+1]
    movzx EBX, BL
    add EAX, EBX                                                        ; sector number of the next cluster in the FAT table

    mov DS:packet_int, EAX                                              ; writing the sector number
    lea SI, sector1   
    mov DS:pi_sector, SI                                                ; writing the address of the sector placement
    read_sector DS:ld_number, packet_int, DS:msg_err_sector_reading
    
    ; popping the cluster number of the file
    movzx SI, byte ptr DS:[next_cluster1]
    shl SI, 1                                                           ; cuz SI is reduced by 2 times 
    mov AX, DS:[SI]                                                     ; popping the value of the descriptor
    mov DS:next_cluster1, AX                                            ; rewriting the value of the descriptor
        
    ; calculating of the FAT table sector of the next copy cluster
    mov EAX, DS:fat1_begin
    mov BL, byte ptr DS:[next_cluster2+1]
    movzx EBX, BL
    add EAX, EBX                                                        ; sector number of the next cluster in the FAT table

    mov DS:packet_int, EAX                                              ; writing the sector number
    lea SI, sector2   
    mov DS:pi_sector, SI                                                ; writing the address of the sector placement
    read_sector DS:ld_number, packet_int, DS:msg_err_sector_reading
    
    ; popping the cluster number of the file copy
    movzx SI, byte ptr DS:[next_cluster2]
    shl SI, 1                                                           ; cuz SI is reduced by 2 times 
    mov AX, DS:[SI]                                                     ; popping the value of the descriptor
    mov DS:next_cluster2, AX                                            ; rewriting the value of the descriptor
    
    ; set the counter
    movzx AX, DS:cluster_size
    mov DS:counter1, AX
    
cs_cycle4_continue:

    ; reading the sector
    mov EAX, DS:next_sector1
    mov DS:packet_int, EAX                                              ; writing the sector number
      
    lea SI, sector3  
    mov DS:pi_sector, SI                                                ; writing the address of the sector placement    
    
    read_sector DS:ld_number, packet_int, DS:msg_err_sector_writing 

    ; writing the dector
    mov EAX, DS:next_sector2
    mov DS:packet_int, EAX                                              ; writing the sector number
    
    lea SI, sector3
    mov DS:pi_sector, SI                                                ; writing the address of the sector placement
    
    write_sector DS:ld_number, packet_int, DS:msg_err_sector_writing

    ; decrementing the counter and going to the next sector
    inc byte ptr DS:next_sector1
    inc byte ptr DS:next_sector2
    
    dec DS:counter1
    jz cs_cycle4_continue_ext
    
    cmp DS:next_cluster1, word ptr 0FFEFh                               ; is it the last cluster?
    jae short cs_cycle4_end                                             ; if it is, leave
    
    jmp short cs_cycle4_continue
    
cs_cycle4_end:

; ========== creating a copy of the FAT table
    mov AX, DS:fat_size
    mov DS:counter1, AX
    
cs_cycle5:
    ; reading the sector of the first FAT-table
    mov EAX, DS:fat1_begin
    mov DS:packet_int, EAX                                              ; writing the sector number
      
    lea SI, sector3  
    mov DS:pi_sector, SI                                                ; writing the address of the sector placement
    
    read_sector DS:ld_number, packet_int, DS:msg_err_sector_reading
    
    ; writing the sector of the second FAT-table
    mov EAX, DS:fat2_begin
    mov DS:packet_int, EAX                                              ; writing the sector number
      
    lea SI, sector3  
    mov DS:pi_sector, SI                                                ; writing the address of the sector placement
    
    write_sector DS:ld_number, packet_int, DS:msg_err_sector_writing
    
    ; decrementing the counter
    dec word ptr DS:counter1
    jz short cs_cycle5_end
    
    inc dword ptr DS:fat1_begin
    inc dword ptr DS:fat2_begin
    
    jmp short cs_cycle5
    
cs_cycle5_end:
    
; ========== print results
	lea DX, msg_success
	
cs_end:
	mov AH, 9h
	int 21h
	
; ========== end program
	mov AH, 4Ch
	int 21h

cseg ends

; ========== code segment for procedures
pseg segment use16
assume cs:pseg, ds:dseg
    proc_ld_number              db  0                                   ; the logical disk number
    proc_cluster_size           db  0                                   ; the cluster size
    proc_root_begin             dd  0                                   ; the root catalog beginning
    proc_root_size              dw  0                                   ; the root catalog size
    proc_sec1_begin             dd  0                                   ; the cluster area beginning
    proc_dir_count              db  0                                   ; the number of catalogs in the names array
    proc_names_array            dw  0                                   ; the names array address
    
    proc_next_sector            dd  0                                   ; sector number for reading
    proc_counter1               db  0                                   ; counter (for cycles) (1)
    
    proc_sign                   db  0                                   ; looking for the file = 1, otherwise = 0
    proc_sign2                  db  0                                   ; looking for the dot (= 1 - ignore)
    
; ========== procedure for getting an LD number and checking it
; ** вх: SI (the logical disk letter address)
; ** вых: SI (the logical disk number), CF (1 - error flag)
    get_ld_number proc far
    
    sub DS:SI, byte ptr 65
    
    cmp DS:SI, byte ptr 0h                                              ; DS:SI < 0 ?
    jl short gln_error                                                  ; => error
    
    cmp DS:SI, byte ptr 25                                              ; DS:SI > 25 ?
    jg short gln_error                                                  ; => error    
    
    clc
    jmp short gln_end
gln_error:
    stc
gln_end:
    ret
    get_ld_number endp

; ========== procedure for calculating sector number
; ** вх: EBX (the first sector number of clusters area), CL (cluster size), AX (cluster number)
; ** вых: EBX (sector number)
    get_sector_number proc far

    dec AX
    dec AX                                                              ; divide sector number in 2 times
    
    mul CX                                                              ; multiply by the cluster size
        
    movzx EAX, AX
    add EBX, EAX                                                        ; result (the cluster number)
    
    ret
    get_sector_number endp

; ========== procedure for looking for a record about the last object in names array
; ** вх: SI (the procedure packet address), CF (= 1 if looking for a file or 0 for looking for a catalog)
; ** вых: CF (1 - error flag), BP (address of the standard record about the object)
    find_record proc far
    
    jnc short fr_continue3                                              ; go to look for the record about a catalog 
    mov CS:proc_sign, 1                                                 ; set a flag for looking for a file
    jmp short fr_continue4
    
fr_continue3:
    mov CS:С, 0                                                         ; clear a flag for looking for a catalog
    
fr_continue4:
    ; logical disk number (1 byte)
    mov DI, DS:SI                                                       ; popping an address with the logical disk number
    mov AL, DS:DI                                                       ; popping logical disk number by the address
    mov CS:proc_ld_number, AL                                           ; copying it into the storage
    inc SI
    inc SI                                                              ; go to the next address
    
    ; cluster size (1 byte)
    mov DI, DS:SI                                                       ; popping an address with the cluster size
    mov AL, DS:DI                                                       ; popping the cluster size by the address
    mov CS:proc_cluster_size, AL                                        ; copying it into the storage
    inc SI            
    inc SI                                                              ; go to the next address
    
    ; root catalog beginning (2 bytes)
    mov DI, DS:SI                                                       ; popping an address with the root catalog beginning
    mov EAX, DS:DI                                                      ; poppint the root catalog beginning by the address
    mov CS:proc_root_begin, EAX                                         ; copying it into the storage
    inc SI
    inc SI                                                              ; go to the next address
    
    ; root catalog size (2 bytes)
    mov DI, DS:SI                                                       ; popping an address with the root size
    mov AX, DS:DI                                                       ; popping the root size by the address
    mov CS:proc_root_size, AX                                           ; copying it into the storage
    inc SI
    inc SI                                                              ; go to the next address
    
    ; cluster area beginning (4 bytes)
    mov DI, DS:SI                                                       ; popping an address with the first cluster number
    mov EAX, DS:DI                                                      ; poppint the first cluster number by the address
    mov CS:proc_sec1_begin, EAX                                         ; copying it into the storage
    inc SI
    inc SI                                                              ; go to the next address
    
    ; number of dirs in the names array (1 byte)
    mov DI, DS:SI                                                       ; popping an adress with the number of directories
    mov AL, DS:DI                                                       ; popping the number of directories by the address
    add CS:proc_dir_count, AL                                           ; copying it into the storage
    inc SI
    inc SI                                                              ; go to the next address
    
    ; names array address (2 bytes)
    mov DI, DS:SI                                                       ; popping the names array address
    mov CS:proc_names_array, DI                                         ; copying it into the storage
    inc SI
    inc SI                                                              ; go to the next address
      
    ; saving the names array address
    mov SI, CS:proc_names_array
    
; ========== looking for the record in the root catalog 
    
fr_cyc1_ext_start:
    ; pushing the sector number of the root directory in the package
    mov EAX, CS:proc_root_begin
    mov DS:packet_int, EAX
    
    ; reading the current sector of the root directory
    mov AL, CS:proc_ld_number
    mov CX, 0FFFFh
    lea BX, DS:packet_int
    int 25h

    pop CX
    
    jnc short fr_continue1                                              ; there is no any errors, so continuing
    
    lea DX, DS:msg_err_sector_reading
    jmp fr_error

fr_continue1:
    ; enumarating all records and searching for the substring
    mov CX, 16                                                          ; number of records in the sector
    lea BP, sector1                                                     ; address in the read sector
    
fr_cyc1_int_start:
    ; comparing these names
    mov EAX, DS:SI
    mov EBX, DS:BP
    
    cmp EBX, 0                                                          ; is it empty string?
    lea DX, DS:msg_err_path                                             ; pushing an error message
    je fr_error                                                         ; leaving the procedure
    
    cmp EAX, EBX
    jne short fr_cyc1_ne                                                ; they don't equal
    
    mov EAX, DS:[SI+4]
    mov EBX, DS:[BP+4]
    cmp EAX, EBX
    jne short fr_cyc1_ne                                                ; the don't equal
    
    mov EAX, DS:[SI+7]
    mov EBX, DS:[BP+7]      
    cmp EAX, EBX
    jne short fr_cyc1_ne                                                ; they don't equal
    
    ; these string equal, but is it a catalog?
    cmp CS:proc_dir_count, byte ptr 0                                   ; is there any catalogs?
    jne short fr_cyc1_cat                                               ; yes, there is => checking if this is a catalog

    cmp CS:proc_sign, byte ptr 0                                        ; does it must be catalog?
    je short fr_cyc1_cat                                                ; checking if this is a catalog
    
    movzx AX, byte ptr DS:[BP+SR_ATTRIBUTE]                             ; copying the bit in the register
    BT AX, 4                                                            ; select a bit 'Dir' from the attributes byte
    jc short fr_cyc1_ne                                                 ; it's not a file, but we are looking for a file
    
    jmp fr_success                                                      ; wow, it's a file! And it's the end cuz it's root catalog

fr_cyc1_cat:
    movzx AX, byte ptr DS:[BP+SR_ATTRIBUTE]                             ; copying the bit in the register
    BT AX, 4                                                            ; select a bit 'Dir' from the attributes byte
    jnc short fr_cyc1_ne                                                ; it's not a catalog, but we are looking for a catalog

    ; creating the next sector number for reading
    movzx EAX, word ptr DS:[BP+SR_CLUSTER_BEGIN]                        ; popping the sector number
    dec AX
    dec AX                                                              ; reducing the cluster number by 2
    
    movzx EDX, CS:proc_cluster_size                                     ; popping the cluster size  
    mul EDX                                                             ; multiply the cluster number by its size
    
    add EAX, CS:proc_sec1_begin                                         ; adding the first sector number
    mov CS:proc_next_sector, EAX                                        ; pushing the next sector number for reading

    ; looking for the catalog in catalog (using clusters)
    jmp short fr_find_clusters
    
fr_cyc1_ne:  ; these string don't equal
    dec CX
    jz short fr_cyc1_ne_next_sector                                     ; there is no searched dir/file in this sector => go to the next one
    
    add BP, 32                                                          ; go to the next record
    jmp fr_cyc1_int_start                                               ; go to the beginning of internal cycle
    
fr_cyc1_ne_next_sector:
    dec CS:proc_root_size                                               ; decrementing the count of unread sectors
    jz fr_error                                                         ; there is no any unread sectors => throw
    
    inc CS:proc_root_begin                                              ; go to the next sector for reading
    jmp fr_cyc1_ext_start                                               ; go to the beginning of external cycle

; ========== looking for in clusters area
fr_find_clusters:

fr_cyc2_ext1_start:
    ; checking, is there any unread directories
    dec CS:proc_dir_count                                               ; decrementing the count of unread directories
    cmp DS:proc_dir_count, 0                                            ; the count of directors is < 0 => it's the end
    jl fr_success                                                       ; success, every directory is founded

    ; go to the next name in the names array
    add SI, 11
    
    ; pushing the number of sectors in a cluster
    mov AL, CS:proc_cluster_size
    mov CS:proc_counter1, AL                                            ; checking all sectors in the cluster
    
fr_cyc2_ext2_start:
    ; pushing the sector number into the packet
    mov EAX, CS:proc_next_sector
    mov DS:packet_int, EAX
    
    ; current sector reading
    mov AL, CS:proc_ld_number
    mov CX, 0FFFFh
    lea BX, DS:packet_int
    int 25h

    pop CX
    
    jnc short fr_continue2                                              ; there is no errors, continuing
    
    lea DX, DS:msg_err_sector_reading
    jmp fr_error
    
fr_continue2:
    ; checking records and searching for my substring
    mov CX, 16                                                          ; number of records in the sector
    lea BP, sector1                                                     ; the address in the read sector
    
fr_cyc2_int_start:
    ; comparing these strings
    mov EAX, DS:SI
    mov EBX, DS:BP
    
    cmp EBX, 0                                                          ; is it empty record?
    lea DX, DS:msg_err_path                                             ; push an error message
    je fr_error                                                         ; throw
    
    cmp EAX, EBX
    jne short fr_cyc2_ne                                                ; they don't equal, leave
    
    mov EAX, DS:[SI+4]
    mov EBX, DS:[BP+4]
    cmp EAX, EBX
    jne short fr_cyc2_ne                                                ; they don't equal, leave
    
    mov EAX, DS:[SI+7]
    mov EBX, DS:[BP+7]
    cmp EAX, EBX    
    jne short fr_cyc2_ne                                                ; they don't equal, leave
    
    ; they equal, but is it a catalog?
    cmp CS:proc_dir_count, byte ptr 0                                   ; is there any catalog?
    jg fr_cyc2_cat                                                      ; there is => checking, if it's a catalog?

    cmp CS:proc_sign, byte ptr 0                                        ; is it must be a catalog?
    je short fr_cyc2_cat                                                ; go to check, if it's a catalog

    movzx AX, byte ptr DS:[BP+SR_ATTRIBUTE]                             ; copying the bit into the register
    BT AX, 4                                                            ; select the 'Dir' bit from the attributes byte
    jc short fr_cyc2_ne                                                 ; it's not a file, but it must be a file
    
    jmp fr_success                                                      ; success, we had found a file

fr_cyc2_cat:
    movzx AX, byte ptr DS:[BP+SR_ATTRIBUTE]                             ; copying a bit to a register
    BT AX, 4                                                            ; select the 'Dir' bit from the attribute byte
    jnc short fr_cyc2_ne                                                ; it's not a catalog, we're leaving

    ; creating the number of the next sector to read
    movzx EAX, word ptr DS:[BP+SR_CLUSTER_BEGIN]                        ; popping the cluster number
    dec AX
    dec AX                                                              ; reducing the cluster number by 2
    
    movzx EBX, CS:proc_cluster_size                                     ; popping the cluster size   
    mul EBX                                                             ; multiply the cluster number by its size
    
    add EAX, CS:proc_sec1_begin                                         ; adding the first sector number
    mov CS:proc_next_sector, EAX                                        ; writing the next sector number for reading

    ; the directory is found
    jmp fr_cyc2_ext1_start
    
fr_cyc2_ne:  ; these string don't equal
    dec CX
    jz short fr_cyc2_ne_next_sector                                     ; there is no the record in this sector => go to the next one
            
    add BP, 32                                                          ; go to the next record
    jmp fr_cyc2_int_start                                               ; go to the internal cycle beginning
    
fr_cyc2_ne_next_sector:
    dec CS:proc_counter1                                                ; recuding number of unread sectors
    jz short fr_error                                                   ; there is no any unread sectors => throw
    
    inc CS:proc_next_sector                                             ; go to the next sector for reading
    jmp fr_cyc2_ext2_start                                              ; go to the external cycle beginning    

; ========== the end of the procedure
fr_error:
    stc
    jmp short fr_end
fr_success:
    clc
fr_end:
    ret
    find_record endp

; ========== procedure for creating a names array
; ** вх: SI (input area address), BP (names array address), CF (= 1 - ignore searching a dot)
; ** вых: CF (1 - error flag), BL (number of catalogs)
    gen_names_array proc far

    jnc short gna_start
    mov CS:proc_sign2, 1
    
gna_start:
    ; initializing registers
    mov DI, 0                                                           ; a letter in the name
    mov BL, 0                                                           ; number of catalogs
    
    movzx CX, byte ptr DS:[SI+1]                                        ; pushing the number of letters in the name
    add SI, 5                                                           ; escape (plan)(fact)D:/...
    sub CX, 3                                                           ; escape D:/

    ; creating a names array
gna_cycle:
    cmp DS:[SI], byte ptr '\'                                           ; == '\' ?
    jne short gna_continue                                              ; no => continuing
    
    inc BL                                                              ; incrementing the catalog counter
    add BP, 11                                                          ; go to the next line of names array
    xor DI, DI                                                          ; go back (to the beginning of the line of names array)   
    jmp short gna_cycle_end
    
gna_continue:
    mov AL, DS:[SI]                                                     ; popping a byte from the path
    mov DS:[BP+DI], AL                                                  ; pushing a byte into the names array
    inc DI                                                              ; go to the next letter in the names array

gna_cycle_end:
    inc SI
    loop short gna_cycle

    ; if ignoring a dot searching is enabled
    cmp CS:proc_sign2, 1
    je gna_success

    ; converting a file name to 8.3 format
    mov CX, DI                                                          ; counter = number of letters in the last line
    xor DI, DI                                                          ; go to the line beginning
    
gna_cycle2:
    cmp DS:[BP+DI], byte ptr '.'                                        ; == '.' ?  
    jne short gna_cycle2_end                                            ; no => continuing
    
    ; a dot have a nice place: 8.3
    cmp DI, 8
    je short gna_continue2                                              ; go to shift the follow letters
    
    ; a dot appears early
    mov DS:[BP+DI], byte ptr ' '                                        ; delete a dot
    
    mov AL, DS:[BP+DI+1]
    mov byte ptr DS:[BP+DI+1], ' '                                      ; saving one letter after a dot
    
    mov CX, DS:[BP+DI+2]
    mov word ptr DS:[BP+DI+2], '  '                                     ; saving two letters after a [dot+1]
    
    mov DS:[BP+8], AL                                                   ; inserting one letter into 8 positiong    
    mov DS:[BP+9], CX                                                   ; inserting two letters into 9-10 positions
    jmp short gna_success
    
gna_cycle2_end:
    inc DI
    loop short gna_cycle2
    jmp short gna_error   
   
    ; shifting all follow letters to the place of the dot (8.3)
gna_continue2:
    mov CX, 3                                                           ; file extension = 3 letters => shift them
gna_cycle3:
    mov AL, DS:[BP+DI+1]
    mov DS:[BP+DI], AL
    inc DI
    
    loop short gna_cycle3
    
    mov DS:[BP+DI], byte ptr ' '

    ; the end of the procedure
gna_success:  
    clc
    jmp short gna_end
gna_error:
    stc
gna_end:
    ret
    gen_names_array endp

pseg ends

end start