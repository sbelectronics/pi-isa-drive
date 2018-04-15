import string
import sys
import time
import RPi.GPIO as IO

DP_ADDRPINS=[13, 19, 26, 21, 20, 16, 12, 7, 8, 18]
DP_DATAPINS=[24, 25, 04, 17, 27, 22, 10, 9]
DP_INTR=23
DP_W=5
DP_R=6
DP_CE=11
DP_CONTROLPINS=[DP_W, DP_R, DP_CE]

class DualPortMemory():
  def __init__(self):
      IO.setmode(IO.BCM)
      for addrpin in DP_ADDRPINS:
          IO.setup(addrpin, IO.OUT)
  
      for datapin in DP_DATAPINS:
          IO.setup(datapin, IO.IN)

      for controlpin in DP_CONTROLPINS:
          IO.setup(controlpin, IO.OUT)

      IO.setup(DP_INTR, IO.IN, pull_up_down=IO.PUD_UP)

      IO.output(DP_W, 1)
      IO.output(DP_R, 1)
      IO.output(DP_CE, 1)

  def read(self, addr):
      try:
          for pin in DP_DATAPINS:
              IO.setup(pin, IO.IN)

          for pin in DP_ADDRPINS:
              IO.output(pin, addr & 1)
              addr = addr >> 1

          IO.output(DP_CE, 0)
          IO.output(DP_R, 0)

          val=0
          for pin in reversed(DP_DATAPINS):
              val=val<<1
              val = val | IO.input(pin)
      finally:
          IO.output(DP_R, 1)
          IO.output(DP_CE, 1)

      return val

  def write(self, addr, val):
      try:
          for pin in DP_DATAPINS:
              IO.setup(pin, IO.OUT)

          for pin in DP_ADDRPINS:
              IO.output(pin, addr & 1)
              addr = addr >> 1

          IO.output(DP_CE, 0)
          IO.output(DP_W, 0)

          for pin in DP_DATAPINS:
              IO.output(pin, val & 1)
              val = val >> 1
      finally:
          IO.output(DP_W, 1)
          IO.output(DP_CE, 1)

      return val

  def get_interrupt(self):
      return IO.input(DP_INTR) == 0

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
