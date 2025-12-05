#!/bin/bash

# kompressor - Compress DEM GeoTIFF files in parallel
# Usage: ./compress.sh <input_dir> <output_dir> [options]

set -euo pipefail

# Default values
COMPRESSION_TYPE="ZSTD"
COMPRESSION_LEVEL="9"
DRY_RUN=false
PARALLEL_JOBS="+0"  # Use all available CPU cores

# Help text
show_help() {
    cat << EOF
Usage: $0 <input_dir> <output_dir> [options]

Compress GeoTIFF DEM files in parallel using GDAL.

Arguments:
  input_dir           Directory containing input GeoTIFF files
  output_dir          Directory to store compressed GeoTIFF files

Options:
  --compression-type TYPE   Compression algorithm to use (default: ZSTD)
                           Available: ZSTD, LZW, DEFLATE, LZMA, LERC_ZSTD
  --compression-level NUM   Compression level 1-9 (default: 9, best compression)
  --dry-run                Only show what would be done, don't compress
  --jobs NUM               Number of parallel jobs (default: all CPU cores)
  --help                   Show this help message

Examples:
  $0 input/ output/
  $0 input/ output/ --compression-type LZW
  $0 input/ output/ --dry-run
  $0 input/ output/ --compression-type ZSTD --compression-level 6 --jobs 8

Compression types:
  ZSTD        - Zstandard compression (best compression ratio, recommended)
  LZW         - Lempel-Ziv-Welch compression (good compatibility)
  DEFLATE     - Deflate compression (widely supported)
  LZMA        - LZMA compression (high compression, slower)
  LERC_ZSTD   - LERC + ZSTD for DEM data (optimal for elevation data)

EOF
    exit 0
}

# Check for help flag first
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
fi

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments"
    show_help
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"
shift 2

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        --compression-type)
            COMPRESSION_TYPE="$2"
            shift 2
            ;;
        --compression-level)
            COMPRESSION_LEVEL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate input directory
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory does not exist: $INPUT_DIR"
    exit 1
fi

# Check for required tools
if ! command -v gdal_translate &> /dev/null; then
    echo "Error: gdal_translate not found. Please install GDAL tools."
    echo "  Ubuntu/Debian: sudo apt-get install gdal-bin"
    echo "  macOS: brew install gdal"
    exit 1
fi

if ! command -v gdalinfo &> /dev/null; then
    echo "Error: gdalinfo not found. Please install GDAL tools."
    echo "  Ubuntu/Debian: sudo apt-get install gdal-bin"
    echo "  macOS: brew install gdal"
    exit 1
fi

if ! command -v parallel &> /dev/null; then
    echo "Error: GNU parallel not found. Please install parallel."
    echo "  Ubuntu/Debian: sudo apt-get install parallel"
    echo "  macOS: brew install parallel"
    exit 1
fi

