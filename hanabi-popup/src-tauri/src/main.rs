// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "hanabi-popup")]
#[command(about = "Hanabi Download Popup - Lightweight download dialog")]
struct Args {
    /// Download URL
    #[arg(short, long)]
    url: Option<String>,

    /// Filename (optional, will be parsed from URL if not provided)
    #[arg(short, long)]
    filename: Option<String>,

    /// Save path (optional)
    #[arg(short, long)]
    path: Option<String>,
}

fn main() {
    let args = Args::parse();
    app_lib::run(args.url, args.filename, args.path);
}
