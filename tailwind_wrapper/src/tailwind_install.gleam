//// Download Tailwind’s standalone CLI into a user-wide shared cache, then copy
//// into the project’s `build/bin/`. Skips work when the project binary or cache
//// file already exists.

import envoy
import filepath
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/http.{Get}
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import tom.{type Toml}

@external(erlang, "tailwind_wrapper_ffi", "absolute_path")
fn abs_path_ffi(relative: String) -> String

@external(erlang, "tailwind_wrapper_ffi", "os_arch")
fn os_arch_ffi() -> String

@external(erlang, "tailwind_wrapper_ffi", "os_platform")
fn os_platform_ffi() -> String

const config_path = "./gleam.toml"

fn cache_dir_root() -> Result(String, String) {
  case envoy.get("TAILWIND_WRAPPER_CACHE") {
    Ok(p) if p != "" -> Ok(string.trim(p))
    _ ->
      case os_platform_ffi() {
        "win32" ->
          case envoy.get("LOCALAPPDATA") {
            Ok(p) if p != "" -> Ok(filepath.join(p, "tailwind-wrapper"))
            _ -> Error("tailwind_wrapper: no LOCALAPPDATA, set TAILWIND_WRAPPER_CACHE")
          }
        _ ->
          case envoy.get("XDG_CACHE_HOME") {
            Ok(p) if p != "" -> Ok(filepath.join(p, "tailwind-wrapper"))
            _ ->
              case envoy.get("HOME") {
                Ok(h) if h != "" -> Ok(filepath.join(filepath.join(h, ".cache"), "tailwind-wrapper"))
                _ -> Error("tailwind_wrapper: no HOME, set TAILWIND_WRAPPER_CACHE or XDG_CACHE_HOME")
              }
          }
      }
  }
}

fn get_config() -> Result(Dict(String, Toml), String) {
  simplifile.read(config_path)
  |> result.map_error(fn(e) { "Error: couldn't read " <> config_path <> " " <> string.inspect(e) })
  |> result.try(fn(config) { tom.parse(config) |> result.replace_error("Error: couldn't parse gleam.toml.") })
}

/// `None` in the inner option means: use the latest release for download URL and cache under `latest/`.
fn tools_tailwind_version_option() -> Result(Option(String), String) {
  use parsed <- result.try(get_config())
  case tom.get_string(parsed, ["tools", "tailwind", "version"]) {
    Ok(v) -> Ok(Some(v))
    Error(_) -> {
      case tom.get_string(parsed, ["tailwind", "version"]) {
        Ok(v) -> Ok(Some(v))
        Error(_) -> Ok(None)
      }
    }
  }
}

fn version_cache_dir(version: Option(String)) -> String {
  case version {
    None -> "latest"
    Some(v) ->
      case v {
        "v" <> _ -> v
        _ -> "v" <> v
      }
  }
}

fn release_target() -> Result(String, String) {
  let os = os_platform_ffi()
  let arch = os_arch_ffi()
  case os {
    "win32" ->
      case arch {
        "x86_64" | "x64" -> Ok("windows-x64.exe")
        ar ->
          case string.starts_with(ar, "arm") {
            True -> Ok("windows-arm64.exe")
            False -> err_platform(os, ar)
          }
      }
    "darwin" ->
      case arch {
        "aarch64" -> Ok("macos-arm64")
        "x86_64" | "x64" -> Ok("macos-x64")
        ar ->
          case string.starts_with(ar, "arm") {
            True -> Ok("macos-arm64")
            False -> err_platform(os, ar)
          }
      }
    "linux" ->
      case arch {
        "aarch64" | "arm64" -> Ok("linux-arm64")
        "x86_64" | "x64" | "amd64" -> Ok("linux-x64")
        ar ->
          case string.starts_with(ar, "armv7") {
            True -> Ok("linux-armv7")
            False -> err_platform(os, ar)
          }
      }
    _ -> err_platform(os, arch)
  }
}

