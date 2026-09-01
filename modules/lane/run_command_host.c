#define _GNU_SOURCE

#include "moonbit.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

enum lane_command_outcome {
  LANE_COMMAND_EXITED = 0,
  LANE_COMMAND_SIGNALED = 1,
  LANE_COMMAND_NOT_FOUND = 2,
  LANE_COMMAND_PERMISSION_DENIED = 3,
  LANE_COMMAND_SYSTEM_FAILURE = 4,
};

static void lane_command_result(int32_t *outcome, int32_t kind, int32_t code) {
  outcome[0] = kind;
  outcome[1] = code;
}

#if defined(_WIN32)

#include <windows.h>
#include <wchar.h>
#include <wctype.h>

static wchar_t *lane_copy_wide(moonbit_string_t source) {
  int32_t length = Moonbit_array_length(source);
  wchar_t *copy = (wchar_t *)malloc(((size_t)length + 1) * sizeof(wchar_t));
  if (copy == NULL) {
    return NULL;
  }
  for (int32_t index = 0; index < length; ++index) {
    copy[index] = (wchar_t)source[index];
  }
  copy[length] = L'\0';
  return copy;
}

struct lane_wide_builder {
  wchar_t *data;
  size_t length;
  size_t capacity;
};

static int lane_wide_reserve(struct lane_wide_builder *builder, size_t extra) {
  if (extra > SIZE_MAX - builder->length - 1) {
    return 0;
  }
  size_t required = builder->length + extra + 1;
  if (required <= builder->capacity) {
    return 1;
  }
  size_t capacity = builder->capacity == 0 ? 64 : builder->capacity;
  while (capacity < required) {
    if (capacity > SIZE_MAX / 2) {
      capacity = required;
      break;
    }
    capacity *= 2;
  }
  wchar_t *data = (wchar_t *)realloc(builder->data, capacity * sizeof(wchar_t));
  if (data == NULL) {
    return 0;
  }
  builder->data = data;
  builder->capacity = capacity;
  return 1;
}

static int lane_wide_push(struct lane_wide_builder *builder, wchar_t value) {
  if (!lane_wide_reserve(builder, 1)) {
    return 0;
  }
  builder->data[builder->length++] = value;
  builder->data[builder->length] = L'\0';
  return 1;
}

static int lane_append_windows_argument(
  struct lane_wide_builder *builder,
  moonbit_string_t argument
) {
  int32_t length = Moonbit_array_length(argument);
  int quote = length == 0;
  for (int32_t index = 0; index < length && !quote; ++index) {
    uint16_t value = argument[index];
    quote = value == ' ' || value == '\t' || value == '"';
  }
  if (!quote) {
    if (!lane_wide_reserve(builder, (size_t)length)) {
      return 0;
    }
    for (int32_t index = 0; index < length; ++index) {
      builder->data[builder->length++] = (wchar_t)argument[index];
    }
    builder->data[builder->length] = L'\0';
    return 1;
  }
  if (!lane_wide_push(builder, L'"')) {
    return 0;
  }
  int32_t backslashes = 0;
  for (int32_t index = 0; index < length; ++index) {
    wchar_t value = (wchar_t)argument[index];
    if (value == L'\\') {
      backslashes += 1;
      continue;
    }
    if (value == L'"') {
      for (int32_t count = 0; count < backslashes * 2 + 1; ++count) {
        if (!lane_wide_push(builder, L'\\')) {
          return 0;
        }
      }
      backslashes = 0;
      if (!lane_wide_push(builder, L'"')) {
        return 0;
      }
      continue;
    }
    for (int32_t count = 0; count < backslashes; ++count) {
      if (!lane_wide_push(builder, L'\\')) {
        return 0;
      }
    }
    backslashes = 0;
    if (!lane_wide_push(builder, value)) {
      return 0;
    }
  }
  for (int32_t count = 0; count < backslashes * 2; ++count) {
    if (!lane_wide_push(builder, L'\\')) {
      return 0;
    }
  }
  return lane_wide_push(builder, L'"');
}

