
	BITS 64
	%define SYS_EXIT 60
	%define BM_STACK_CAPACITY 1024
	%define BM_WORD_SIZE 8
	%define STDOUT 1
	%define SYS_EXIT 60
	%define SYS_WRITE 1
	%define PRINT_FRAC_N 10
	

	;; %include "./src/natives.asm"
	
	segment .text
	global _start

print_int:
	;; rax contains the value we need to print
	mov rdi,  0		; counter of chars
	.loop:
	xor rdx, rdx
	mov rbx, 10
	div rbx
	add rdx, '0'
	dec rsp
	inc rdi
	mov [rsp], dl
	cmp rax, 0
	jne .loop
	
	;; rsp - points at the beginning of the buffer
	;; rdi - contains the size of the buffer
	mov rbx, rdi
	;; write(STDOUT, buf, buf_size)
	mov rax, SYS_WRITE
	mov rdi, STDOUT		; stream
	mov rsi, rsp		; buffer
	mov rdx, rbx		; count
	syscall
	add rsp, rbx
	ret

	;; xmm0 - f  - fraction to print, must be < 1.0
print_frac:
	;; dot of the fraction
	mov BYTE [x], '.'
	mov rax, SYS_WRITE
	mov rdi, STDOUT
	mov rsi, x
	mov rdx, 1
	syscall

	;; Allocate Stack Variables
	%define M    0
	%define R    (M + 8)
	%define U    (R + 8)
	%define Size (U + 8)
	sub rsp, Size
	;; -----------------------------

	;; Initialize R -----------------
	movsd QWORD [rsp + R], xmm0
	;; -----------------------------
		
	;; Initialize M = b^(-n)/2 -----------------
	movsd xmm0, QWORD [one]
	mov rax, PRINT_FRAC_N
	
.loop:
	test rax, rax
	jz .end

	movsd xmm1,QWORD [tenth]
	mulsd xmm0, xmm1
	dec rax
	jmp .loop
	
.end:
	movsd xmm1, QWORD [half]
	mulsd xmm0, xmm1
	movsd [rsp + M], xmm0
	;; -----------------------------

.loop1:	
	;;  U = floor(R * 10.0);
	movsd xmm0, QWORD[rsp + R]
	movsd xmm1, QWORD [ten]
	mulsd xmm0, xmm1
	call floor
	movsd QWORD [rsp + U], xmm0
	
	;; R = frac(R * 10.0);
	movsd xmm0, QWORD [rsp + R]
	movsd xmm1, QWORD [ten]
	mulsd xmm0, xmm1
	call frac
	movsd QWORD [rsp + R], xmm0

	;; M = M * 10.0;
	movsd xmm0, QWORD [rsp + M]
	movsd xmm1, QWORD [ten]
	mulsd xmm0, xmm1
	movsd QWORD [rsp + M], xmm0

	;; if(R < M) break;
	movsd xmm0, QWORD [rsp + R]
	movsd xmm1, QWORD [rsp + M]
	comisd xmm0, xmm1
	jb .loop1_end
	
	;; if(R > 1 - M) break;
	movsd xmm0, QWORD [one]
	movsd xmm1, QWORD [rsp + M]
	subsd xmm0, xmm1
	movsd xmm1, xmm0
	movsd xmm0, QWORD [rsp + R]
	comisd xmm0, xmm1
	ja .loop1_end

	;; printf("%d", (int)U);
	movsd xmm0, QWORD [rsp + U]
	cvttsd2si rax, xmm0
	add al, '0'
	mov BYTE [x], al
	mov rax, SYS_WRITE
	mov rdi, STDOUT
	mov rsi, x
	mov rdx, 1
	syscall
	
	jmp .loop1
.loop1_end:

	;; R > 0.5 {
	;; 	u += 1.0;
	;; }
	movsd xmm0, QWORD [rsp + R]
	movsd xmm1, QWORD [half]
	comisd xmm0, xmm1
	jbe .skip_increment

	movsd xmm0, QWORD [rsp + U]
	movsd xmm1, QWORD [one]
	addsd xmm0, xmm1
	movsd QWORD [rsp + U], xmm0

.skip_increment:
	;; printf("%d", (int)U);
	movsd xmm0, QWORD [rsp + U]
	cvttsd2si rax, xmm0
	add al, '0'
	mov BYTE [x], al
	mov rax, SYS_WRITE
	mov rdi, STDOUT
	mov rsi, x
	mov rdx, 1
	syscall
	
	;; Deallocate Stack Variables
	add rsp, Size
	%undef Size
	%undef M
	%undef R
	%undef U
	;; -----------------------------		
	
	ret

	;; xmm0 - input floating number
print_f64:
	;; print integet part
	cvttsd2si rax, xmm0
	call print_int

	;; print fractional part
	call frac
	call print_frac

	;; Print new line
	mov BYTE [x], 10
	mov rax, SYS_WRITE
	mov rdi, STDOUT
	mov rsi, x
	mov rdx, 1
	syscall
	
	ret


	;; xmm0 - input
	;; xmm1 - output
	;; frac(3.1415) == 0.1415
	;; frac(x) = x - floor(x)
frac:
	sub rsp, 16		;; Sub 16 from stack pointer
	movsd [rsp], xmm0

	call floor
	movsd xmm1, [rsp]
	subsd xmm1, xmm0
	movsd xmm0, xmm1

	add rsp, 16		;; Add 16 to stack pointer
	ret

	;; xmm0 - input
	;; floor(3.142) == 3.0
floor:
	pxor xmm1, xmm1
	cvttsd2si rax, xmm0    ;; Truncate Integer part from floating number
	comisd xmm0, xmm1
	ja .skipdec
	dec rax
	.skipdec:
	cvtsi2sd xmm0, rax     ;; Integer => float
	ret
	
_start:

	movsd xmm0, [pi]
	call print_f64
	
	mov rax, SYS_EXIT
	mov rdi, 0
	syscall

	segment .data
one:	dq 1.0
half:	dq 0.5
ten:	dq 10.0
tenth:	dq 0.1
pi:	dq 3.141592653589793
	
	segment .bss
x:	resb 1
