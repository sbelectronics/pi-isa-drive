from distutils.core import setup, Extension

dpmem_direct_ext = Extension('dpmem_direct_ext',
                    sources = ['dpmem_direct_ext.c'],
                    libraries = ['wiringPi'])

setup (name = 'dpmem_direct_ext',
       version = '1.0',
       description = 'Dual port memory extension',
       ext_modules = [dpmem_direct_ext])
