import sys

def main():
    data = open(sys.argv[1],"rb").read()
    data = bytearray(data)
    cksum = 0
    for d in data:
        cksum = cksum + d
    cksum = cksum & 0xFF
    
    if (cksum == 0):
        print "ok"
        sys.exit(0)
    else:
        print "bogus!"
        sys.exit(-1)

if __name__ == "__main__":
    main()