static int lane_windows_environment_key_equal(
  const wchar_t *entry,
  moonbit_string_t key
) {
  int32_t key_length = Moonbit_array_length(key);
  const wchar_t *separator = wcschr(entry, L'=');
  if (separator == NULL || separator - entry != key_length) {
    return 0;
  }
  for (int32_t index = 0; index < key_length; ++index) {
    if (towupper(entry[index]) != towupper((wchar_t)key[index])) {
      return 0;
    }
  }
  return 1;
}

static int lane_windows_keys_equal(
  moonbit_string_t left,
  moonbit_string_t right
) {
  int32_t length = Moonbit_array_length(left);
  if (length != Moonbit_array_length(right)) {
    return 0;
  }
  for (int32_t index = 0; index < length; ++index) {
    if (towupper((wchar_t)left[index]) != towupper((wchar_t)right[index])) {
      return 0;
    }
  }
  return 1;
}

static int lane_windows_key_is_shadowed(
  moonbit_string_t *keys,
  int32_t count,
  int32_t index
) {
  for (int32_t later = index + 1; later < count; ++later) {
    if (lane_windows_keys_equal(keys[index], keys[later])) {
      return 1;
    }
  }
  return 0;
}

static wchar_t *lane_windows_environment_entry(
  moonbit_string_t key,
  moonbit_string_t value
) {
  int32_t key_length = Moonbit_array_length(key);
  int32_t value_length = Moonbit_array_length(value);
  size_t length = (size_t)key_length + (size_t)value_length + 1;
  wchar_t *entry = (wchar_t *)malloc((length + 1) * sizeof(wchar_t));
  if (entry == NULL) {
    return NULL;
  }
  for (int32_t index = 0; index < key_length; ++index) {
    entry[index] = (wchar_t)key[index];
  }
  entry[key_length] = L'=';
  for (int32_t index = 0; index < value_length; ++index) {
    entry[key_length + 1 + index] = (wchar_t)value[index];
  }
  entry[length] = L'\0';
  return entry;
}

static int lane_compare_environment_entries(const void *left, const void *right) {
  const wchar_t *const *left_entry = (const wchar_t *const *)left;
  const wchar_t *const *right_entry = (const wchar_t *const *)right;
  return _wcsicmp(*left_entry, *right_entry);
}

static wchar_t *lane_windows_environment(
  moonbit_string_t *keys,
  moonbit_string_t *values,
  int inherit_environment
) {
  int32_t extra_count = Moonbit_array_length(keys);
  size_t effective_extra_count = 0;
  for (int32_t index = 0; index < extra_count; ++index) {
    if (!lane_windows_key_is_shadowed(keys, extra_count, index)) {
      effective_extra_count += 1;
    }
  }
  wchar_t *inherited = inherit_environment ? GetEnvironmentStringsW() : NULL;
  if (inherit_environment && inherited == NULL) {
    return NULL;
  }
  size_t inherited_count = 0;
  if (inherited != NULL) {
    for (const wchar_t *entry = inherited; *entry != L'\0'; entry += wcslen(entry) + 1) {
      int replaced = 0;
      for (int32_t index = 0; index < extra_count; ++index) {
        if (lane_windows_environment_key_equal(entry, keys[index])) {
          replaced = 1;
          break;
        }
      }
      if (!replaced) {
        inherited_count += 1;
      }
    }
  }
  size_t count = inherited_count + effective_extra_count;
  wchar_t **entries = (wchar_t **)calloc(count == 0 ? 1 : count, sizeof(wchar_t *));
  if (entries == NULL) {
    if (inherited != NULL) {
      FreeEnvironmentStringsW(inherited);
    }
    return NULL;
  }
  size_t cursor = 0;
  if (inherited != NULL) {
    for (const wchar_t *entry = inherited; *entry != L'\0'; entry += wcslen(entry) + 1) {
      int replaced = 0;
      for (int32_t index = 0; index < extra_count; ++index) {
        if (lane_windows_environment_key_equal(entry, keys[index])) {
          replaced = 1;
          break;
        }
      }
      if (!replaced) {
        size_t length = wcslen(entry);
        entries[cursor] = (wchar_t *)malloc((length + 1) * sizeof(wchar_t));
        if (entries[cursor] == NULL) {
          goto failure;
        }
        memcpy(entries[cursor], entry, (length + 1) * sizeof(wchar_t));
        cursor += 1;
      }
    }
  }
  for (int32_t index = 0; index < extra_count; ++index) {
    if (lane_windows_key_is_shadowed(keys, extra_count, index)) {
      continue;
    }
    entries[cursor] = lane_windows_environment_entry(keys[index], values[index]);
    if (entries[cursor] == NULL) {
      goto failure;
    }
    cursor += 1;
  }
  qsort(entries, count, sizeof(wchar_t *), lane_compare_environment_entries);
  size_t units = count == 0 ? 2 : 1;
  for (size_t index = 0; index < count; ++index) {
    units += wcslen(entries[index]) + 1;
  }
  wchar_t *block = (wchar_t *)malloc(units * sizeof(wchar_t));
  if (block == NULL) {
    goto failure;
  }
  wchar_t *destination = block;
  for (size_t index = 0; index < count; ++index) {
    size_t length = wcslen(entries[index]) + 1;
    memcpy(destination, entries[index], length * sizeof(wchar_t));
    destination += length;
  }
  *destination = L'\0';
  if (count == 0) {
    destination[1] = L'\0';
  }
  for (size_t index = 0; index < count; ++index) {
    free(entries[index]);
  }
  free(entries);
  if (inherited != NULL) {
    FreeEnvironmentStringsW(inherited);
  }
  return block;

failure:
  for (size_t index = 0; index < count; ++index) {
    free(entries[index]);
  }
  free(entries);
  if (inherited != NULL) {
    FreeEnvironmentStringsW(inherited);
  }
  return NULL;
}

