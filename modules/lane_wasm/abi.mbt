///|
let arena_start : Int = 1048576

///|
let arena_size : Int = 15728640

///|
let arena_end : Int = arena_start + arena_size

///|
let arena_state : Array[Int] = [arena_start, 0, 0]

///|
fn arena_next() -> Int {
  arena_state[0]
}

///|
pub fn arena_reset() -> Unit {
  arena_state[0] = arena_start
  arena_state[1] = 0
  arena_state[2] = 0
}

///|
pub fn arena_capacity() -> Int {
  arena_size
}

///|
pub fn arena_alloc(len : Int) -> Int {
  if len < 0 {
    return 0
  }
  let next = arena_next() + len
  if next > arena_end {
    0
  } else {
    let ptr = arena_next()
    arena_state[0] = next
    ptr
  }
}

///|
pub fn explore(input_ptr : Int, input_len : Int) -> Int {
  arena_state[1] = 0
  arena_state[2] = 0
  guard input_ptr >= arena_start &&
    input_len >= 0 &&
    input_ptr + input_len <= arena_end else {
    return status_invalid_request
  }
  let request_bytes : Array[Byte] = []
  for index = 0; index < input_len; index = index + 1 {
    request_bytes.push(wasm_load_u8(input_ptr + index).to_byte())
  }
  let request = @utf8.decode(Bytes::from_array(request_bytes)) catch {
    _ =>
      return write_output(
        invalid_request_response("request bytes must be valid UTF-8").stringify(),
        status_invalid_request,
      )
  }
  let result = explore_request(request)
  write_output(result.json, result.status)
}

///|
fn write_output(output : String, status : Int) -> Int {
  let output_bytes = @utf8.encode(output)
  let ptr = arena_alloc(output_bytes.length())
  if ptr == 0 {
    return status_overflow
  }
  let mut index = 0
  for byte in output_bytes {
    wasm_store_u8(ptr + index, byte.to_int())
    index = index + 1
  }
  arena_state[1] = ptr
  arena_state[2] = output_bytes.length()
  status
}

///|
pub fn last_result_ptr() -> Int {
  arena_state[1]
}

///|
pub fn last_result_len() -> Int {
  arena_state[2]
}

///|
extern "wasm" fn wasm_load_u8(ptr : Int) -> Int =
  #|(func (param i32) (result i32)
  #|  (i32.load8_u (local.get 0)))

///|
extern "wasm" fn wasm_store_u8(ptr : Int, value : Int) -> Unit =
  #|(func (param i32 i32)
  #|  (i32.store8 (local.get 0) (local.get 1)))
