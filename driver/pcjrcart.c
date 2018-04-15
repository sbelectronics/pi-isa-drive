/* based on PCJRCART.C by Shaos (Dec 2016) */

/* Create ROM image from COM file for XT bios extension */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include "crc16.h"

#define MAXSIZE 65535

int main(int argc, char **argv)
{
    FILE *f;
    int i;
    char fname[100],*po;
    unsigned long sz;
    unsigned char extra = 0;
    //    unsigned short crc = 0;
    unsigned char cksum = 0;
    unsigned char *bytes = (unsigned char*)malloc(MAXSIZE);
    if(bytes==NULL)
    {
       printf("\nCan't allocate memory!\n\n");
       return -1;
    }
    if(argc<2)
    {
       printf("\nFilename was not specified!\n\n");
       return -2;
    }
    memset(bytes,0,MAXSIZE);
    bytes[0] = 0x55;
    bytes[1] = 0xAA;

    strcpy(fname,argv[1]);
    f = fopen(fname,"rb");
    if(f==NULL)
    {
       printf("\nCan't open file '%s'!\n\n",fname);
       free(bytes);
       return -3;
    }
    fseek(f,0,SEEK_END);
    sz = ftell(f);
    printf("%s %lu\n",fname,sz);
    if(sz>=65280L)
    {
       printf("\nFile is too large!\n\n");
       fclose(f);
       free(bytes);
       return -4;
    }
    fseek(f,0,SEEK_SET);
    fread(&bytes[256],1,sz,f);
    fclose(f);

    sz += 258;
    if(sz&511)
    {
       sz &= 0xFE00;
       sz += 512;
    }
    bytes[2] = sz>>9;
    printf("ROM size is %lu bytes (%i)\n",sz,bytes[2]);
    bytes[3] = 0xE9;
    bytes[4] = 0x01;
    bytes[5] = 0x00;
    bytes[6] = 0x00;
    bytes[7] = 0xB8;
    bytes[8] = 0x00;
    bytes[9] = 0x01;
    bytes[10] = 0xFF;
    bytes[11] = 0xE0;

    cksum = 0;
    for (i=0; i<sz-2; i++) {
      cksum = cksum + bytes[i];
    } 
    cksum = 256-cksum;
    printf("Calculated cksum is 0x%2.2X\n", cksum);

    bytes[sz-2] = 0;
    bytes[sz-1] = cksum;

    po = strrchr(fname,'.');
    if(po!=NULL) *po=0;
    strcat(fname,".bin");
    f = fopen(fname,"wb");
    if(f==NULL)
    {
       printf("\nCan't open file '%s'!\n\n",fname);
       free(bytes);
       return -5;
    }
    if(sz<=32768L) fwrite(bytes,1,sz,f);
    else fwrite(bytes,1,32768L,f);
    fclose(f);
    if(sz>32768L)
    {
       fname[strlen(fname)-1] = '2';
       f = fopen(fname,"wb");
       if(f==NULL)
       {
          printf("\nCan't open file '%s'!\n\n",fname);
          free(bytes);
          return -6;
       }
       if(sz==65536L)
       {
          fwrite(&bytes[32768L],4,0x1FFF,f);
          fputc(bytes[65532L],f);
          fputc(bytes[65533L],f);
          fputc(bytes[65534L],f);
          fputc(extra,f);
       }
       else fwrite(&bytes[32768L],1,sz-32768L,f);
       fclose(f);
    }
    free(bytes);
    return 0;
}
