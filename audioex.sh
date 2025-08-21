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
    echo "使用方法: $0 [-s ストリーム番号] [-i] [-y] input.m2ts|input.vob [output.wav]"
    echo ""
    echo "Blu-rayの.m2tsファイルとDVDの.VOBファイルから音声を無変換で抽出します"
    echo ""
    echo "オプション:"
    echo "  -s NUM        音声ストリーム番号を選択 (0から開始、デフォルト: 0)"
    echo "  -i            ストリーム情報のみを表示 (抽出は行わない)"
    echo "  -y            既存の出力ファイルを確認なしで強制上書き"
    echo ""
    echo "引数:"
    echo "  input.m2ts    入力する.m2tsファイル (Blu-ray)"
    echo "  input.vob     入力する.VOBファイル (DVD)"
    echo "  output.wav    出力音声ファイル (省略可、デフォルトは入力ファイル名に.wav拡張子)"
    echo ""
    echo "使用例:"
    echo "  $0 movie.m2ts"
    echo "  $0 VTS_01_1.VOB"
    echo "  $0 -s 1 movie.m2ts audio.wav"
    echo "  $0 -i movie.m2ts                    # ストリーム情報のみ表示"
    echo "  $0 -y movie.m2ts output.wav         # 確認なしで強制上書き"
    echo "  $0 -s 0 VTS_01_1.VOB japanese.wav"
    exit 1
}

# Function to check if ffmpeg is installed
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        echo -e "${RED}エラー: ffmpegがインストールされていないか、PATHに含まれていません${NC}"
        echo "まず、ffmpegをインストールしてください:"
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
        echo -e "${RED}エラー: 入力ファイル '$input_file' が存在しません${NC}"
        exit 1
    fi
    
    local file_extension="${input_file##*.}"
    file_extension=$(echo "$file_extension" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
    
    if [[ "$file_extension" != "m2ts" && "$file_extension" != "vob" ]]; then
        echo -e "${YELLOW}警告: 入力ファイルの拡張子が.m2tsまたは.VOBではありません${NC}"
        echo "対応フォーマット: .m2ts (Blu-ray), .VOB (DVD)"
        echo "とりあえず続行します..."
    fi
}

