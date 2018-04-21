import argparse
import threading
import time

from dpmem_direct import DualPortMemory

SHARED_FMT = """
#        .junk       resb 476
#        .secbuf     resb 512

        .junk       resb 732
        .secbuf     resb 256

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

        .mbox_left  resb 1
        .mbox_right resb 1                  ; must be at 3FFh
"""

def parse_args():
    parser = argparse.ArgumentParser()

    defs = {"image_name": "images/dos331_krynn.img",
            "fail": False,
            "bios": False,
            "bios_drive_num": None}

    _help = 'Image name (default: %s)' % defs['image_name']
    parser.add_argument(
        '-i', '--image_name', dest='image_name', action='store',
        default=defs['image_name'],
        help=_help)

    _help = 'Send failure response (default: %s)' % defs['fail']
    parser.add_argument(
        '-f', '--fail', dest='fail', action='store_true',
        default=defs['fail'],
        help=_help)

    _help = 'Install bios extension (default: %s)' % defs['bios']
    parser.add_argument(
        '-b', '--bios', dest='bios', action='store_true',
        default=defs['bios'],
        help=_help)

    _help = 'Set drive number, only usable with --bios (default: %s)' % defs['bios_drive_num']
    parser.add_argument(
        '-d', '--drive', dest='bios_drive_num', action='store', type=int,
        default=defs['bios_drive_num'],
        help=_help)

    _help = 'Verbosity, use option multiple times to increase'
    parser.add_argument(
        '-v', '--verbose', dest='verbose', action='count',
        default=0,
        help=_help)

    args = parser.parse_args()

    return args

def asm_struct(x):
    total_count = 0
    offsets = {}
    sizes = {}
    fields = []
    fmt = "<"
    for line in x.split("\n"):
        line = line.strip()
        if not line:
            continue
        if line.startswith("#") or line.startswith(";"):
            continue
        parts = line.split()
        if len(parts)<3:
            continue
        if parts[1]!="resb":
            continue
        name = parts[0].lstrip(".")
        byte_count = int(parts[2])
        sizes[name] = byte_count
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

    return (fmt, fields, total_count, offsets, sizes)