fn err_platform(os: String, ar: String) -> Result(String, String) {
  Error("Error: no Tailwind CLI build for " <> os <> " " <> ar)
}

fn github_path(version: Option(String), target: String) -> String {
  case version {
    None -> "/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-" <> target
    Some("v" <> v) ->
      "/tailwindlabs/tailwindcss/releases/download/v" <> v <> "/tailwindcss-" <> target
    Some(v) ->
      "/tailwindlabs/tailwindcss/releases/download/v" <> v <> "/tailwindcss-" <> target
  }
}

fn download_bin_to(path: String, github_rel: String) -> Result(Nil, String) {
  let req =
    request.new()
    |> request.set_method(Get)
    |> request.set_host("github.com")
    |> request.set_path(github_rel)
    |> request.map(bit_array.from_string)
  use resp <- result.try(
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.dispatch_bits(req)
    |> result.map_error(fn(e) { "Error: download failed " <> string.inspect(e) }),
  )
  use _ <- result.try(
    simplifile.write_bits(resp.body, to: path)
    |> result.map_error(fn(e) { "Error: write " <> path <> " " <> string.inspect(e) }),
  )
  Ok(Nil)
}

fn copy_bin(from: String, to: String) -> Result(Nil, String) {
  use bits <- result.try(
    simplifile.read_bits(from)
    |> result.map_error(fn(e) { "Error: read " <> from <> " " <> string.inspect(e) }),
  )
  use _ <- result.try(
    simplifile.write_bits(bits, to: to)
    |> result.map_error(fn(e) { "Error: write " <> to <> " " <> string.inspect(e) }),
  )
  Ok(Nil)
}

/// Idempotent: uses project `build/bin` if present; else user cache; else downloads.
pub fn install_cli(local_executable: String) -> Result(Nil, String) {
  case simplifile.is_file(local_executable) {
    Ok(True) -> {
      io.println(
        "tailwind_wrapper: Tailwind CLI already in project: "
        <> abs_path_ffi(local_executable),
      )
      Ok(Nil)
    }
    _ -> {
      use root <- result.try(cache_dir_root())
      use v_opt <- result.try(tools_tailwind_version_option())
      use t <- result.try(release_target())
      let vdir = version_cache_dir(v_opt)
      let file_name = "tailwindcss-" <> t
      let cache_path = filepath.join(root, filepath.join(vdir, file_name))
      case simplifile.is_file(cache_path) {
        Ok(True) -> {
          io.println(
            "tailwind_wrapper: using shared cache ("
            <> vdir
            <> ", "
            <> t
            <> "): "
            <> abs_path_ffi(cache_path),
          )
          ensure_with_copy(cache_path, local_executable)
        }
        _ -> {
          io.println(
            "tailwind_wrapper: no shared install at "
            <> abs_path_ffi(cache_path)
            <> ", downloading",
          )
          use _ <- result.try(
            simplifile.create_directory_all(filepath.directory_name(cache_path))
            |> result.map_error(string.inspect),
          )
          use _ <- result.try(download_bin_to(cache_path, github_path(v_opt, t)))
          use _ <- result.try(
            simplifile.set_permissions_octal(cache_path, 0o755)
            |> result.map_error(string.inspect),
          )
          ensure_with_copy(cache_path, local_executable)
        }
      }
    }
  }
}

fn ensure_with_copy(cached: String, local_executable: String) -> Result(Nil, String) {
  use _ <- result.try(
    simplifile.create_directory_all(filepath.directory_name(local_executable))
    |> result.map_error(string.inspect),
  )
  use _ <- result.try(copy_bin(cached, local_executable))
  use _ <- result.try(
    simplifile.set_permissions_octal(local_executable, 0o755)
    |> result.map_error(string.inspect),
  )
  io.println("tailwind_wrapper: installed project CLI: " <> abs_path_ffi(local_executable))
  Ok(Nil)
}
