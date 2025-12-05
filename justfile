# kompressor justfile
# Compress DEM GeoTIFF files in parallel

# Default recipe shows help
default:
    @just --list

# Compress GeoTIFF files from input_dir to output_dir
# Usage: just compress input_dir output_dir [ARGS...]
compress input_dir output_dir *ARGS:
    ./compress.sh "{{input_dir}}" "{{output_dir}}" {{ARGS}}

# Show compression help
help:
    ./compress.sh --help

# Dry-run compression (show what would be done)
dry-run input_dir output_dir *ARGS:
    ./compress.sh "{{input_dir}}" "{{output_dir}}" --dry-run {{ARGS}}

# Compress with LZW compression
compress-lzw input_dir output_dir *ARGS:
    ./compress.sh "{{input_dir}}" "{{output_dir}}" --compression-type LZW {{ARGS}}

# Compress with DEFLATE compression
compress-deflate input_dir output_dir *ARGS:
    ./compress.sh "{{input_dir}}" "{{output_dir}}" --compression-type DEFLATE {{ARGS}}

# Compress with LERC_ZSTD (optimal for DEM data)
compress-lerc input_dir output_dir *ARGS:
    ./compress.sh "{{input_dir}}" "{{output_dir}}" --compression-type LERC_ZSTD {{ARGS}}

# Check if required tools are installed
check-deps:
    #!/usr/bin/env bash
    echo "Checking dependencies..."
    echo -n "just: "
    if command -v just &> /dev/null; then echo "✓ installed"; else echo "✗ not found"; fi
    echo -n "gdal_translate: "
    if command -v gdal_translate &> /dev/null; then echo "✓ installed"; else echo "✗ not found"; fi
    echo -n "parallel: "
    if command -v parallel &> /dev/null; then echo "✓ installed"; else echo "✗ not found"; fi
