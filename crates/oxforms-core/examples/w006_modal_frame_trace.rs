use std::error::Error;
use std::fs;
use std::path::{Path, PathBuf};

use oxforms_core::{build_w006_modal_frame_trace_subset_artifact, W006_MODAL_FRAME_TRACE_PATH};

fn main() -> Result<(), Box<dyn Error>> {
    let config = Config::from_args(std::env::args().skip(1))?;
    if config.help {
        print_help();
        return Ok(());
    }

    let artifact = build_w006_modal_frame_trace_subset_artifact();

    if config.print {
        print!("{artifact}");
    }

    if let Some(dir) = config.write_dir.as_deref() {
        fs::create_dir_all(dir)?;
        fs::write(dir.join(trace_file_name()), artifact.as_bytes())?;
        println!("Wrote W006 modal-frame trace artifact to {}", dir.display());
    }

    if config.check {
        assert_file_matches(W006_MODAL_FRAME_TRACE_PATH, &artifact)?;
        println!("W006 modal-frame trace check: ok");
        println!("Trace: {W006_MODAL_FRAME_TRACE_PATH}");
    }

    if !config.print && config.write_dir.is_none() && !config.check {
        print_help();
    }

    Ok(())
}

#[derive(Debug, Default)]
struct Config {
    check: bool,
    print: bool,
    write_dir: Option<PathBuf>,
    help: bool,
}

impl Config {
    fn from_args(args: impl IntoIterator<Item = String>) -> Result<Self, Box<dyn Error>> {
        let mut config = Self::default();
        let mut args = args.into_iter();

        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--check" => config.check = true,
                "--print" => config.print = true,
                "--write-dir" => {
                    let value = args.next().ok_or("--write-dir requires a directory")?;
                    config.write_dir = Some(PathBuf::from(value));
                }
                "--help" | "-h" => config.help = true,
                _ => return Err(format!("unknown argument: {arg}").into()),
            }
        }

        Ok(config)
    }
}

fn print_help() {
    println!(
        "Usage: cargo run -p oxforms-core --example w006_modal_frame_trace -- [--check] [--write-dir DIR] [--print]"
    );
}

fn assert_file_matches(repo_relative_path: &str, expected: &str) -> Result<(), Box<dyn Error>> {
    let full_path = repo_root().join(repo_relative_path);
    let actual = fs::read_to_string(&full_path)
        .map_err(|err| format!("read {}: {err}", full_path.display()))?;

    if actual != expected {
        return Err(format!(
            "trace artifact mismatch for {}; rerun with --write-dir and review the diff",
            repo_relative_path
        )
        .into());
    }

    Ok(())
}

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn trace_file_name() -> &'static str {
    Path::new(W006_MODAL_FRAME_TRACE_PATH)
        .file_name()
        .and_then(|name| name.to_str())
        .expect("W006 trace path should have a file name")
}
