""" Convert a binary file into a bios extension.

    Assumes:
       1) The first three bytes of the file can be overwritten
       2) The fourth byte of the file is the beginning of executable code
       3) The file is set to origin 0

    Syntax:
        make_bios.py <infilename> <outfilename>
"""

import sys

def main():
    data = open(sys.argv[1],"rb").read()

    data = bytearray(data)

    # Make room for the checksum
    if (len(data) % 512) == 0:
        data.append(0)

    # round to a block size
    while (len(data) % 512) != 0:
        data.append(0)

    data[0] = 0x55
    data[1] = 0xAA
    data[2] = len(data)/512

    cksum = 0
    for i in range(0, len(data)):
        cksum = cksum + data[i]

    chksum = cksum & 0xFF
    data[-1] = 256-chksum

    open(sys.argv[2],"wb").write(data)

if __name__ == "__main__":
    main()