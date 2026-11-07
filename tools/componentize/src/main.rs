fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().collect();
    if args.len()!=3 {return Err("Usage: cosmic-componentize CORE.wasm COMPONENT.wasm".into());}
    let core=std::fs::read(&args[1])?;
    let component=wit_component::ComponentEncoder::default().module(&core)?.validate(true).encode()?;
    std::fs::write(&args[2],component)?;
    println!("Validated WebAssembly component: {}",args[2]);
    Ok(())
}
