#include <Python.h>
#include <wiringPi.h>
#include <unistd.h>

#define DP_W 5
#define DP_R 6
#define DP_CE 11

const int DP_ADDRPINS[] = { 13, 19, 26, 21, 20, 16, 12, 7, 8, 18 };
const int DP_DATAPINS[] = { 24, 25, 04, 17, 27, 22, 10, 9 };
const int DP_DATAPINS_REVERSED[] = { 9, 10, 22, 27, 17, 04, 25, 24 };

void dpmem_config_input(void)
{
  int i;
  for (i=0; i<8; i++) {
    pinMode(DP_DATAPINS[i], INPUT);
  }
}

void dpmem_config_output(void)
{
  int i;
  for (i=0; i<8; i++) {
    pinMode(DP_DATAPINS[i], OUTPUT);
  }
}

void dpmem_set_addr(unsigned int addr)
{
  int i;
  for (i=0; i<10; i++) {
    digitalWrite(DP_ADDRPINS[i], addr & 0x01);
    addr = addr >> 1;
  }
}

void dpmem_set_data(unsigned int data)
{
  int i;
  for (i=0; i<8; i++) {
    digitalWrite(DP_DATAPINS[i], data & 0x01);
    data = data >> 1;
  }
}

unsigned int dpmem_get_data(void)
{
  int i;
  int data = 0;
  for (i=0; i<8; i++) {
    data = data << 1;
    data = data | digitalRead(DP_DATAPINS_REVERSED[i]);
  }
  return data;
}

void short_delay(void)
{
    // Just do nothing for a while. This is to allow the RAM some time to do it's work.
    //
    int j;

    for (j=0; j<1; j++) {
        asm("nop");
    }
}

static PyObject *dpmem_direct_set_addr(PyObject *self, PyObject *args)
{
  int i;  
  if (!PyArg_ParseTuple(args, "i", &i)) {  
    return NULL;    
  }
  dpmem_set_addr(i);
  return Py_BuildValue("");
}

static PyObject *dpmem_direct_set_data(PyObject *self, PyObject *args)
{
  int i;
  if (!PyArg_ParseTuple(args, "i", &i)) {
    return NULL;
  }
  dpmem_set_data(i);
  return Py_BuildValue("");
}

static PyObject *dpmem_direct_get_data(PyObject *self, PyObject *args)
{
  if (!PyArg_ParseTuple(args, "")) {
    return NULL;
  }
  return Py_BuildValue("i", dpmem_get_data());
}

static PyObject *dpmem_direct_config_input(PyObject *self, PyObject *args)
{
  if (!PyArg_ParseTuple(args, "")) {
    return NULL;
  }
  dpmem_config_input();
  return Py_BuildValue("");
}

static PyObject *dpmem_direct_config_output(PyObject *self, PyObject *args)
{
  if (!PyArg_ParseTuple(args, "")) {
    return NULL;
  }
  dpmem_config_output();
  return Py_BuildValue("");
}

static PyObject *dpmem_direct_read_byte(PyObject *self, PyObject *args)
{
  unsigned int addr;
  unsigned int data;
  if (!PyArg_ParseTuple(args, "i", &addr)) {
    return NULL;
  }
  dpmem_config_input();
  dpmem_set_addr(addr);
  digitalWrite(DP_CE,0);
  digitalWrite(DP_R,0);
  // see comment in dpmem_direct_read_block. Just to be safe...
  digitalRead(DP_DATAPINS_REVERSED[0]);
  data = dpmem_get_data();
  digitalWrite(DP_R,1);
  digitalWrite(DP_CE,1);
  return Py_BuildValue("i", data);
}

static PyObject *dpmem_direct_write_byte(PyObject *self, PyObject *args)
{
  unsigned int addr, data;
  if (!PyArg_ParseTuple(args, "ii", &addr, &data)) {
    return NULL;
  }
  dpmem_config_output();
  dpmem_set_addr(addr);
  dpmem_set_data(data);
  digitalWrite(DP_CE,0);
  digitalWrite(DP_W,0);
  digitalWrite(DP_W,1);
  digitalWrite(DP_CE,1);
  return Py_BuildValue("");
}

static PyObject *dpmem_direct_read_block(PyObject *self, PyObject *args)
{
  unsigned int addr, count;
  char buf[1024];
  int i;

  if (!PyArg_ParseTuple(args, "ii", &addr, &count)) {
    return NULL;
  }

  if (count > 1024) {
      // throw exception?
      return NULL;
  }

  dpmem_config_input();

  for (i=0; i<count; i++) {
      dpmem_set_addr(addr + i);
      digitalWrite(DP_CE,0);
      digitalWrite(DP_R,0);
      // For some reason, the first bit we get will occasionally glitch. Originally I thought it was due to lack
      // of time between signaling the control pins and reading the first data bit, but injecting NOPs doesn't
      // seem to help. What does work is just throwing away the first bit and re-reading it. Go figure.
      digitalRead(DP_DATAPINS_REVERSED[0]);
      buf[i] = dpmem_get_data();
      digitalWrite(DP_R,1);
      digitalWrite(DP_CE,1);
  }

  return Py_BuildValue("s#", buf, count);
}

static PyObject *dpmem_direct_write_block(PyObject *self, PyObject *args)
{
  unsigned int addr;
  const char *buf;
  unsigned int buf_len, count;
  int i;

  if (!PyArg_ParseTuple(args, "is#i", &addr, &buf, &buf_len, &count)) {
    return NULL;
  }

  dpmem_config_output();

  for (i=0; i<count; i++) {
      dpmem_set_addr(addr);
      dpmem_set_data(*buf);
      digitalWrite(DP_CE,0);
      digitalWrite(DP_W,0);
      short_delay();
      digitalWrite(DP_W,1);
      digitalWrite(DP_CE,1);
      addr++;
      buf++;
  }
  return Py_BuildValue("");
}

static PyMethodDef dpmem_direct_methods[] = {
  {"set_addr", dpmem_direct_set_addr, METH_VARARGS, "Set address bits"},
  {"set_data", dpmem_direct_set_data, METH_VARARGS, "Set data bits"},
  {"get_data", dpmem_direct_get_data, METH_VARARGS, "Get data bits"},
  {"config_input", dpmem_direct_config_input, METH_VARARGS, "Set data pins for reading"},
  {"config_output", dpmem_direct_config_output, METH_VARARGS, "Set data pins for writing"},
  {"read_byte", dpmem_direct_read_byte, METH_VARARGS, "Read byte at address"},
  {"write_byte", dpmem_direct_write_byte, METH_VARARGS, "Write byte at address"},
  {"read_block", dpmem_direct_read_block, METH_VARARGS, "Read block at address"},
  {"write_block", dpmem_direct_write_block, METH_VARARGS, "Write block at address"},
  {NULL, NULL, 0, NULL}
};

PyMODINIT_FUNC initdpmem_direct_ext(void)
{
  wiringPiSetupGpio();
  (void) Py_InitModule("dpmem_direct_ext", dpmem_direct_methods);
}