MOONBIT_FFI_EXPORT
void lane_run_command(
  moonbit_string_t executable,
  moonbit_string_t *arguments,
  moonbit_string_t working_directory,
  int32_t has_working_directory,
  moonbit_string_t *environment_keys,
  moonbit_string_t *environment_values,
  int32_t inherit_environment,
  int32_t *outcome
) {
  struct lane_wide_builder command_line = {0};
  if (!lane_append_windows_argument(&command_line, executable)) {
    lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, ERROR_NOT_ENOUGH_MEMORY);
    return;
  }
  int32_t argument_count = Moonbit_array_length(arguments);
  for (int32_t index = 0; index < argument_count; ++index) {
    if (!lane_wide_push(&command_line, L' ') ||
        !lane_append_windows_argument(&command_line, arguments[index])) {
      free(command_line.data);
      lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, ERROR_NOT_ENOUGH_MEMORY);
      return;
    }
  }
  wchar_t *directory = has_working_directory ? lane_copy_wide(working_directory) : NULL;
  wchar_t *environment = lane_windows_environment(
    environment_keys,
    environment_values,
    inherit_environment
  );
  if ((has_working_directory && directory == NULL) || environment == NULL) {
    free(command_line.data);
    free(directory);
    free(environment);
    lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, ERROR_NOT_ENOUGH_MEMORY);
    return;
  }
  STARTUPINFOW startup = {0};
  PROCESS_INFORMATION process = {0};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESTDHANDLES;
  startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
  startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
  BOOL created = CreateProcessW(
    NULL,
    command_line.data,
    NULL,
    NULL,
    TRUE,
    CREATE_UNICODE_ENVIRONMENT,
    environment,
    directory,
    &startup,
    &process
  );
  DWORD error = created ? ERROR_SUCCESS : GetLastError();
  free(command_line.data);
  free(directory);
  free(environment);
  if (!created) {
    if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
      lane_command_result(outcome, LANE_COMMAND_NOT_FOUND, (int32_t)error);
    } else if (error == ERROR_ACCESS_DENIED) {
      lane_command_result(outcome, LANE_COMMAND_PERMISSION_DENIED, (int32_t)error);
    } else {
      lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, (int32_t)error);
    }
    return;
  }
  DWORD wait_result = WaitForSingleObject(process.hProcess, INFINITE);
  if (wait_result == WAIT_FAILED) {
    error = GetLastError();
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, (int32_t)error);
    return;
  }
  DWORD exit_code = 0;
  if (!GetExitCodeProcess(process.hProcess, &exit_code)) {
    error = GetLastError();
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, (int32_t)error);
    return;
  }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  lane_command_result(outcome, LANE_COMMAND_EXITED, (int32_t)exit_code);
}

