#!/bin/bash

# audioex.sh - Extract PCM audio from Blu-ray .m2ts and DVD .VOB files without re-encoding
# Usage: ./audioex.sh input.m2ts|input.vob [output.wav]

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo "Usage: $0 [-s stream_number] [-i] input.m2ts|input.vob [output.wav]"
    echo ""
    echo "Extract PCM audio from Blu-ray .m2ts and DVD .VOB files without re-encoding"
    echo ""
    echo "Options:"
    echo "  -s NUM        Select audio stream number (0-based index, default: 0)"
    echo "  -i            Show stream information only (no extraction)"
    echo ""
    echo "Arguments:"
    echo "  input.m2ts    Input .m2ts file (Blu-ray)"
    echo "  input.vob     Input .VOB file (DVD)"
    echo "  output.wav    Output audio file (optional, defaults to input filename with .wav extension)"
    echo ""
    echo "Examples:"
    echo "  $0 movie.m2ts"
    echo "  $0 VTS_01_1.VOB"
    echo "  $0 -s 1 movie.m2ts audio.wav"
    echo "  $0 -i movie.m2ts                    # Show stream info only"
    echo "  $0 -s 0 VTS_01_1.VOB japanese.wav"
    exit 1
}

# Function to check if ffmpeg is installed
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        echo -e "${RED}Error: ffmpeg is not installed or not in PATH${NC}"
        echo "Please install ffmpeg first:"
        echo "  macOS: brew install ffmpeg"
        echo "  Ubuntu/Debian: sudo apt install ffmpeg"
        echo "  CentOS/RHEL: sudo yum install ffmpeg"
        exit 1
    fi
}

