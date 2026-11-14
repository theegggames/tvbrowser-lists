// Compiles the downloaded filter lists into shields.dat (the serialized adblock-rust engine).
//   cargo run --release --bin build_shields -- <lists dir> <output shields.dat> [all|network]
use adblock::lists::{ParseOptions, RuleTypes, FilterSet};
use adblock::Engine;

fn main() {
    let a: Vec<String> = std::env::args().collect();
    if a.len() < 3 { eprintln!("usage: build_shields <lists dir> <out file> [all|network]"); std::process::exit(2); }
    let mode = a.get(3).map(|s| s.as_str()).unwrap_or("network");
    let mut opts = ParseOptions::default();
    opts.rule_types = if mode == "all" { RuleTypes::All } else { RuleTypes::NetworkOnly };
    let mut files: Vec<_> = std::fs::read_dir(&a[1]).expect("cannot read lists dir")
        .filter_map(|e| e.ok()).map(|e| e.path()).filter(|p| p.extension().map_or(false, |x| x == "txt")).collect();
    files.sort();
    let mut set = FilterSet::new(false);
    let mut lines = 0usize;
    for f in &files {
        let text = std::fs::read_to_string(f).unwrap_or_else(|e| panic!("cannot read {:?}: {}", f, e));
        lines += text.lines().count();
        set.add_filter_list(text, opts.clone());
    }
    let engine = Engine::new_with_filter_set(set);
    let data = engine.serialize();
    std::fs::write(&a[2], &data).expect("cannot write output");
    println!("built {} bytes from {} files, {} lines ({})", data.len(), files.len(), lines, mode);
}