#else

#include <errno.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

extern int32_t moonbit_utf8_len_from_utf16(
  moonbit_string_t source,
  int32_t offset,
  int32_t length
);

extern int32_t moonbit_utf8_encode_from_utf16(
  moonbit_string_t source,
  int32_t source_offset,
  int32_t source_length,
  moonbit_bytes_t destination,
  int32_t destination_offset
);

static char *lane_copy_utf8(moonbit_string_t source) {
  int32_t source_length = Moonbit_array_length(source);
  int32_t length = moonbit_utf8_len_from_utf16(source, 0, source_length);
  char *copy = (char *)malloc((size_t)length + 1);
  if (copy == NULL) {
    return NULL;
  }
  moonbit_utf8_encode_from_utf16(
    source,
    0,
    source_length,
    (moonbit_bytes_t)copy,
    0
  );
  copy[length] = '\0';
  return copy;
}

static size_t lane_environment_key_length(const char *entry) {
  const char *separator = strchr(entry, '=');
  return separator == NULL ? strlen(entry) : (size_t)(separator - entry);
}

static int lane_environment_key_equal(const char *entry, const char *key) {
  size_t entry_length = lane_environment_key_length(entry);
  size_t key_length = strlen(key);
  return entry_length == key_length && memcmp(entry, key, key_length) == 0;
}

static int lane_environment_key_is_shadowed(
  char **keys,
  int32_t count,
  int32_t index
) {
  for (int32_t later = index + 1; later < count; ++later) {
    if (strcmp(keys[index], keys[later]) == 0) {
      return 1;
    }
  }
  return 0;
}

static char **lane_build_environment(
  moonbit_string_t *keys,
  moonbit_string_t *values,
  int inherit_environment,
  char ***allocated_entries,
  size_t *allocated_count
) {
  int32_t extra_count = Moonbit_array_length(keys);
  char **extra_keys = (char **)calloc(extra_count == 0 ? 1 : (size_t)extra_count, sizeof(char *));
  char **extra_entries = (char **)calloc(extra_count == 0 ? 1 : (size_t)extra_count, sizeof(char *));
  if (extra_keys == NULL || extra_entries == NULL) {
    free(extra_keys);
    free(extra_entries);
    return NULL;
  }
  for (int32_t index = 0; index < extra_count; ++index) {
    extra_keys[index] = lane_copy_utf8(keys[index]);
    char *value = lane_copy_utf8(values[index]);
    if (extra_keys[index] == NULL || value == NULL) {
      free(value);
      goto failure;
    }
    size_t key_length = strlen(extra_keys[index]);
    size_t value_length = strlen(value);
    extra_entries[index] = (char *)malloc(key_length + value_length + 2);
    if (extra_entries[index] == NULL) {
      free(value);
      goto failure;
    }
    memcpy(extra_entries[index], extra_keys[index], key_length);
    extra_entries[index][key_length] = '=';
    memcpy(extra_entries[index] + key_length + 1, value, value_length + 1);
    free(value);
  }
  size_t inherited_count = 0;
  if (inherit_environment) {
    for (char **entry = environ; *entry != NULL; ++entry) {
      int replaced = 0;
      for (int32_t index = 0; index < extra_count; ++index) {
        if (lane_environment_key_equal(*entry, extra_keys[index])) {
          replaced = 1;
          break;
        }
      }
      if (!replaced) {
        inherited_count += 1;
      }
    }
  }
  size_t effective_extra_count = 0;
  for (int32_t index = 0; index < extra_count; ++index) {
    if (!lane_environment_key_is_shadowed(extra_keys, extra_count, index)) {
      effective_extra_count += 1;
    }
  }
  char **environment = (char **)malloc(
    (inherited_count + effective_extra_count + 1) * sizeof(char *)
  );
  if (environment == NULL) {
    goto failure;
  }
  size_t cursor = 0;
  if (inherit_environment) {
    for (char **entry = environ; *entry != NULL; ++entry) {
      int replaced = 0;
      for (int32_t index = 0; index < extra_count; ++index) {
        if (lane_environment_key_equal(*entry, extra_keys[index])) {
          replaced = 1;
          break;
        }
      }
      if (!replaced) {
        environment[cursor++] = *entry;
      }
    }
  }
  for (int32_t index = 0; index < extra_count; ++index) {
    if (!lane_environment_key_is_shadowed(extra_keys, extra_count, index)) {
      environment[cursor++] = extra_entries[index];
    }
  }
  environment[cursor] = NULL;
  for (int32_t index = 0; index < extra_count; ++index) {
    free(extra_keys[index]);
  }
  free(extra_keys);
  *allocated_entries = extra_entries;
  *allocated_count = (size_t)extra_count;
  return environment;

failure:
  for (int32_t index = 0; index < extra_count; ++index) {
    free(extra_keys[index]);
    free(extra_entries[index]);
  }
  free(extra_keys);
  free(extra_entries);
  return NULL;
}

