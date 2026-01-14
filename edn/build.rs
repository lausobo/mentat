// Copyright 2016 Mozilla
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a copy of the
// License at http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

extern crate peg;

use std::env;
use std::fs::File;
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::process::exit;

fn main() {
    let input_path = Path::new("src/edn.rustpeg");
    if let Err(e) = build_with_ranges(input_path) {
        let mut stderr = io::stderr();
        writeln!(
            stderr,
            "Could not build PEG grammar `{}`: {}",
            input_path.display(),
            e
        )
        .ok();
        exit(1);
    }
}

fn build_with_ranges(input_path: &Path) -> io::Result<()> {
    let mut peg_source = String::new();
    File::open(input_path)?.read_to_string(&mut peg_source)?;
    println!("cargo:rerun-if-changed={}", input_path.display());

    let mut rust_source = match peg::compile(&peg_source) {
        Ok(source) => source,
        Err(e) => {
            return Err(io::Error::new(
                io::ErrorKind::Other,
                format!("Error compiling PEG grammar `{}`: {}", input_path.display(), e),
            ));
        }
    };

    // peg 0.5 emits deprecated `...` range patterns; normalize to `..=` for newer Rust editions.
    rust_source = rust_source.replace(" ... ", " ..= ");

    let out_dir: PathBuf = env::var_os("OUT_DIR").unwrap().into();
    let rust_path = out_dir.join(input_path.file_name().unwrap()).with_extension("rs");
    File::create(&rust_path)?.write_all(rust_source.as_bytes())?;

    Ok(())
}
