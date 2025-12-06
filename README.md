# kompressor

Compress DEM GeoTIFF files in parallel using GDAL and GNU parallel.

This tool is designed to efficiently compress large numbers (200,000+) of GeoTIFF DEM (Digital Elevation Model) files created by [gmldem2tif](https://github.com/unopengis/gmldem2tif).

## Features

- 🚀 **Parallel processing** using GNU parallel for maximum throughput
- 🗜️ **Best compression by default** using ZSTD algorithm
- 🎛️ **Flexible compression options** (ZSTD, LZW, DEFLATE, LZMA, LERC_ZSTD)
- 🔍 **Dry-run mode** to preview operations before execution
- 📊 **Progress tracking** with visual progress bar
- ⚡ **Smart skip** of already compressed files with validation
- 🔄 **Resumable compression** - safely restart interrupted compression jobs
- 📈 **Compression ratio analysis** - calculate and display compression statistics
- 🏔️ **DEM-optimized** compression settings

## Installation

### Prerequisites

Install the required dependencies:

#### Ubuntu/Debian
```bash
# Install just command runner
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# Install GDAL tools
sudo apt-get update
sudo apt-get install gdal-bin

# Install GNU parallel
sudo apt-get install parallel
```

#### macOS
```bash
# Install just command runner
brew install just

# Install GDAL
brew install gdal

# Install GNU parallel
brew install parallel
```

### Verify Installation

```bash
just check-deps
```

This will verify that all required tools are installed.

## Usage

### Basic Usage

Compress GeoTIFF files with best compression (ZSTD):

```bash
just compress input_dir output_dir
```

### Dry-Run Mode

Preview what would be compressed without actually doing it:

```bash
just dry-run input_dir output_dir
```

Or using the script directly:

```bash
./compress.sh input_dir output_dir --dry-run
```

### Custom Compression Type

Use LZW compression (better compatibility):

```bash
just compress-lzw input_dir output_dir
```

Use DEFLATE compression:

```bash
just compress-deflate input_dir output_dir
```

Use LERC_ZSTD (optimal for DEM data):

```bash
just compress-lerc input_dir output_dir
```

Or specify compression type manually:

```bash
just compress input_dir output_dir --compression-type LZW
```

### Custom Compression Level

Adjust compression level (1-9, where 9 is best compression):

```bash
just compress input_dir output_dir --compression-level 6
```

### Limit Parallel Jobs

By default, all CPU cores are used. To limit the number of parallel jobs:

```bash
just compress input_dir output_dir --jobs 8
```

### Combined Options

```bash
just compress input_dir output_dir --compression-type ZSTD --compression-level 9 --jobs 16
```

### Resumable Compression

The compress task is now resumable. If compression is interrupted, you can safely restart it:

```bash
just compress input_dir output_dir
```

The tool will:
- Skip files that are already compressed and valid
- Recompress files that exist but are invalid GeoTIFF files
- Process files that haven't been compressed yet

This is achieved by validating each output file with `gdalinfo` before skipping.

### Compression Ratio Analysis

Calculate and display compression statistics for your dataset:

```bash
just ratio input_dir output_dir
```

This will:
- Display the compression ratio for each file (as percentage of original size)
- Show overall compression statistics
- Report how many files are not yet compressed
- Display progress percentage

Example output:
```
==========================================
Compression Ratio Analysis
==========================================

Comparing files between:
  Input:  input/
  Output: output/

==========================================

dem_file1.tif                                                                      28%
dem_file2.tif                                                                      32%
dem_file3.tif                                                                      25%

==========================================
Summary
==========================================

Total GeoTIFF files in input directory: 4

Compressed files: 3
  Input total size:  150MiB
  Output total size: 42MiB

Overall compression ratio: 28% of original size
Space saved: 108MiB
Compression percentage: 72% reduction

Not yet compressed: 1 file
Progress: 3/4 (75% complete)

==========================================
```

### Getting Help

```bash
just help
```

Or directly:

```bash
./compress.sh --help
```

## Compression Options

### Compression Algorithms

| Algorithm   | Description | Pros | Cons |
|-------------|-------------|------|------|
| **ZSTD** (default) | Zstandard compression | Best compression ratio, fast decompression | Requires newer GDAL (≥2.3) |
| **LZW** | Lempel-Ziv-Welch | Good compatibility, widely supported | Larger file sizes |
| **DEFLATE** | Deflate compression | Universal support | Moderate compression |
| **LZMA** | LZMA compression | Very high compression | Slower compression/decompression |
| **LERC_ZSTD** | LERC + ZSTD | Optimal for elevation data, lossy option | Specialized use case |

### Compression Levels

- **Level 1**: Fastest compression, larger file size
- **Level 5**: Balanced compression and speed
- **Level 9**: Best compression, slower (default)

For large datasets (200,000+ files), level 6-7 often provides a good balance between compression time and file size.

## Performance

### Parallel Processing

The tool uses GNU parallel to process multiple files simultaneously, utilizing all available CPU cores by default. For a dataset of 200,000+ files:

- **Single-threaded**: Days to weeks
- **Parallel (16 cores)**: Hours to days

### Optimization Tips

1. **Use ZSTD compression**: Best compression ratio with good speed
2. **Adjust compression level**: Level 6-7 for faster processing, level 9 for best compression
3. **Scale parallel jobs**: Match the number of jobs to your CPU cores
4. **Use local storage**: Process files on fast local disks (SSD/NVMe) rather than network storage
5. **Monitor resources**: Use `htop` or `top` to ensure optimal resource utilization

### Disk Space

During compression, you'll need:
- Space for input files
- Space for output files (~50-70% of input size with ZSTD)
- Temporary space for GDAL operations

## Technical Details

### GDAL Options Used

The compression script uses these GDAL creation options:

- `COMPRESS`: Compression algorithm
- `ZSTD_LEVEL` or `ZLEVEL`: Compression level
- `PREDICTOR=2`: Horizontal differencing predictor (for LZW/DEFLATE) - improves compression for DEM data
- `TILED=YES`: Creates tiled TIFF for better performance with large files
- `BIGTIFF=IF_SAFER`: Automatically uses BigTIFF format for files >4GB

### File Processing

- Maintains directory structure from input to output
- Validates output files using `gdalinfo` before skipping
- Recompresses invalid GeoTIFF files automatically
- Supports resumable compression for interrupted jobs
- Processes `.tif` and `.tiff` files (case-insensitive)
- Preserves all geospatial metadata and coordinate systems

## Examples

### Compress with default settings
```bash
just compress /data/input /data/output
```

### Dry-run to see what would happen
```bash
just dry-run /data/input /data/output
```

### Use LZW for better compatibility
```bash
just compress /data/input /data/output --compression-type LZW
```

### Fast compression for testing
```bash
just compress /data/input /data/output --compression-level 3 --jobs 4
```

### Best compression for archival
```bash
just compress /data/input /data/output --compression-type ZSTD --compression-level 9
```

### Check compression statistics
```bash
just ratio /data/input /data/output
```

### Resume interrupted compression
```bash
# If compression was interrupted, simply run it again
just compress /data/input /data/output
# Already compressed files will be validated and skipped
```

## Troubleshooting

### "gdal_translate not found"

Install GDAL tools:
```bash
# Ubuntu/Debian
sudo apt-get install gdal-bin

# macOS
brew install gdal
```

### "parallel not found"

Install GNU parallel:
```bash
# Ubuntu/Debian
sudo apt-get install parallel

# macOS
brew install parallel
```

### "just not found"

Install just command runner:
```bash
# Linux
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# macOS
brew install just
```

### Compression fails for some files

Check GDAL version and compression support:
```bash
gdal_translate --formats | grep -i tiff
```

Some older GDAL versions may not support ZSTD. Use LZW instead:
```bash
just compress input output --compression-type LZW
```

### Out of memory errors

Reduce the number of parallel jobs:
```bash
just compress input output --jobs 4
```

## License

CC0 1.0 Universal - See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Related Projects

- [gmldem2tif](https://github.com/unopengis/gmldem2tif) - Convert GML DEM to GeoTIFF
