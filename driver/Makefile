all: pidrive.com pidrive.bin

pidrive.bin: pidrive.com pcjrcart
	./pcjrcart pidrive.com

pidrive.com: pidrive.asm
	nasm pidrive.asm -fbin -l pidrive.lst -o pidrive.com -dDOS_COM_TSR

pidrive_zero.com: pidrive.asm
	nasm pidrive.asm -fbin -l pidrive_zero.lst -o pidrive_zero.com -dQUIET

pidrive.bin: pidrive_zero.com
	python make_bios.py pidrive_zero.com pidrive.bin

pcjrcart:
	gcc -o pcjrcart pcjrcart.c

clean:
	rm -f pcjrcart pidrive.bin pidrive.com pidrive_zero.com
