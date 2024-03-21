// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

// Learn more about Tauri commands at https://tauri.app/v1/guides/features/command
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![greet])
        .setup(|app| {
            // I can decide at runtime whether to launch index.html or foo.html
            let url = if true { "foo.html" } else { "index.html" };
            let _main_window =
                tauri::WindowBuilder::new(app, "main", tauri::WindowUrl::App(url.into()))
                    .build()?;
            Ok(())
        })
        .run(tauri::generate_context!("tauri.conf.foo.json"))
        .expect("error while running tauri application");
}
