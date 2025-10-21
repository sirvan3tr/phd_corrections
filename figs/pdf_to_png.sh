#!/bin/bash

# PDF to PNG Converter for PDF/A Compliance (macOS)
# Converts PDF figures to high-quality 300 DPI PNG images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "PDF to PNG Converter for PDF/A Compliance"
echo "================================================"
echo "Features:"
echo "• 300 DPI resolution for print quality"
echo "• RGB color space for PDF/A compatibility"
echo "• No transparency (solid white background)"
echo "• Optimized for document inclusion"
echo ""

# Check for Ghostscript
if ! command -v gs &> /dev/null; then
    echo -e "${RED}Error: Ghostscript is not installed${NC}"
    echo "Install with: brew install ghostscript"
    exit 1
fi

echo -e "${GREEN}✓ Ghostscript found${NC}"

# Configuration
INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-png_figures}"
DPI=300

echo "Configuration:"
echo "  Input directory: $INPUT_DIR"
echo "  Output directory: $OUTPUT_DIR"
echo "  Resolution: ${DPI} DPI"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Find all PDF files
pdf_files=($(find "$INPUT_DIR" -maxdepth 3 -name "*.pdf" -type f))
total_files=${#pdf_files[@]}

if [ $total_files -eq 0 ]; then
    echo -e "${YELLOW}No PDF files found in $INPUT_DIR${NC}"
    exit 0
fi

echo "Found $total_files PDF file(s) to convert"
echo ""

# Process each PDF
success_count=0
error_count=0

for pdf_file in "${pdf_files[@]}"; do
    # Get filename without path and extension
    filename=$(basename "$pdf_file")
    filename_no_ext="${filename%.pdf}"
    
    # Output file path
    output_file="$OUTPUT_DIR/${filename_no_ext}.png"
    
    echo -e "${YELLOW}Converting: $filename${NC}"
    
    # Convert PDF to PNG with high quality settings
    echo "  → Converting to 300 DPI PNG..."
    
    # Ghostscript PNG conversion with PDF/A friendly settings
    if gs -sDEVICE=png16m \
          -r$DPI \
          -dNOPAUSE \
          -dBATCH \
          -dSAFER \
          -dGraphicsAlphaBits=4 \
          -dTextAlphaBits=4 \
          -dUseCropBox \
          -dEPSCrop \
          -sProcessColorModel=DeviceRGB \
          -dBackgroundColor=16#ffffff \
          -dQUIET \
          -sOutputFile="$output_file" \
          "$pdf_file" 2>/dev/null; then
        
        # Check if output is valid
        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            # Get file sizes (macOS compatible)
            original_size=$(stat -f%z "$pdf_file" 2>/dev/null)
            new_size=$(stat -f%z "$output_file" 2>/dev/null)
            
            # Convert to KB for display
            original_kb=$((original_size / 1024))
            new_kb=$((new_size / 1024))
            
            # Get image dimensions using file command
            if command -v file &> /dev/null; then
                dimensions=$(file "$output_file" | grep -o '[0-9]* x [0-9]*' | head -1)
                if [ -n "$dimensions" ]; then
                    echo -e "  ${GREEN}✓ Success${NC} (${original_kb}KB → ${new_kb}KB, ${dimensions} pixels)"
                else
                    echo -e "  ${GREEN}✓ Success${NC} (${original_kb}KB → ${new_kb}KB)"
                fi
            else
                echo -e "  ${GREEN}✓ Success${NC} (${original_kb}KB → ${new_kb}KB)"
            fi
            ((success_count++))
        else
            echo -e "  ${RED}✗ Failed: Output file is empty${NC}"
            rm -f "$output_file"
            ((error_count++))
        fi
    else
        echo -e "  ${RED}✗ Failed: Ghostscript conversion error${NC}"
        ((error_count++))
    fi
    
    echo ""
done

# Summary
echo "================================================"
echo "Conversion Complete"
echo "================================================"
echo -e "${GREEN}Successful: $success_count${NC}"
if [ $error_count -gt 0 ]; then
    echo -e "${RED}Failed: $error_count${NC}"
fi
echo ""
echo "PNG files are in: $OUTPUT_DIR"
echo ""

# Provide usage tips
if [ $success_count -gt 0 ]; then
    echo -e "${BLUE}Usage Tips:${NC}"
    echo "• PNG files are 300 DPI and ready for print"
    echo "• Use these in LaTeX with: \\includegraphics{filename.png}"
    echo "• Files have white backgrounds (no transparency)"
    echo "• RGB color space ensures PDF/A compatibility"
    echo ""
fi

echo -e "${GREEN}Done!${NC}"