# Function to compress a single GeoTIFF file
compress_geotiff() {
    local input_file="$1"
    local input_dir="$2"
    local output_dir="$3"
    local compression_type="$4"
    local compression_level="$5"
    local dry_run="$6"
    
    # Calculate relative path and output file path
    local relative_path="${input_file#$input_dir/}"
    local output_file="$output_dir/$relative_path"
    local output_subdir=$(dirname "$output_file")
    
    if [ "$dry_run" = true ]; then
        echo "[DRY-RUN] Would compress: $input_file -> $output_file"
        return 0
    fi
    
    # Create output subdirectory if it doesn't exist
    mkdir -p "$output_subdir"
    
    # Skip if output file already exists and is a valid GeoTIFF
    if [ -f "$output_file" ]; then
        # Check if the output file is a valid GeoTIFF
        if gdalinfo "$output_file" &> /dev/null; then
            echo "[SKIP] Already compressed: $relative_path"
            return 0
        else
            echo "[RECOMPRESS] Invalid GeoTIFF, recompressing: $relative_path"
        fi
    fi
    
    # Compress the file using gdal_translate
    # -co: Creation options for compression
    # -co COMPRESS: Compression algorithm
    # -co ZLEVEL or ZSTD_LEVEL: Compression level
    # -co PREDICTOR=2: Horizontal differencing predictor (good for DEM data)
    # -co TILED=YES: Create tiled TIFF for better performance
    # -co BIGTIFF=IF_SAFER: Use BigTIFF if needed
    
    local predictor_opt=()
    if [ "$compression_type" = "LZW" ] || [ "$compression_type" = "DEFLATE" ]; then
        predictor_opt=(-co PREDICTOR=2)
    fi
    
    local level_opt=()
    if [ "$compression_type" = "ZSTD" ]; then
        level_opt=(-co ZSTD_LEVEL="$compression_level")
    elif [ "$compression_type" = "DEFLATE" ] || [ "$compression_type" = "LZMA" ] || [ "$compression_type" = "LZW" ]; then
        level_opt=(-co ZLEVEL="$compression_level")
    elif [ "$compression_type" = "LERC_ZSTD" ]; then
        level_opt=(-co ZSTD_LEVEL="$compression_level")
    fi
    
    # Build gdal_translate command with optional arguments
    local gdal_cmd=(gdal_translate -q -co COMPRESS="$compression_type")
    
    if [ ${#level_opt[@]} -gt 0 ]; then
        gdal_cmd+=("${level_opt[@]}")
    fi
    
    if [ ${#predictor_opt[@]} -gt 0 ]; then
        gdal_cmd+=("${predictor_opt[@]}")
    fi
    
    gdal_cmd+=(-co TILED=YES -co BIGTIFF=IF_SAFER "$input_file" "$output_file")
    
    if "${gdal_cmd[@]}" 2>/dev/null; then
        echo "[OK] Compressed: $relative_path"
    else
        echo "[ERROR] Failed to compress: $relative_path" >&2
        return 1
    fi
}

# Export function and variables for parallel
export -f compress_geotiff
export INPUT_DIR OUTPUT_DIR COMPRESSION_TYPE COMPRESSION_LEVEL DRY_RUN

# Find all GeoTIFF files
echo "Scanning for GeoTIFF files in: $INPUT_DIR"
TIFF_FILES=$(find "$INPUT_DIR" -type f \( -iname "*.tif" -o -iname "*.tiff" \) | wc -l)
echo "Found $TIFF_FILES GeoTIFF files"

if [ "$TIFF_FILES" -eq 0 ]; then
    echo "No GeoTIFF files found in $INPUT_DIR"
    exit 0
fi

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "=== DRY RUN MODE ==="
    echo "Compression type: $COMPRESSION_TYPE"
    echo "Compression level: $COMPRESSION_LEVEL"
    echo "Parallel jobs: $PARALLEL_JOBS"
    echo ""
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Process files in parallel
echo "Starting parallel compression..."
echo "Compression: $COMPRESSION_TYPE (level $COMPRESSION_LEVEL)"
echo "Parallel jobs: $PARALLEL_JOBS"
echo ""

find "$INPUT_DIR" -type f \( -iname "*.tif" -o -iname "*.tiff" \) | \
    parallel --bar --jobs "$PARALLEL_JOBS" \
        compress_geotiff {} "$INPUT_DIR" "$OUTPUT_DIR" "$COMPRESSION_TYPE" "$COMPRESSION_LEVEL" "$DRY_RUN"

echo ""
echo "Compression complete!"

if [ "$DRY_RUN" = false ]; then
    # Show statistics
    INPUT_SIZE=$(du -sh "$INPUT_DIR" 2>/dev/null | cut -f1)
    if [ -d "$OUTPUT_DIR" ] && [ "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]; then
        OUTPUT_SIZE=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
        echo "Input directory size: $INPUT_SIZE"
        echo "Output directory size: $OUTPUT_SIZE"
    else
        echo "Input directory size: $INPUT_SIZE"
        echo "Output directory is empty or does not exist"
    fi
fi