static void lane_free_environment_entries(char **entries, size_t count) {
  if (entries == NULL) {
    return;
  }
  for (size_t index = 0; index < count; ++index) {
    free(entries[index]);
  }
  free(entries);
}

MOONBIT_FFI_EXPORT
void lane_run_command(
  moonbit_string_t executable,
  moonbit_string_t *arguments,
  moonbit_string_t working_directory,
  int32_t has_working_directory,
  moonbit_string_t *environment_keys,
  moonbit_string_t *environment_values,
  int32_t inherit_environment,
  int32_t *outcome
) {
  char *program = lane_copy_utf8(executable);
  char *directory = has_working_directory ? lane_copy_utf8(working_directory) : NULL;
  int32_t argument_count = Moonbit_array_length(arguments);
  char **argv = (char **)calloc((size_t)argument_count + 2, sizeof(char *));
  char **allocated_environment = NULL;
  size_t allocated_environment_count = 0;
  char **environment = lane_build_environment(
    environment_keys,
    environment_values,
    inherit_environment,
    &allocated_environment,
    &allocated_environment_count
  );
  if (program == NULL || (has_working_directory && directory == NULL) ||
      argv == NULL || environment == NULL) {
    lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, ENOMEM);
    goto cleanup;
  }
  argv[0] = program;
  for (int32_t index = 0; index < argument_count; ++index) {
    argv[index + 1] = lane_copy_utf8(arguments[index]);
    if (argv[index + 1] == NULL) {
      lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, ENOMEM);
      goto cleanup;
    }
  }
  posix_spawn_file_actions_t actions;
  int error = posix_spawn_file_actions_init(&actions);
  if (error != 0) {
    lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, error);
    goto cleanup;
  }
  if (directory != NULL) {
#if defined(__APPLE__)
    error = posix_spawn_file_actions_addchdir(&actions, directory);
#else
    error = posix_spawn_file_actions_addchdir_np(&actions, directory);
#endif
  }
  pid_t pid = 0;
  if (error == 0) {
    error = posix_spawnp(&pid, program, &actions, NULL, argv, environment);
  }
  posix_spawn_file_actions_destroy(&actions);
  if (error != 0) {
    if (error == ENOENT || error == ENOTDIR) {
      lane_command_result(outcome, LANE_COMMAND_NOT_FOUND, error);
    } else if (error == EACCES || error == EPERM) {
      lane_command_result(outcome, LANE_COMMAND_PERMISSION_DENIED, error);
    } else {
      lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, error);
    }
    goto cleanup;
  }
  int status = 0;
  while (waitpid(pid, &status, 0) < 0) {
    if (errno != EINTR) {
      lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, errno);
      goto cleanup;
    }
  }
  if (WIFEXITED(status)) {
    lane_command_result(outcome, LANE_COMMAND_EXITED, WEXITSTATUS(status));
  } else if (WIFSIGNALED(status)) {
    lane_command_result(outcome, LANE_COMMAND_SIGNALED, WTERMSIG(status));
  } else {
    lane_command_result(outcome, LANE_COMMAND_SYSTEM_FAILURE, ECHILD);
  }

cleanup:
  if (argv != NULL) {
    for (int32_t index = 1; index <= argument_count; ++index) {
      free(argv[index]);
    }
  }
  free(argv);
  free(program);
  free(directory);
  free(environment);
  lane_free_environment_entries(
    allocated_environment,
    allocated_environment_count
  );
}

#endif
