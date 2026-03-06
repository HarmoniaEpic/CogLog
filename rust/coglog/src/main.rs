//! CogLog CLI v0.9.1
//!
//! Usage:
//!   coglog-cli read
//!   echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | coglog-cli write
//!   coglog-cli clear

use coglog_core::{default_coglog_dir, Error, CogLog, WriteArgs};
use std::io::Read;
use std::path::PathBuf;
use std::process;

fn print_usage() {
    print!(
        "usage: coglog-cli <read|write|clear>\n\
         \n\
         \x20 read    — display the previous turn's coglog\n\
         \x20 write   — save current turn (reads JSON from stdin)\n\
         \x20 clear   — reset coglog\n\
         \n\
         write expects JSON on stdin (all fields required):\n\
         \x20 {{\n\
         \x20   \"user\": \"user's message\",\n\
         \x20   \"thinking\": \"AI thinking process\",\n\
         \x20   \"assistant\": \"AI output\",\n\
         \x20   \"current_focus\": \"what is happening right now\",\n\
         \x20   \"theory_of_mind\": \"user intent/state inference\",\n\
         \x20   \"self_narrative\": \"improvised self-story at this moment\",\n\
         \x20   \"annotation\": \"note to future self\"\n\
         \x20 }}\n\
         \n\
         \x20 fact layer (user, thinking, assistant): non-empty string required\n\
         \x20 interpretation layer (current_focus, theory_of_mind,\n\
         \x20   self_narrative, annotation): string required, empty string acceptable\n"
    );
}

fn run() -> Result<(), Error> {
    let mut args: Vec<String> = std::env::args().collect();

    // --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
    let ml = if args.len() >= 3 && args[1] == "--coglog-dir" {
        let dir = PathBuf::from(&args[2]);
        args.remove(1);
        args.remove(1);
        CogLog::with_dir(dir)
    } else {
        CogLog::new()
    };

    if args.len() < 2 {
        print_usage();
        return Ok(());
    }

    match args[1].as_str() {
        "read" => {
            match ml.read()? {
                Some(entry) => {
                    let json = serde_json::to_string_pretty(&entry)?;
                    println!("{}", json);
                }
                None => {
                    println!("(no coglog found)");
                }
            }
        }
        "write" => {
            let mut input = String::new();
            std::io::stdin().read_to_string(&mut input)?;
            let write_args: WriteArgs = serde_json::from_str(&input)?;
            let entry = ml.write(write_args)?;
            println!("coglog: turn {} written", entry.turn_id);
        }
        "clear" => {
            let result = ml.clear()?;
            if result.cleared {
                println!("coglog: cleared");
            } else if let Some(reason) = &result.reason {
                println!("coglog: {}", reason);
            }
        }
        _ => {
            print_usage();
            process::exit(1);
        }
    }

    Ok(())
}

fn main() {
    if let Err(e) = run() {
        eprintln!("coglog error: {}", e);
        process::exit(1);
    }
}
