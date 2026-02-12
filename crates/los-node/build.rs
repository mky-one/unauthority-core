// Build script untuk compile protobuf definitions
// Runs automatically saat `cargo build`

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Compile los.proto ke Rust code
    tonic_build::configure()
        .build_server(true) // Generate server code
        .build_client(true) // Generate client code (for testing)
        .compile_protos(
            // Updated method name (not deprecated)
            &["../../los.proto"], // Proto file path
            &["../../"],          // Include directory
        )?;

    println!("cargo:rerun-if-changed=../../los.proto");

    Ok(())
}
