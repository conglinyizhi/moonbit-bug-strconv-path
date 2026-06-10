fn main {
  let s = "42"
  let x = try { @strconv.parse_int(s) } catch { _ => 0 }
  println(x.to_string())
}
