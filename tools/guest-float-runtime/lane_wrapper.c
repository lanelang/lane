#include "ryu/ryu.h"

void *memcpy(void *destination, const void *source, unsigned long length) {
  unsigned char *out = destination;
  const unsigned char *in = source;
  for (unsigned long i = 0; i < length; ++i) out[i] = in[i];
  return destination;
}

static int lane_canonicalize(char *output, int length) {
  if (length == 3 && output[0] == 'N') return length;
  int sign = output[0] == '-';
  if (length - sign == 8 && output[sign] == 'I') {
    output[sign] = 'i';
    output[sign + 1] = 'n';
    output[sign + 2] = 'f';
    return sign + 3;
  }
  char digits[24];
  int digit_count = 0;
  int exponent_index = sign;
  while (exponent_index < length && output[exponent_index] != 'E') {
    if (output[exponent_index] != '.') digits[digit_count++] = output[exponent_index];
    ++exponent_index;
  }
  int exponent_sign = 1;
  int exponent = 0;
  int cursor = exponent_index + 1;
  if (output[cursor] == '-') {
    exponent_sign = -1;
    ++cursor;
  } else if (output[cursor] == '+') {
    ++cursor;
  }
  while (cursor < length) exponent = exponent * 10 + output[cursor++] - '0';
  exponent *= exponent_sign;
  cursor = 0;
  if (sign) output[cursor++] = '-';
  if (exponent >= -6 && exponent < 21) {
    if (exponent < 0) {
      output[cursor++] = '0';
      output[cursor++] = '.';
      for (int i = -1; i > exponent; --i) output[cursor++] = '0';
      for (int i = 0; i < digit_count; ++i) output[cursor++] = digits[i];
    } else if (exponent + 1 >= digit_count) {
      for (int i = 0; i < digit_count; ++i) output[cursor++] = digits[i];
      for (int i = digit_count; i < exponent + 1; ++i) output[cursor++] = '0';
      output[cursor++] = '.';
      output[cursor++] = '0';
    } else {
      for (int i = 0; i < exponent + 1; ++i) output[cursor++] = digits[i];
      output[cursor++] = '.';
      for (int i = exponent + 1; i < digit_count; ++i) output[cursor++] = digits[i];
    }
  } else {
    output[cursor++] = digits[0];
    if (digit_count > 1) {
      output[cursor++] = '.';
      for (int i = 1; i < digit_count; ++i) output[cursor++] = digits[i];
    }
    output[cursor++] = 'e';
    output[cursor++] = exponent < 0 ? '-' : '+';
    if (exponent < 0) exponent = -exponent;
    if (exponent >= 100) output[cursor++] = '0' + exponent / 100;
    if (exponent >= 10) output[cursor++] = '0' + exponent / 10 % 10;
    output[cursor++] = '0' + exponent % 10;
  }
  return cursor;
}

int lane_f32_to_string(float value, char *output) {
  union { float value; unsigned int bits; } decoded = { value };
  if ((decoded.bits & 0x7fffffffU) == 0) {
    int cursor = 0;
    if (decoded.bits >> 31) output[cursor++] = '-';
    output[cursor++] = '0';
    output[cursor++] = '.';
    output[cursor++] = '0';
    return cursor;
  }
  return lane_canonicalize(output, f2s_buffered_n(value, output));
}

int lane_f64_to_string(double value, char *output) {
  union { double value; unsigned long long bits; } decoded = { value };
  if ((decoded.bits & 0x7fffffffffffffffULL) == 0) {
    int cursor = 0;
    if (decoded.bits >> 63) output[cursor++] = '-';
    output[cursor++] = '0';
    output[cursor++] = '.';
    output[cursor++] = '0';
    return cursor;
  }
  return lane_canonicalize(output, d2s_buffered_n(value, output));
}
