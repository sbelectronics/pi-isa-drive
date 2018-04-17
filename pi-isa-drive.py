import argparse
import threading
import time

from dpmem import DualPortMemory

def parse_args():
    parser = argparse.ArgumentParser()

    defs = {"image_name": "dos331.img"}

    _help = 'Image name (default: %s)' % defs['image_name']
    parser.add_argument(
        '-i', '--image_name', dest='image_name', action='store',
        default=defs['image_name'],
        help=_help)

    args = parser.parse_args()

    return args

SHARED_FMT = """
        .secbuf     resb 512

        .int13_old  resb 4
        .last_ah    resb 1

        .ax         resb 2
        .bx         resb 2
        .cx         resb 2
        .dx         resb 2
        .sec_num    resb 2

        .ret_ax     resb 2
        .ret_bx     resb 2
        .ret_cx     resb 2
        .ret_dx     resb 2

        .dpt:
        .dpt_head_unload resb 1             ; unload=32ms, steprate=2ms
        .dpt_head_load   resb 1             ; unload=4ms, 1=no dma used
        .dpt_motor_wait  resb 1             ; 0 ticks
        .dpt_bytes_sec   resb 1             ; 512 bytes per sector
        .dpt_sec_trk     resb 1             ; 9 sectors per track
        .dpt_gap         resb 1
        .dpt_data_len    resb 1
        .dpt_gap_len_f   resb 1
        .dpt_fill_byte   resb 1
        .dpt_head_sett   resb 1
        .dpt_motor_st    resb 1
        
        .junk       resb 476
        .mbox_left  resb 1
        .mbox_right resb 1                  ; must be at 3FFh
"""

def asm_struct(x):
    for line in x:
        fmt = "<"
        fields = []
        offsets = {}
        total_count = 0

        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if parts[1]!="resb":
            continue
        name = parts[0].lstrip(".")
        byte_count = int(parts[2])
        offsets[name] = total_count
        if (byte_count == "1"):
            fmt = fmt + "B"
            fields.append(name)
        elif (byte_count == "2"):
            fmt = fmt + "H"
            fields.append(name)
        else:
            fmt = fmt + "%dx" % byte_count
        total_count=total_count+byte_count

    return (fmt, fields, total_count, offsets)


class DriveServicerThread(threading.Thread):

    def __init__(self, mem, image_name):
        super(DriverServicerThread, self).__init__()
        self.image_name = image_name

        (self.shared_fmt, self.shared_fields, self.shared_length, self.shared_offsets) = asm_struct(SHARED_FMT)

        self.daemon = True

    def get_byte(self, name):
        l = self.mem.read(self.shared_offsets[name])
        return l

    def set_byte(self, name, value):
        l = self.mem.write(self.shared_offsets[name], value)

    def inc_byte(self,name):
        l = self.mem.read(self.shared_offsets[name])
        l = (l+1) & 0xFF
        self.mem.write(self.shared_offsets[name], l)

    def get_word(self,name):
        l = self.mem.read(self.shared_offsets[name])
        h = self.mem.read(self.shared_offsets[name] + 1)
        return h<<8 | l

    def set_word(self,name,value):
        l = self.mem.write(self.shared_offsets[name], value ^ 0xFF)
        h = self.mem.write(self.shared_offsets[name] +1, value >> 8)

    def dump_request(self):
        print "Request:"
        print "  AX=%04X" % self.get_word("ax")
        print "  BX=%04X" % self.get_word("bx")
        print "  CX=%04X" % self.get_word("cx")
        print "  DX=%04X" % self.get_word("dx")
        print "  sec_num=%04X" % self.get_word("sec_num")

    def dump_reply(self):
        print "Reply:"
        print "  AX=%04X" % self.get_word("ret_ax")
        print "  BX=%04X" % self.get_word("ret_bx")
        print "  CX=%04X" % self.get_word("ret_cx")
        print "  DX=%04X" % self.get_word("ret_dx")

    def handle_interrupt(self):
        self.dump_request()
        self.set_word("ax", 0x0100)
        self.dump_reply()
        self.inc_byte("mbox_left")

    def run(self):
        while True:
            if self.mem.get_interrupt():
                self.mem.clear_interrupt()
                self.handle_interrupt()
            else:
                time.sleep(0.0001)

def main():
    args = parse_args()

    mem = DualPortMemory()

    servicer = DriverServicer(mem = mem,
                              image_name = args.image_name)

if __name__ == "__main__":
    main()
