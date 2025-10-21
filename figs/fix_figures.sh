#!/bin/bash

# PDF Figure Fixer for PDF/A Compliance (macOS)
# Fixes fonts, colors, transparency, and interpolation issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "PDF Figure Fixer for PDF/A-1B Compliance"
echo "================================================"
echo "Fixes applied:"
echo "• Embeds sRGB color profile for consistent colors"
echo "• Removes transparency and soft masks"
echo "• Disables image interpolation"
echo "• Adds PDF/A identification metadata"
echo "• Ensures proper font embedding"
echo ""

# Check for Ghostscript
if ! command -v gs &> /dev/null; then
    echo -e "${RED}Error: Ghostscript is not installed${NC}"
    echo "Install with: brew install ghostscript"
    exit 1
fi

echo -e "${GREEN}✓ Ghostscript found${NC}"

# Check for sRGB profile (macOS default location)
SRGB_PROFILE="/System/Library/ColorSync/Profiles/sRGB Profile.icc"
if [ ! -f "$SRGB_PROFILE" ]; then
    echo -e "${YELLOW}Warning: sRGB profile not found at default location${NC}"
    echo "  Trying alternative locations..."
    
    # Try alternative locations
    ALT_PROFILES=(
        "/Library/ColorSync/Profiles/sRGB Profile.icc"
        "/usr/share/color/icc/sRGB.icc"
        "/opt/homebrew/share/ghostscript/*/iccprofiles/srgb.icc"
    )
    
    SRGB_PROFILE=""
    for profile in "${ALT_PROFILES[@]}"; do
        if [ -f "$profile" ]; then
            SRGB_PROFILE="$profile"
            break
        fi
    done
    
    if [ -z "$SRGB_PROFILE" ]; then
        echo -e "${YELLOW}No sRGB profile found. PDF/A compliance may be limited.${NC}"
        SRGB_PROFILE=""
    else
        echo -e "${GREEN}✓ Found sRGB profile: $SRGB_PROFILE${NC}"
    fi
else
    echo -e "${GREEN}✓ sRGB profile found${NC}"
fi
echo ""

# Configuration
INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-fixed_figures}"
DPI=300
QUALITY="printer"  # screen, ebook, printer, prepress

echo "Configuration:"
echo "  Input directory: $INPUT_DIR"
echo "  Output directory: $OUTPUT_DIR"
echo "  Resolution: ${DPI} DPI"
echo "  Quality: $QUALITY"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# No PostScript metadata file needed - using built-in PDF/A support

