///|
let transfer_start : Int = 1048576

///|
let transfer_size : Int = 65536

///|
pub fn transfer_ptr() -> Int {
  transfer_start
}

///|
pub fn transfer_capacity() -> Int {
  transfer_size
}

///|
pub fn explore() -> Int {
  let request = match read_request() {
    Ok(request) => request
    Err(reason) =>
      return write_response(
        invalid_request_response(reason).stringify(),
        status_invalid_request,
      )
  }
  let result = explore_request(request)
  write_response(result.json, result.status)
}

///|
pub fn entries() -> Int {
  let request = match read_request() {
    Ok(request) => request
    Err(reason) =>
      return write_response(
        invalid_request_response(reason).stringify(),
        status_invalid_request,
      )
  }
  let result = entries_request(request)
  write_response(result.json, result.status)
}

///|
fn read_request() -> Result[String, String] {
  let length = host_request_length()
  if length < 0 {
    return Err("request length must not be negative")
  }
  let request_bytes : Array[Byte] = []
  let mut offset = 0
  while offset < length {
    let capacity = if length - offset < transfer_size {
      length - offset
    } else {
      transfer_size
    }
    let read = host_request_read(offset, transfer_start, capacity)
    if read <= 0 || read > capacity {
      return Err("request stream ended before the declared length")
    }
    for index in 0..<read {
      request_bytes.push(wasm_load_u8(transfer_start + index).to_byte())
    }
    offset += read
  }
  Ok(@utf8.decode(Bytes::from_array(request_bytes))) catch {
    _ => Err("request bytes must be valid UTF-8")
  }
}

///|
fn write_response(output : String, status : Int) -> Int {
  let output_bytes = @utf8.encode(output)
  if host_response_begin(output_bytes.length()) != 0 {
    return status_transport_error
  }
  let mut offset = 0
  while offset < output_bytes.length() {
    let length = if output_bytes.length() - offset < transfer_size {
      output_bytes.length() - offset
    } else {
      transfer_size
    }
    for index in 0..<length {
      wasm_store_u8(
        transfer_start + index,
        output_bytes[offset + index].to_int(),
      )
    }
    if host_response_write(offset, transfer_start, length) != length {
      return status_transport_error
    }
    offset += length
  }
  status
}

///|
fn host_request_length() -> Int = "lane.explorer" "request_length"

///|
fn host_request_read(offset : Int, ptr : Int, capacity : Int) -> Int = "lane.explorer" "request_read"

///|
fn host_response_begin(length : Int) -> Int = "lane.explorer" "response_begin"

///|
fn host_response_write(offset : Int, ptr : Int, length : Int) -> Int = "lane.explorer" "response_write"

///|
extern "wasm" fn wasm_load_u8(ptr : Int) -> Int =
  #|(func (param i32) (result i32)
  #|  (i32.load8_u (local.get 0)))

///|
extern "wasm" fn wasm_store_u8(ptr : Int, value : Int) -> Unit =
  #|(func (param i32 i32)
  #|  (i32.store8 (local.get 0) (local.get 1)))
