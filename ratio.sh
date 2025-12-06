#!/bin/bash

# kompressor ratio - Calculate compression ratios for GeoTIFF files
# Usage: ./ratio.sh <input_dir> <output_dir>

set -euo pipefail

# Help text
show_help() {
    cat << EOF
Usage: $0 <input_dir> <output_dir>

Calculate compression ratios for GeoTIFF files.

Arguments:
  input_dir           Directory containing input GeoTIFF files
  output_dir          Directory containing compressed GeoTIFF files

This script compares file sizes between input and output directories,
displays compression ratio for each file, and shows overall statistics.

Examples:
  $0 input/ output/

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

# Validate directories
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory does not exist: $INPUT_DIR"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

# Helper functions
get_file_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null
}

format_size() {
    local size="$1"
    numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "$size bytes"
}

# Initialize counters
total_input_size=0
total_output_size=0
compressed_count=0
not_compressed_count=0

echo "=========================================="
echo "Compression Ratio Analysis"
echo "=========================================="
echo ""
echo "Comparing files between:"
echo "  Input:  $INPUT_DIR"
echo "  Output: $OUTPUT_DIR"
echo ""
echo "=========================================="
echo ""

# Find all GeoTIFF files in input directory
while IFS= read -r input_file; do
    # Calculate relative path
    relative_path="${input_file#$INPUT_DIR/}"
    output_file="$OUTPUT_DIR/$relative_path"
    
    # Get input file size
    input_size=$(get_file_size "$input_file")
    
    # Check if output file exists
    if [ -f "$output_file" ]; then
        # Get output file size
        output_size=$(get_file_size "$output_file")
        
        # Calculate compression ratio as integer percentage (guard against division by zero)
        if [ "$input_size" -gt 0 ]; then
            ratio=$((output_size * 100 / input_size))
        else
            ratio=0
        fi
        
        # Display file name and ratio
        printf "%-80s %3d%%\n" "$relative_path" "$ratio"
        
        # Add to totals
        total_input_size=$((total_input_size + input_size))
        total_output_size=$((total_output_size + output_size))
        compressed_count=$((compressed_count + 1))
    else
        not_compressed_count=$((not_compressed_count + 1))
    fi
done < <(find "$INPUT_DIR" -type f \( -iname "*.tif" -o -iname "*.tiff" \))

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

# Display statistics
total_files=$((compressed_count + not_compressed_count))

echo "Total GeoTIFF files in input directory: $total_files"
echo ""

if [ $compressed_count -gt 0 ]; then
    echo "Compressed files: $compressed_count"
    echo "  Input total size:  $(format_size $total_input_size)"
    echo "  Output total size: $(format_size $total_output_size)"
    echo ""
    
    # Calculate overall compression ratio (guard against division by zero)
    if [ $total_input_size -gt 0 ]; then
        overall_ratio=$((total_output_size * 100 / total_input_size))
        space_saved=$((total_input_size - total_output_size))
        
        echo "Overall compression ratio: $overall_ratio% of original size"
        echo "Space saved: $(format_size $space_saved)"
        
        # Calculate compression percentage (how much was reduced)
        compression_percentage=$((100 - overall_ratio))
        echo "Compression percentage: $compression_percentage% reduction"
    else
        echo "Overall compression ratio: N/A (zero input size)"
    fi
else
    echo "Compressed files: 0"
fi

echo ""

if [ $not_compressed_count -gt 0 ]; then
    if [ $not_compressed_count -eq 1 ]; then
        file_word="file"
    else
        file_word="files"
    fi
    echo "Not yet compressed: $not_compressed_count $file_word"
    
    if [ $total_files -gt 0 ]; then
        progress_percentage=$((compressed_count * 100 / total_files))
        echo "Progress: $compressed_count/$total_files ($progress_percentage% complete)"
    fi
else
    echo "Not yet compressed: 0 files"
    echo "Progress: 100% complete - All files have been compressed!"
fi

echo ""
echo "=========================================="
echo ""