class DriveServicerThread(threading.Thread):

    def __init__(self, mem, image_name, verbose):
        super(DriveServicerThread, self).__init__()

        self.mem = mem
        self.image_name = image_name
        self.image_file = open(image_name, "r+b")
        self.verbose = verbose

        self.config_disk(144)

        (self.shared_fmt, self.shared_fields, self.shared_length, self.shared_offsets, self.shared_sizes) = asm_struct(SHARED_FMT)

        self.daemon = True

    def config_disk(self, kind):
        if (kind==144):
            self.drive_type = 1
            self.floppy_type = 4
            self.num_cyl = 80
            self.num_head = 2
            self.num_sec = 18
        elif (kind==360):
            self.drive_type = 1
            self.floppy_type = 1
            self.num_cyl = 40
            self.num_head = 2
            self.num_sec = 9
        else:
            raise Exception("unknown disk kind")

    def get_byte(self, name):
        l = self.mem.read(self.shared_offsets[name])
        return l

    def set_byte(self, name, value):
        l = self.mem.write(self.shared_offsets[name], value)

    def inc_byte(self,name):
        l = self.mem.read(self.shared_offsets[name])
        l = (l+1) & 0xFF
        # in case the left side has the memory contended, keep trying until we get back what we wrote.
        while True:
            self.mem.write(self.shared_offsets[name], l)
            x = self.mem.read(self.shared_offsets[name])
            if (x==l):
                return

    def get_word(self,name):
        l = self.mem.read(self.shared_offsets[name])
        h = self.mem.read(self.shared_offsets[name] + 1)
        return h<<8 | l

    def set_word(self,name,value):
        self.mem.write(self.shared_offsets[name], value & 0xFF)
        self.mem.write(self.shared_offsets[name] +1, value >> 8)

    def set_bytes(self, name, bytes, count):
        offset = self.shared_offsets[name]
        self.mem.write_block(offset, bytes, count)

    def get_bytes(self, name, count):
        offset = self.shared_offsets[name]
        return self.mem.read_block(offset, count)

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

    def chs_to_block(self, cyl, head, sector):
        block = (cyl * self.num_head + head) * self.num_sec + (sector - 1)
        return block

    def handle_read(self):
        cx = self.get_word("cx")
        dx = self.get_word("dx")
        cyl = cx >> 8
        sector = cx & 0xFF
        head = dx >> 8

        buf_size = self.shared_sizes["secbuf"]
        blockoffs = self.get_word("sec_num") * buf_size

        block = self.chs_to_block(cyl, head, sector) + blockoffs/512

        if self.verbose>=1:
            print "read c/h/s %d/%d/%d block %d ofs %d bufsz %d" % (cyl, head, sector, block, blockoffs%512, buf_size)

        self.image_file.seek(block * 512 + blockoffs % 512)
        buf = self.image_file.read(buf_size)

        self.set_bytes("secbuf", buf, buf_size)
        self.set_word("ret_ax", 0x0001)

    def handle_write(self):
        cx = self.get_word("cx")
        dx = self.get_word("dx")
        cyl = cx >> 8
        sector = cx & 0xFF
        head = dx >> 8

        buf_size = self.shared_sizes["secbuf"]
        blockoffs = self.get_word("sec_num") * buf_size

        block = self.chs_to_block(cyl, head, sector) + blockoffs/512

        if self.verbose>=1:
           print "write c/h/s %d/%d/%d block %d offset %d bufsz %d" % (cyl, head, sector, block, blockoffs%512, buf_size)

        buf = self.get_bytes("secbuf", buf_size)
        self.image_file.seek(block * 512 + blockoffs % 512)
        self.image_file.write(buf)

        self.set_word("ret_ax", 0x0001)

    def handle_read_params(self):
        ret_dx = ((self.num_head-1) << 8) | 1
        ret_cx = (((self.num_cyl-1) & 0xFF ) << 8) | (((self.num_cyl-1) & 0x300) >> 8) | self.num_sec
        ret_bx = self.get_word("bx") & 0xFF00 | self.floppy_type

        """
        hdd param table
        self.set_word("dpt_head_unload", self.num_cyl)   # wMaxCyls
        self.set_byte("dpt_motor_wait", self.num_head)   # bMaxHeads
        self.set_word("dpt_bytes_sec", 0)                # wRWCyl
        self.set_word("dpt_gap", 0)                      # wWPCyl
        self.set_word("dpt_data_len", 0)                 # bECCLen
        self.set_word("dpt_fill_byte", 0)                # rOptFlags
        self.set_word("dpt_head_sett", 100)              # bTimeOutStd
        self.set_word("dpt_motor_st", 100)               # bTimeOutFmt
        #self.set_word("dpt_unused", 100)                 # bTimeOutChk
        """

        self.set_byte("dpt_head_unload", 0) # 191) # 0)
        self.set_byte("dpt_head_load", 1) # 2) # 1)
        self.set_byte("dpt_motor_wait", 0) # 37) # 0)
        self.set_byte("dpt_bytes_sec", 2)
        self.set_byte("dpt_sec_trk", self.num_sec)
        self.set_byte("dpt_gap", 0) # 27) # 0)
        self.set_byte("dpt_data_len", 0x0FF)
        self.set_byte("dpt_gap_len_f", 0) # 108) # 0)
        self.set_byte("dpt_fill_byte", 0xF6)
        self.set_byte("dpt_head_sett", 0) # 15) # 0)
        self.set_byte("dpt_motor_st", 0) # 8) # 0)

        self.set_word("ret_ax", 0x0000)
        self.set_word("ret_bx", ret_bx)
        self.set_word("ret_cx", ret_cx)
        self.set_word("ret_dx", ret_dx)

    def handle_read_size(self):
        ax = self.drive_type << 8

        size = self.num_head * self.num_cyl * self.num_sec

        if (self.drive_type in [1,2]):
            # floppy -- all hell breaks loose if we mess with cx and dx, so leave them unchanged
            self.set_word("ret_cx", self.get_word("cx")) # size >> 16)
            self.set_word("ret_dx", self.get_word("dx")) # size & 0xFFFF)
        else:
            # hard disk -- cx:dx is size
            self.set_word("ret_cx", size >> 16)
            self.set_word("ret_dx", size & 0xFFFF)
        self.set_word("ret_ax", ax)

    def handle_interrupt(self):
        if self.verbose>=2:
            self.dump_request()

        ah = self.get_word("ax") >> 8
        if (ah == 0x02):
            self.handle_read()
        elif (ah == 0x03):
            self.handle_write()
        elif (ah == 0x08):
            self.handle_read_params()
        elif (ah == 0x15):
            self.handle_read_size()
        else:
            self.set_word("ret_ax", 0x0100)

        if self.verbose>=2:
            self.dump_reply()

        self.inc_byte("mbox_left")

    def run(self):
        while True:
            if self.mem.get_interrupt():
                self.mem.clear_interrupt()
                self.handle_interrupt()
            else:
                time.sleep(0.0001)

def patch_bios(data, drive_num):
    romvar_sig = "RVAR"+chr(0)
    romvar_index = data.index(romvar_sig) + len(romvar_sig)

    data = bytearray(data)

    if drive_num is not None:
        data[romvar_index] = drive_num

    cksum = 0
    for i in range(0, len(data)-1):
        cksum = cksum + data[i]

    chksum = cksum & 0xFF
    data[-1] = 256-chksum

    return str(data)

def main():
    args = parse_args()

    mem = DualPortMemory()

    servicer = DriveServicerThread(mem = mem,
                                   image_name = args.image_name,
                                   verbose = args.verbose)

    if args.bios:
        bootimage = open("driver/pidrive.bin", "rb").read()
        bootimage = patch_bios(bootimage, args.bios_drive_num)
        servicer.set_bytes("junk", bootimage, len(bootimage))
    else:
        servicer.set_bytes("junk", "no_boot_image", len("no_boot_image"))

    if args.fail:
        servicer.set_byte("ret_ax", 0x0100)
        servicer.inc_byte("mbox_left")
        return

    print "Image = ", servicer.image_name
    print "Cylinders =", servicer.num_cyl, "Heads =", servicer.num_head, "Sectors =", servicer.num_sec, "Size =", \
          servicer.num_cyl*servicer.num_head*servicer.num_sec*512/1024, "KB"
    print "Servicing Requests..."

    servicer.run()

    while True:
        time.sleep(1)

if __name__ == "__main__":
    main()