# Function to check if input file exists and has correct extension
validate_input() {
    local input_file="$1"
    
    if [[ ! -f "$input_file" ]]; then
        echo -e "${RED}Error: Input file '$input_file' does not exist${NC}"
        exit 1
    fi
    
    local file_extension="${input_file##*.}"
    file_extension=$(echo "$file_extension" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
    
    if [[ "$file_extension" != "m2ts" && "$file_extension" != "vob" ]]; then
        echo -e "${YELLOW}Warning: Input file does not have .m2ts or .VOB extension${NC}"
        echo "Supported formats: .m2ts (Blu-ray), .VOB (DVD)"
        echo "Continuing anyway..."
    fi
}

# Function to get audio stream info
get_audio_info() {
    local input_file="$1"
    local info_only="${2:-false}"
    
    echo -e "${YELLOW}Analyzing audio streams in '$input_file'...${NC}"
    echo ""
    
    # Get detailed audio stream information with stream index
    local stream_info
    stream_info=$(ffprobe -v quiet -select_streams a -show_entries stream=index,codec_name,channels,sample_rate,bits_per_sample,bits_per_raw_sample,channel_layout -of csv=p=0:nk=1 "$input_file" 2>/dev/null) || {
        echo -e "${RED}Error: Could not analyze audio streams in '$input_file'${NC}"
        exit 1
    }
    
    if [[ -z "$stream_info" ]]; then
        echo -e "${RED}Error: No audio streams found in '$input_file'${NC}"
        exit 1
    fi
    
    # Remove duplicate lines and filter valid entries
    stream_info=$(echo "$stream_info" | sort -u | grep -E '^[0-9]+,' | head -10)
    echo -e "${GREEN}Available audio streams:${NC}"
    local stream_count=0
    while IFS=',' read -r index codec_name sample_rate channels channel_layout bits_per_sample bits_per_raw_sample; do
        # Skip empty lines and validate index
        [[ -n "$index" && "$index" =~ ^[0-9]+$ ]] || continue
        
        # Use bits_per_raw_sample if bits_per_sample is 0 or N/A (common for PCM formats)
        local actual_bits="$bits_per_sample"
        if [[ "$bits_per_sample" == "0" || "$bits_per_sample" == "N/A" || -z "$bits_per_sample" ]]; then
            actual_bits="$bits_per_raw_sample"
        fi
        
        echo "  Stream $stream_count (index $index): $codec_name, ${channels}ch, ${sample_rate}Hz, ${actual_bits:-N/A}bit, ${channel_layout:-N/A}"
        ((stream_count++))
    done <<< "$stream_info"
    
    echo ""
    echo -e "${GREEN}Total audio streams: $stream_count${NC}"
    
    # If info_only mode, show additional details and exit
    if [[ "$info_only" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}Detailed stream information:${NC}"
        
        # Get detailed stream information for each audio stream
        local stream_idx=0
        while [[ $stream_idx -lt $stream_count ]]; do
            echo ""
            echo -e "${GREEN}--- Stream $stream_idx ---${NC}"
            
            # Get stream info more reliably
            local detailed_info
            detailed_info=$(ffprobe -v quiet -select_streams a:$stream_idx -show_entries stream=codec_name,sample_rate,channels,channel_layout,bits_per_sample,duration,bit_rate,bits_per_raw_sample -of csv=p=0:nk=1 "$input_file" 2>/dev/null | head -1)
            
            if [[ -n "$detailed_info" ]]; then
                IFS=',' read -r codec_name sample_rate channels channel_layout bits_per_sample duration bit_rate bits_per_raw_sample <<< "$detailed_info"
                echo "  codec_name=$codec_name"
                echo "  channels=$channels"
                echo "  sample_rate=$sample_rate"
                
                # Use bits_per_raw_sample if bits_per_sample is 0 or N/A (common for PCM formats)
                local actual_bits="$bits_per_sample"
                if [[ "$bits_per_sample" == "0" || "$bits_per_sample" == "N/A" || -z "$bits_per_sample" ]]; then
                    actual_bits="$bits_per_raw_sample"
                fi
                [[ "$actual_bits" != "N/A" && -n "$actual_bits" && "$actual_bits" != "0" ]] && echo "  bits_per_sample=$actual_bits"
                
                [[ "$channel_layout" != "N/A" && -n "$channel_layout" ]] && echo "  channel_layout=$channel_layout"
                [[ "$duration" != "N/A" && -n "$duration" ]] && echo "  duration=$duration"
                [[ "$bit_rate" != "N/A" && -n "$bit_rate" ]] && echo "  bit_rate=$bit_rate"
            else
                echo "  Unable to get detailed info for stream $stream_idx"
            fi
            
            ((stream_idx++))
        done
        
        echo ""
        echo -e "${GREEN}Use -s <stream_number> to select a specific stream for extraction.${NC}"
        exit 0
    fi
    
    # Return the stream count for validation
    echo "$stream_count"
}

# Function to extract PCM audio
extract_audio() {
    local input_file="$1"
    local output_file="$2"
    local stream_number="$3"
    
    local file_extension="${input_file##*.}"
    file_extension=$(echo "$file_extension" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
    
    echo -e "${GREEN}Extracting audio from stream $stream_number in '$input_file' to '$output_file'...${NC}"
    
    # Get codec info for the specific stream
    local codec_info
    codec_info=$(ffprobe -v quiet -select_streams a:$stream_number -show_entries stream=codec_name -of csv=p=0:nk=1 "$input_file" 2>/dev/null | head -1)
    
    echo -e "${YELLOW}Source codec: ${codec_info:-unknown}${NC}"
    
    # Different strategies based on file type and codec
    if [[ "$file_extension" == "vob" ]]; then
        # DVD VOB files - often contain AC3, MP2, or PCM
        echo -e "${YELLOW}Processing DVD VOB file...${NC}"
        
        # First, try to copy without re-encoding
        if ffmpeg -i "$input_file" -map "0:a:$stream_number" -c:a copy -y "$output_file" 2>/dev/null; then
            echo -e "${GREEN}Audio extracted successfully without re-encoding${NC}"
        else
            echo -e "${YELLOW}Direct copy failed, converting to PCM...${NC}"
            # For DVD, use 16-bit PCM as it's more compatible
            ffmpeg -i "$input_file" -map "0:a:$stream_number" -c:a pcm_s16le -ar 48000 -y "$output_file" || {
                echo -e "${RED}Error: Failed to extract audio from stream $stream_number${NC}"
                exit 1
            }
            echo -e "${GREEN}Audio extracted successfully as 16-bit PCM${NC}"
        fi
    else
        # Blu-ray M2TS files - often contain high-quality PCM, DTS, or AC3
        echo -e "${YELLOW}Processing Blu-ray M2TS file...${NC}"
        
        # First, try to copy without re-encoding
        if ffmpeg -i "$input_file" -map "0:a:$stream_number" -c:a copy -y "$output_file" 2>/dev/null; then
            echo -e "${GREEN}Audio extracted successfully without re-encoding${NC}"
        else
            echo -e "${YELLOW}Direct copy failed, converting to high-quality PCM...${NC}"
            # For Blu-ray, use 24-bit PCM to maintain quality
            ffmpeg -i "$input_file" -map "0:a:$stream_number" -c:a pcm_s24le -y "$output_file" || {
                echo -e "${RED}Error: Failed to extract audio from stream $stream_number${NC}"
                exit 1
            }
            echo -e "${GREEN}Audio extracted successfully as 24-bit PCM${NC}"
        fi
    fi
    
    # Display output file info
    echo -e "${GREEN}Output file info:${NC}"
    ffprobe -v quiet -show_entries format=filename,size,duration -show_entries stream=codec_name,channels,sample_rate,bit_rate -of default=noprint_wrappers=1 "$output_file" 2>/dev/null || true
}

# Main script
main() {
    local stream_number=0
    local stream_specified=false
    local info_only=false
    local input_file=""
    local output_file=""
    
    # Parse command line options
    while getopts "s:ih" opt; do
        case $opt in
            s)
                stream_number="$OPTARG"
                stream_specified=true
                if ! [[ "$stream_number" =~ ^[0-9]+$ ]]; then
                    echo -e "${RED}Error: Stream number must be a non-negative integer${NC}"
                    echo -e "${YELLOW}Showing available streams instead...${NC}"
                    echo ""
                    info_only=true
                    stream_specified=false
                fi
                ;;
            i)
                info_only=true
                ;;
            h)
                show_usage
                ;;
            \?)
                echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
                show_usage
                ;;
        esac
    done
    
    # Shift past the options
    shift $((OPTIND-1))
    
    # Check remaining arguments
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        show_usage
    fi
    
    input_file="$1"
    output_file="$2"
    
    # Validate environment and input
    check_ffmpeg
    validate_input "$input_file"
    
    # If info_only mode, just show stream information and exit
    if [[ "$info_only" == "true" ]]; then
        get_audio_info "$input_file" "true"
        return 0
    fi
    
    # Show audio stream information and get stream count
    local stream_count
    stream_count=$(get_audio_info "$input_file")
    
    # Validate stream number if it was specified
    if [[ "$stream_specified" == "true" && $stream_number -ge $stream_count ]]; then
        echo -e "${RED}Error: Stream number $stream_number does not exist. Available streams: 0-$((stream_count-1))${NC}"
        echo -e "${YELLOW}Showing detailed stream information:${NC}"
        echo ""
        get_audio_info "$input_file" "true"
        exit 1
    fi
    
    # Generate output filename if not provided
    if [[ -z "$output_file" ]]; then
        if [[ $stream_number -eq 0 ]]; then
            output_file="${input_file%.*}.wav"
        else
            output_file="${input_file%.*}_stream${stream_number}.wav"
        fi
    fi
    
    echo -e "${GREEN}Selected audio stream: $stream_number${NC}"
    echo ""
    
    # Check if output file already exists
    if [[ -f "$output_file" ]]; then
        echo -e "${YELLOW}Warning: Output file '$output_file' already exists${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
    
    # Extract audio
    extract_audio "$input_file" "$output_file" "$stream_number"
    
    # Final success message
    echo ""
    echo -e "${GREEN}✓ Audio extraction completed successfully!${NC}"
    echo -e "${GREEN}✓ Output file: '$output_file'${NC}"
    
    # Display file size
    if command -v du &> /dev/null; then
        echo -e "${GREEN}✓ File size: $(du -h "$output_file" | cut -f1)${NC}"
    fi
}

# Run main function with all arguments
main "$@"
