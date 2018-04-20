import string
import sys
import time
import wiringpi

import dpmem_direct_ext
from dpmem_common import *

WPI_IN = 0
WPI_OUT = 1

class DualPortMemory():
  def __init__(self):
      wiringpi.wiringPiSetupGpio()
      for addrpin in DP_ADDRPINS:
          wiringpi.pinMode(addrpin, WPI_OUT)

      for datapin in DP_DATAPINS:
          wiringpi.pinMode(datapin, WPI_IN)

      for controlpin in DP_CONTROLPINS:
          wiringpi.pinMode(controlpin, WPI_OUT)

      wiringpi.pinMode(DP_INTR, WPI_IN)
      wiringpi.pullUpDnControl(DP_INTR, 2)

      wiringpi.digitalWrite(DP_W, 1)
      wiringpi.digitalWrite(DP_R, 1)
      wiringpi.digitalWrite(DP_CE, 1)

  def read(self, addr):
      return dpmem_direct_ext.read_byte(addr)

  def read_block(self, addr, count):
      return dpmem_direct_ext.read_block(addr, count)

  def write(self, addr, val):
      dpmem_direct_ext.write_byte(addr, val)

  def write_block(self, addr, data, count):
      dpmem_direct_ext.write_block(addr, data, count)

  def read_old(self, addr):
      try:
          dpmem_direct_ext.config_input()
          dpmem_direct_ext.set_addr(addr)

          wiringpi.digitalWrite(DP_CE, 0)
          wiringpi.digitalWrite(DP_R, 0)

          val=dpmem_direct_ext.get_data()
      finally:
          wiringpi.digitalWrite(DP_R, 1)
          wiringpi.digitalWrite(DP_CE, 1)

      return val

  def write_old(self, addr, val):
      try:
          dpmem_direct_ext.config_output()
          dpmem_direct_ext.set_addr(addr)

          wiringpi.digitalWrite(DP_CE, 0)
          wiringpi.digitalWrite(DP_W, 0)

          dpmem_direct_ext.set_data(val)
      finally:
          wiringpi.digitalWrite(DP_W, 1)
          wiringpi.digitalWrite(DP_CE, 1)

      return val

  def get_interrupt(self):
      return wiringpi.digitalRead(DP_INTR) == 0

  def clear_interrupt(self):
      self.read(0x3FF)

def str_to_int(val):
    if "x" in val:
        val = string.atoi(val, 16)
    else:
        val = string.atoi(val)
    return val

def help():
    print "read <addr>"
    print "write <addr> <val>"
    print "waitint"

def main():
    mem = DualPortMemory()

    if sys.argv[1] == "read":
        addr = str_to_int(sys.argv[2])
        print "addr %04x = %02X" % (addr, mem.read(addr))

    elif sys.argv[1] == "write":
        addr = str_to_int(sys.argv[2])
        val = str_to_int(sys.argv[3])
        mem.write(addr, val)

    elif sys.argv[1] == "waitint":
        while not mem.get_interrupt():
            time.sleep(0.0001)
        mem.clear_interrupt()

    elif sys.argv[1] == "readblock":
        addr = str_to_int(sys.argv[2])
        count = str_to_int(sys.argv[3])
        data = mem.read_block(addr, count)
        for b in data:
            print "%02X" % ord(b),
        print

    elif sys.argv[1] == "writeblock":
        addr = str_to_int(sys.argv[2])
        count = str_to_int(sys.argv[3])
        data = ""
        for arg in sys.argv[4:]:
            data = data + chr(str_to_int(arg))
        mem.write_block(addr, data, count)

    elif sys.argv[1] == "benchread":
        t=time.time()
        for i in range(0,100):
            mem.read_block(0,512)
        elapsed = time.time()-t
        print "elapsed =", elapsed, "ops/s = ", 100.0/elapsed, "KB/s =", 100.0/elapsed*512/1024
        return

    elif sys.argv[1] == "benchwrite":
        controlblock = ""
        for i in range(0, 512):
            controlblock = controlblock + chr(i & 0xFF)
        t=time.time()
        for i in range(0,100):
            mem.write_block(0,controlblock,512)
        elapsed = time.time()-t
        print "elapsed =", elapsed, "ops/s = ", 100.0/elapsed, "KB/s =", 100.0/elapsed*512/1024
        return

    elif sys.argv[1] == "testread":
        last_block = mem.read_block(0,512)
        while True:
            block = mem.read_block(0, 512)
            errors=0;
            for i in range(0,512):
                if block[i]!=last_block[i]:
                    errors+=1
            if errors>0:
                print "errors", errors
            last_block = block

    elif sys.argv[1] == "testreadwrite":
        passnum = 0
        while True:
            controlblock = ""
            for i in range(0, 512):
                controlblock = controlblock + chr((i+passnum) & 0xFF)

            mem.write_block(0,controlblock,512)

            block = mem.read_block(0, 512)
            errors=0;
            for i in range(0,512):
                if block[i]!=controlblock[i]:
                    errors+=1
            if errors>0:
                print "errors", errors

            passnum+=1

    else:
        help()



if __name__ == "__main__":
    main()
