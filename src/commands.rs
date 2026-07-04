use crate::{
    constants::MAX_COMMAND_ARGS,
    structs::FieldPair,
    utils::{self, load_table, save_table},
};

pub fn command_list(db_path: &str, table_name: &str) -> Result<(), Box<dyn std::error::Error>> {
    let json: serde_json::Value = utils::load_table(db_path, table_name);
    println!("{}", serde_json::to_string_pretty(&json)?);
    Ok(())
}

pub fn command_get(
    db_path: &str,
    table_name: &str,
    field: &str,
    value: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let json: serde_json::Value = utils::load_table(db_path, table_name);
    let rows: Vec<&serde_json::Value> = json
        .as_array()
        .ok_or("Rows are not an array")?
        .iter()
        .filter(|item| item.get(field).and_then(|v| v.as_str()) == Some(value))
        .collect();
    for row in rows {
        println!("{}", row);
    }
    Ok(())
}

fn generate_new_id(json: &serde_json::Value) -> Result<String, Box<dyn std::error::Error>> {
    let mut max_id: u64 = 0;
    let size = (*json.as_array().ok_or("JSON is not an array")?).len();
    for i in 1..size {
        let item = &json[i];
        if item.is_object() {
            let value: u64 = item["id"].as_u64().unwrap_or(0);
            if value > max_id {
                max_id = value;
            }
        }
    }
    max_id = max_id + 1;
    Ok(max_id.to_string())
}

pub fn command_save(
    db_path: &str,
    table_name: &str,
    command_args_count: usize,
    command_args: [Option<&str>; MAX_COMMAND_ARGS],
) -> Result<(), Box<dyn std::error::Error>> {
    let mut json = load_table(db_path, table_name);
    let mut fields: [Option<FieldPair>; MAX_COMMAND_ARGS] = [None; MAX_COMMAND_ARGS];
    let mut field_count: usize = 0;
    let mut user_provided_id: bool = false;
    let mut user_id_value = 0;
    for i in 0..command_args_count {
        let buffer = command_args[i].ok_or("Command arg is not defined")?;
        let splitted = buffer.split_once("=");
        let Some((key, value)) = splitted else {
            eprintln!(
                "Error: Invalid field format '{}'. Use <field>=<value>.",
                buffer
            );
            std::process::exit(1);
        };
        fields[field_count] = Some(FieldPair::new(key, value));
        field_count = field_count + 1;

        if key == "id" {
            user_provided_id = true;
            let value_as_u64 = match value.parse::<u64>() {
                Ok(v) => v,
                Err(_) => {
                    return Err(
                        format!("Error: 'id' must be a positive integer, got '{}'", value).into(),
                    );
                }
            };
            user_id_value = value_as_u64;
        }
    }
    let auto_id_buffer: String;
    let final_id_str: Option<String>;

    if user_provided_id {
        auto_id_buffer = user_id_value.to_string();
        final_id_str = Some(auto_id_buffer);
    } else {
        let generated = generate_new_id(&json);
        match generated {
            Ok(s) => {
                final_id_str = Some(s);
            }
            Err(_) => {
                eprintln!("Error: Unable to generate new ID.");
                std::process::exit(1);
            }
        }
    }
    let mut new_record = serde_json::Value::from({});
    new_record["id"] = serde_json::from_str(&final_id_str.ok_or("ID not string")?)?;

    for i in 0..field_count {
        let field = fields[i].ok_or("Invalid field")?;
        if field.key() == "id" {
            continue;
        }
        new_record[field.key()] = serde_json::from_str(field.value())
            .unwrap_or_else(|_| serde_json::Value::String(field.value().to_owned()));
    }

    let mut existing_record: Option<&mut serde_json::Value> = None;

    let new_id = &new_record["id"];

    if let Some(array) = json.as_array_mut() {
        for item in array {
            if item["id"] == *new_id {
                existing_record = Some(item);
                break;
            }
        }
    }

    let record_to_print = if let Some(existing_value) = existing_record {
        if let (Some(existing), Some(new)) =
            (existing_value.as_object_mut(), new_record.as_object())
        {
            for (key, value) in new {
                existing.insert(key.clone(), value.clone());
            }
        }
        existing_value.clone()
    } else {
        if let Some(array) = json.as_array_mut() {
            array.push(new_record.clone());
        }
        new_record
    };

    save_table(db_path, table_name, json)?;

    println!("{}", record_to_print);

    Ok(())
}

pub fn command_delete(
    db_path: &str,
    table_name: &str,
    field: &str,
    value: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let json: serde_json::Value = utils::load_table(db_path, table_name);

    if !json.is_array() {
        return Err("Table JSON is not an array".into());
    }

    let rows: Vec<&serde_json::Value> = json
        .as_array()
        .ok_or("Rows are not an array")?
        .iter()
        .filter(|item| item.get(field).and_then(|v| v.as_str()) != Some(value))
        .collect();
    let deleted_count: usize = rows.len();

    let json_array: serde_json::Value = rows
        .into_iter()
        .cloned()
        .collect::<Vec<serde_json::Value>>()
        .into();

    utils::save_table(db_path, table_name, json_array)?;

    println!("Deleted {} record(s)", deleted_count);
    Ok(())
}