# Function to get audio stream info
get_audio_info() {
    local input_file="$1"
    local info_only="${2:-false}"
    
    echo -e "${YELLOW}'$input_file' の音声ストリームを解析中...${NC}"
    echo ""
    
    # Get detailed audio stream information with stream index
    local stream_info
    stream_info=$(ffprobe -v quiet -select_streams a -show_entries stream=index,codec_name,channels,sample_rate,bits_per_sample,bits_per_raw_sample,channel_layout -of csv=p=0:nk=1 "$input_file" 2>/dev/null) || {
        echo -e "${RED}エラー: '$input_file' の音声ストリームを解析できませんでした${NC}"
        exit 1
    }
    
    if [[ -z "$stream_info" ]]; then
        echo -e "${RED}エラー: '$input_file' に音声ストリームが見つかりません${NC}"
        exit 1
    fi
    
    # Remove duplicate lines and filter valid entries
    stream_info=$(echo "$stream_info" | sort -u | grep -E '^[0-9]+,' | head -10)
    echo -e "${GREEN}利用可能な音声ストリーム:${NC}"
    local stream_count=0
    while IFS=',' read -r index codec_name sample_rate channels channel_layout bits_per_sample bits_per_raw_sample; do
        # Skip empty lines and validate index
        [[ -n "$index" && "$index" =~ ^[0-9]+$ ]] || continue
        
        # Use bits_per_raw_sample if bits_per_sample is 0 or N/A (common for PCM formats)
        local actual_bits="$bits_per_sample"
        if [[ "$bits_per_sample" == "0" || "$bits_per_sample" == "N/A" || -z "$bits_per_sample" ]]; then
            actual_bits="$bits_per_raw_sample"
        fi
        
        echo "  ストリーム $stream_count (インデックス $index): $codec_name, ${channels}ch, ${sample_rate}Hz, ${actual_bits:-N/A}bit, ${channel_layout:-N/A}"
        ((stream_count++))
    done <<< "$stream_info"
    
    echo ""
    echo -e "${GREEN}音声ストリーム総数: $stream_count${NC}"
    
    # If info_only mode, show additional details and exit
    if [[ "$info_only" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}詳細ストリーム情報:${NC}"
        
        # Get detailed stream information for each audio stream
        local stream_idx=0
        while [[ $stream_idx -lt $stream_count ]]; do
            echo ""
            echo -e "${GREEN}--- ストリーム $stream_idx ---${NC}"
            
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
                echo "  ストリーム $stream_idx の詳細情報を取得できませんでした"
            fi
            
            ((stream_idx++))
        done
        
        echo ""
        echo -e "${GREEN}特定のストリームを抽出するには -s <ストリーム番号> を使用してください。${NC}"
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
    
    echo -e "${GREEN}'$input_file' のストリーム $stream_number から '$output_file' に音声を抽出中...${NC}"
    
    # Get codec info for the specific stream
    local codec_info
    codec_info=$(ffprobe -v quiet -select_streams a:$stream_number -show_entries stream=codec_name -of csv=p=0:nk=1 "$input_file" 2>/dev/null | head -1)
    
    echo -e "${YELLOW}ソースコーデック: ${codec_info:-不明}${NC}"
    
    # Different strategies based on file type and codec
    if [[ "$file_extension" == "vob" ]]; then
        # DVD VOB files - often contain AC3, MP2, or PCM
        echo -e "${YELLOW}DVD VOBファイルを処理中...${NC}"
        
        # First, try to copy without re-encoding
        if ffmpeg -i "$input_file" -map "0:a:$stream_number" -c:a copy -y "$output_file" 2>/dev/null; then
            echo -e "${GREEN}音声が無変換で正常に抽出されました${NC}"
        else
            echo -e "${YELLOW}直接コピーに失敗しました。PCMに変換しています...${NC}"
            # For DVD, use 16-bit PCM as it's more compatible
            ffmpeg -i "$input_file" -map "0:a:$stream_number" -c:a pcm_s16le -ar 48000 -y "$output_file" || {
                echo -e "${RED}エラー: ストリーム $stream_number からの音声抽出に失敗しました${NC}"
                exit 1
            }
            echo -e "${GREEN}音声が16-bit PCMとして正常に抽出されました${NC}"
        fi
    else
        # Blu-ray M2TS files - often contain high-quality PCM, DTS, or AC3
        echo -e "${YELLOW}Blu-ray M2TSファイルを処理中...${NC}"
        
        # First, try to copy without re-encoding
        if ffmpeg -i "$input_file" -map "0:a:$stream_number" -c:a copy -y "$output_file" 2>/dev/null; then
            echo -e "${GREEN}音声が無変換で正常に抽出されました${NC}"
        else
            echo -e "${YELLOW}直接コピーに失敗しました。高品質PCMに変換しています...${NC}"
            # For Blu-ray, use 24-bit PCM to maintain quality
            ffmpeg -i "$input_file" -map "0:a:$stream_number" -c:a pcm_s24le -y "$output_file" || {
                echo -e "${RED}エラー: ストリーム $stream_number からの音声抽出に失敗しました${NC}"
                exit 1
            }
            echo -e "${GREEN}音声が24-bit PCMとして正常に抽出されました${NC}"
        fi
    fi
    
    # Display output file info
    echo -e "${GREEN}出力ファイル情報:${NC}"
    ffprobe -v quiet -show_entries format=filename,size,duration -show_entries stream=codec_name,channels,sample_rate,bit_rate -of default=noprint_wrappers=1 "$output_file" 2>/dev/null || true
}

# Main script
main() {
    local stream_number=0
    local stream_specified=false
    local info_only=false
    local force_overwrite=false
    local input_file=""
    local output_file=""
    
    # Parse command line options
    while getopts "s:iyh" opt; do
        case $opt in
            s)
                stream_number="$OPTARG"
                stream_specified=true
                if ! [[ "$stream_number" =~ ^[0-9]+$ ]]; then
                    echo -e "${RED}エラー: ストリーム番号は非負の整数である必要があります${NC}"
                    echo -e "${YELLOW}代わりに利用可能なストリームを表示します...${NC}"
                    echo ""
                    info_only=true
                    stream_specified=false
                fi
                ;;
            i)
                info_only=true
                ;;
            y)
                force_overwrite=true
                ;;
            h)
                show_usage
                ;;
            \?)
                echo -e "${RED}無効なオプション: -$OPTARG${NC}" >&2
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
        echo -e "${RED}エラー: ストリーム番号 $stream_number は存在しません。利用可能なストリーム: 0-$((stream_count-1))${NC}"
        echo -e "${YELLOW}詳細ストリーム情報を表示します:${NC}"
        echo ""
        get_audio_info "$input_file" "true"
        exit 1
    fi
    
    # Generate output filename if not provided
    if [[ -z "$output_file" ]]; then
        if [[ $stream_number -eq 0 ]]; then
            output_file="${input_file%.*}.wav"
        else
            output_file="${input_file%.*}_${stream_number}.wav"
        fi
    fi
    
    echo -e "${GREEN}選択された音声ストリーム: $stream_number${NC}"
    echo ""
    
    # Check if output file already exists
    if [[ -f "$output_file" ]]; then
        if [[ "$force_overwrite" == "true" ]]; then
            echo -e "${YELLOW}Overwriting existing file '$output_file'${NC}"
        else
            echo -e "${YELLOW}Warning: Output file '$output_file' already exists${NC}"
            read -p "Overwrite? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 1
            fi
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
