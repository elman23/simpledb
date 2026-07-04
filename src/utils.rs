use std::fs;
use std::fs::File;
use std::io;

use serde_json::json;

pub fn print_usage(program_name: &str) -> Result<(), Box<dyn std::error::Error>> {
    println!(
        "Usage:\n
{} --db-path <PATH> COMMAND [ARGS...]\n
Commands:
  list <table>
  get <table> field=value
  save <table> field1=value1 [field2=value2 ...]
  delete <table> field=value
\n
Options:
  --db-path <PATH>   Required. Path to the database directory.",
        program_name
    );
    Err("Incorrect program usage".into())
}

fn read_file(filename: &str) -> String {
    match fs::read_to_string(filename) {
        Ok(s) => s,
        Err(_) => {
            match File::create("my_file.txt") {
                Ok(_) => {}
                Err(e) => {
                    eprintln!("Unable to create the database: {}", e);
                }
            }
            "".to_string()
        }
    }
}

fn write_file_atomic(filename: &str, data: &str) -> io::Result<()> {
    let temp_filename = format!("{}.tmp", filename);
    fs::write(&temp_filename, data)?;
    fs::rename(&temp_filename, filename)
}

pub fn load_table(db_path: &str, table_name: &str) -> serde_json::Value {
    let filepath = format!("{}/{}.json", db_path, table_name);
    let content = read_file(&filepath);
    match serde_json::from_str(&content) {
        Ok(json) => json,
        Err(_) => {
            json!([])
        }
    }
}

pub fn save_table(db_path: &str, table_name: &str, json: serde_json::Value) -> io::Result<()> {
    let filepath = format!("{}/{}.json", db_path, table_name);
    let data = serde_json::to_string(&json)?;
    write_file_atomic(&filepath, &data)
}
