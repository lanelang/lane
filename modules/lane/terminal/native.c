#include "moonbit.h"

#if defined(_WIN32)

MOONBIT_FFI_EXPORT
int32_t lane_terminal_is_tty(int32_t fd) {
  (void)fd;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t lane_terminal_width(int32_t fd) {
  (void)fd;
  return 0;
}

#else

#include <sys/ioctl.h>
#include <unistd.h>

MOONBIT_FFI_EXPORT
int32_t lane_terminal_is_tty(int32_t fd) {
  return isatty(fd) ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t lane_terminal_width(int32_t fd) {
  struct winsize ws;
  if (ioctl(fd, TIOCGWINSZ, &ws) == -1 || ws.ws_col <= 0) {
    return 0;
  }
  return (int32_t)ws.ws_col;
}

#endif
