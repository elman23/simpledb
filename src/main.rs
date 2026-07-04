/******************************************************************************
 * simpledb
 *
 * A minimal JSON-based command-line database utility ported in Rust.
 * Inspired by: https://github.com/Baeldung/posts-resources/tree/main/linux-articles/simpledb
 *
 * To compile:
 *     cargo build
 * This produces the executable target/debug/simpledb.
 *
 * Usage:
 *     ./target/debug/simpledb --db-path <PATH> list <table>
 *     ./target/debug/simpledb --db-path <PATH> get <table> field=value
 *     ./target/debug/simpledb --db-path <PATH> save <table> field1=value1 field2=value2 ...
 *     ./target/debug/simpledb --db-path <PATH> delete <table> field=value
 *
 ******************************************************************************/

use commands::{command_delete, command_get, command_list, command_save};
use constants::MAX_COMMAND_ARGS;
use std::path::Path;
use std::{env, process::exit};
use utils::print_usage;
mod commands;
mod constants;
mod structs;
mod utils;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();

    // for (i, arg) in args.iter().enumerate().skip(1) {
    //     println!("Argument {}: {}", i, arg);
    // }

    let program_name = &args[0];

    if args.len() < 4 {
        print_usage(program_name)?;
    }

    let mut db_path: Option<&str> = None;
    let mut command: Option<&str> = None;
    let mut table_name: Option<&str> = None;

    let mut command_args: [Option<&str>; MAX_COMMAND_ARGS] = [None; MAX_COMMAND_ARGS];
    let mut command_args_count: usize = 0;

    let mut i = 1;
    while i < args.len() {
        let arg = &args[i];
        if arg == "--db-path" || arg == "-d" {
            if i + 1 < args.len() {
                i = i + 1;
                db_path = Some(&args[i]);
                continue;
            } else {
                eprintln!("Error: --db-path requires an argument\n");
                exit(1);
            }
        } else {
            i = i + 1;
            command = Some(&args[i]);
            break;
        }
    }
    i = i + 1;

    if db_path.is_none() || command.is_none() {
        print_usage(program_name)?;
    }

    if i < args.len() {
        table_name = Some(&args[i]);
        i = i + 1;
    } else {
        print_usage(program_name)?;
    }

    let Some(db_path) = db_path else {
        return print_usage(program_name);
    };
    let Some(table_name) = table_name else {
        return print_usage(program_name);
    };
    let Some(command) = command else {
        return print_usage(program_name);
    };

    while i < args.len() && command_args_count < MAX_COMMAND_ARGS {
        command_args[command_args_count] = Some(&args[i]);
        command_args_count = command_args_count + 1;
        i = i + 1;
    }
    let path = Path::new(db_path);
    if !path.is_dir() {
        eprintln!("Error: Database path {} is not a directory.", db_path);
        exit(1);
    }

    // println!("Command: {}", command);
    // println!("DB path: {}", db_path);
    // println!("Table name: {}", table_name);

    match command {
        "list" => {
            if command_args_count != 0 {
                return print_usage(program_name);
            }
            command_list(db_path, table_name)
        }
        "get" => {
            if command_args_count != 1 {
                return print_usage(program_name);
            }
            let first_command_arg = command_args[0].ok_or("First argument is null")?;
            let Some((field, value)) = first_command_arg.split_once('=') else {
                eprintln!(
                    "Error: Invalid get argument '{}'. Use <field>=<value>.",
                    first_command_arg
                );
                exit(1);
            };
            command_get(db_path, table_name, field, value)
        }
        "save" => {
            if command_args_count < 1 {
                return print_usage(program_name);
            }
            command_save(db_path, table_name, command_args_count, command_args)
        }
        "delete" => {
            if command_args_count != 1 {
                return print_usage(program_name);
            }
            let first_command_arg = command_args[0].ok_or("First argument is null")?;
            let Some((field, value)) = first_command_arg.split_once('=') else {
                eprintln!(
                    "Error: Invalid get argument '{}'. Use <field>=<value>.",
                    first_command_arg
                );
                exit(1);
            };
            command_delete(db_path, table_name, field, value)
        }
        _ => Err(format!("Error: Unknown command '{}'", command).into()),
    }
}