# Find all PDF files
pdf_files=($(find "$INPUT_DIR" -maxdepth 3 -name "*.pdf" -type f))
total_files=${#pdf_files[@]}

if [ $total_files -eq 0 ]; then
    echo -e "${YELLOW}No PDF files found in $INPUT_DIR${NC}"
    exit 0
fi

echo "Found $total_files PDF file(s) to process"
echo ""

# Process each PDF
success_count=0
error_count=0

for pdf_file in "${pdf_files[@]}"; do
    # Get filename without path
    filename=$(basename "$pdf_file")
    filename_no_ext="${filename%.pdf}"
    
    # Output file path
    output_file="$OUTPUT_DIR/$filename"
    
    echo -e "${YELLOW}Processing: $filename${NC}"
    
    # Ghostscript conversion with PDF/A-1B compliance
    echo "  → Applying PDF/A-1B fixes..."
    
    # Build Ghostscript command with conditional ICC profile
    gs_cmd=(
        gs -sDEVICE=pdfwrite
        -dNOPAUSE
        -dBATCH
        -dSAFER
        -dCompatibilityLevel=1.4
        -dPDFA=1
        -dPDFACompatibilityPolicy=1
        -sProcessColorModel=DeviceRGB
        -dEmbedAllFonts=true
        -dSubsetFonts=true
        -dCompressFonts=true
        -dNOTRANSPARENCY
        -dNoOutputFonts=false
        -dDoThumbnails=false
        -dCreateJobTicket=false
        -dPreserveEPSInfo=false
        -dPreserveOPIComments=false
        -dPreserveHalftoneInfo=false
        -dTransferFunctionInfo=/Remove
        -sColorConversionStrategy=RGB
        -dUseFlateCompression=true
        -dAutoFilterColorImages=false
        -dAutoFilterGrayImages=false
        -dColorImageFilter=/FlateEncode
        -dGrayImageFilter=/FlateEncode
        -dMonoImageFilter=/CCITTFaxEncode
        -dAntiAliasColorImages=false
        -dAntiAliasGrayImages=false
        -dAntiAliasMonoImages=false
        -dDownsampleColorImages=true
        -dDownsampleGrayImages=true
        -dDownsampleMonoImages=true
        -dColorImageDownsampleType=/Bicubic
        -dColorImageResolution=$DPI
        -dGrayImageDownsampleType=/Bicubic
        -dGrayImageResolution=$DPI
        -dMonoImageDownsampleType=/Bicubic
        -dMonoImageResolution=1200
        -dColorImageDownsampleThreshold=1.0
        -dGrayImageDownsampleThreshold=1.0
        -dMonoImageDownsampleThreshold=1.0
        -dAutoRotatePages=/None
        -dDetectDuplicateImages=true
        -dOptimize=true
        -dFastWebView=false
        -dParseDSCComments=false
        -dParseDSCCommentsForDocInfo=false
        -dPreserveCopyPage=false
        -dPreserveMarkedContent=false
        -dQUIET
    )
    
    # Add ICC profile if available
    if [ -n "$SRGB_PROFILE" ]; then
        gs_cmd+=(-sDefaultRGBProfile="$SRGB_PROFILE")
        gs_cmd+=(-sOutputICCProfile="$SRGB_PROFILE")
    fi
    
    gs_cmd+=(-sOutputFile="$output_file")
    gs_cmd+=("$pdf_file")
    
    # Try PDF/A conversion first
    conversion_success=false
    
    if "${gs_cmd[@]}" 2>/dev/null; then
        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            conversion_success=true
            conversion_type="PDF/A-1B"
        fi
    fi
    
    # If PDF/A failed, try basic PDF optimization
    if [ "$conversion_success" = false ]; then
        echo "  → PDF/A failed, trying basic optimization..."
        rm -f "$output_file"
        
        # Simpler Ghostscript command without strict PDF/A
        basic_cmd=(
            gs -sDEVICE=pdfwrite
            -dNOPAUSE
            -dBATCH
            -dSAFER
            -dCompatibilityLevel=1.4
            -sProcessColorModel=DeviceRGB
            -sColorConversionStrategy=RGB
            -dEmbedAllFonts=true
            -dSubsetFonts=true
            -dCompressFonts=true
            -dNOTRANSPARENCY
            -dAutoFilterColorImages=false
            -dAutoFilterGrayImages=false
            -dColorImageFilter=/FlateEncode
            -dGrayImageFilter=/FlateEncode
            -dAntiAliasColorImages=false
            -dAntiAliasGrayImages=false
            -dAntiAliasMonoImages=false
            -dColorImageResolution=$DPI
            -dGrayImageResolution=$DPI
            -dMonoImageResolution=1200
            -dAutoRotatePages=/None
            -dOptimize=true
            -dQUIET
            -sOutputFile="$output_file"
            "$pdf_file"
        )
        
        if "${basic_cmd[@]}" 2>/dev/null; then
            if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                conversion_success=true
                conversion_type="Basic optimization"
            fi
        fi
    fi
    
    # If basic optimization failed, try minimal conversion
    if [ "$conversion_success" = false ]; then
        echo "  → Basic optimization failed, trying minimal conversion..."
        rm -f "$output_file"
        
        # Minimal Ghostscript command
        minimal_cmd=(
            gs -sDEVICE=pdfwrite
            -dNOPAUSE
            -dBATCH
            -dSAFER
            -dCompatibilityLevel=1.4
            -dEmbedAllFonts=true
            -dQUIET
            -sOutputFile="$output_file"
            "$pdf_file"
        )
        
        if "${minimal_cmd[@]}" 2>/dev/null; then
            if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                conversion_success=true
                conversion_type="Minimal conversion"
            fi
        fi
    fi
    
    # Report results
    if [ "$conversion_success" = true ]; then
        # Get file sizes (macOS compatible)
        original_size=$(stat -f%z "$pdf_file" 2>/dev/null)
        new_size=$(stat -f%z "$output_file" 2>/dev/null)
        
        # Convert to KB for display
        original_kb=$((original_size / 1024))
        new_kb=$((new_size / 1024))
        
        echo -e "  ${GREEN}✓ Success - $conversion_type${NC} (${original_kb}KB → ${new_kb}KB)"
        ((success_count++))
    else
        echo -e "  ${RED}✗ Failed: All conversion methods failed${NC}"
        rm -f "$output_file"
        ((error_count++))
    fi
    
    echo ""
done

# Summary
echo "================================================"
echo "Processing Complete"
echo "================================================"
echo -e "${GREEN}Successful: $success_count${NC}"
if [ $error_count -gt 0 ]; then
    echo -e "${RED}Failed: $error_count${NC}"
fi
echo ""
echo "Fixed files are in: $OUTPUT_DIR"
echo ""

# Offer to create PNG fallbacks for failed files
if [ $error_count -gt 0 ]; then
    echo -e "${YELLOW}Some files failed. Create PNG versions as fallback? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Creating PNG fallbacks..."
        mkdir -p "$OUTPUT_DIR/png_fallbacks"
        
        for pdf_file in "${pdf_files[@]}"; do
            filename=$(basename "$pdf_file")
            filename_no_ext="${filename%.pdf}"
            output_file="$OUTPUT_DIR/$filename"
            
            # If PDF fix failed, create PNG
            if [ ! -f "$output_file" ]; then
                png_file="$OUTPUT_DIR/png_fallbacks/${filename_no_ext}.png"
                echo "  Converting $filename to PNG..."
                
                if gs -sDEVICE=png16m \
                      -r$DPI \
                      -dNOPAUSE \
                      -dBATCH \
                      -dSAFER \
                      -dQUIET \
                      -sOutputFile="$png_file" \
                      "$pdf_file" 2>/dev/null; then
                    echo -e "  ${GREEN}✓ Created: ${filename_no_ext}.png${NC}"
                else
                    echo -e "  ${RED}✗ Failed to create PNG${NC}"
                fi
            fi
        done
        echo ""
        echo "PNG fallbacks created in: $OUTPUT_DIR/png_fallbacks"
    fi
fi

echo -e "${GREEN}Done!${NC}"