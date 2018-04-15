all: pidrive.bin

pidrive.bin: pidrive.com pcjrcart
	./pcjrcart pidrive.com

pidrive.com: pidrive.asm
	nasm pidrive.asm -fbin -l pidrive.lst -o pidrive.com

pcjrcart:
	gcc -o pcjrcart pcjrcart.c

clean:
	rm -f pcjrcart pidrive.bin pidrive.com
