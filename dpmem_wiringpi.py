import string
import sys
import time
import wiringpi

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
      try:
          for pin in DP_DATAPINS:
              wiringpi.pinMode(pin, WPI_IN)

          for pin in DP_ADDRPINS:
              wiringpi.digitalWrite(pin, addr & 1)
              addr = addr >> 1

          wiringpi.digitalWrite(DP_CE, 0)
          wiringpi.digitalWrite(CP_R, 0)

          val=0
          for pin in reversed(DP_DATAPINS):
              val=val<<1
              val = val | wiringpi.digitalRead(pin)
      finally:
          wiringpi.digitalWrite(DP_R, 1)
          wiringpi.digitalWrite(DP_CE, 1)

      return val

  def write(self, addr, val):
      try:
          for pin in DP_DATAPINS:
              wiringpi.pinMode(pin, WPI_OUT)

          for pin in DP_ADDRPINS:
              wiringpi.digitalWrite(pin, addr & 1)
              addr = addr >> 1

          wiringpi.digitalWrite(DP_CE, 0)
          wiringpi.digitalWrite(DP_W, 0)

          for pin in DP_DATAPINS:
              wiringpi.digitalWrite(pin, val & 1)
              val = val >> 1
      finally:
          wiringpi.digitalWrite(DP_W, 1)
          wiringpi.digitalWrite(DP_CE, 1)

      return val

  def write_block(self, addr, data, count):
      for i in range(0, count):
          self.mem.write(addr+i, ord(data[i]))

  def read_block(self, addr, count):
      bytes=[]
      for i in range(0, count):
          bytes = bytes + chr(self.mem.read(addr+i))
      return bytes

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

    else:
        help()



if __name__ == "__main__":
    main()
