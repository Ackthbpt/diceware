#!/bin/sh
# diceware.sh — POSIX-portable diceware passphrase generator
# Uses the EFF large wordlist and /dev/urandom for cryptographic randomness.
# No dependencies beyond a POSIX shell, awk, od, and tr.

# ----- defaults -----
NUM_WORDS=6          # standard diceware recommendation
ADD_NUMBER=false     # insert a random digit into a random word
SPECIAL_CHARS=""     # if set, pick one and insert into a random word
SHOW_ROLLS=false     # show the dice rolls alongside each word
WORDLIST=""          # path to wordlist file (auto-detected below)

# ----- usage -----
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Generate a diceware passphrase using the EFF large wordlist.

Options:
  -w NUM   Number of words (default: 6)
  -n       Append a random digit (0-9) onto a random word
  -c       Capitalize the words
  -s CHARS Use a random character from CHARS as the word separator
           (default: space). e.g., -s '-' or -s '!@#-'
  -l       Show total length of passphrase
  -d       Show dice rolls alongside each word
  -f FILE  Path to EFF wordlist file (default: auto-detect)
  -h       Show this help

Examples:
  $(basename "$0")              # 6-word passphrase
  $(basename "$0") -w 8         # 8-word passphrase
  $(basename "$0") -w 7 -n      # 7 words + a random digit
  $(basename "$0") -n -s '!@#'  # 6 words + digit + special char
  $(basename "$0") -d           # show dice rolls for verification
EOF
exit 0
}

# ----- parse arguments with getopts -----
#
# getopts loops through argv one flag at a time.
# The leading colon in ":w:ns:dhf:" enables SILENT error mode —
# instead of getopts printing its own error messages, it sets opt to
# '?' (unknown flag) or ':' (missing argument) and lets us handle it.

while getopts ":w:ncs:dlhf:" opt; do
    case $opt in
        w)  # -w requires an argument (the colon after w in the optstring)
            # OPTARG is automatically set to whatever followed -w
            NUM_WORDS=$OPTARG
            # Validate it's actually a number
            case $NUM_WORDS in
                ''|*[!0-9]*) echo "Error: -w requires a number" >&2; exit 1 ;;
            esac
            ;;
        c)  # -c is a boolean flag (no colon after it), so no OPTARG
            ADD_CAP=true
            ;;
        n)  # -n is a boolean flag (no colon after it), so no OPTARG
            ADD_NUMBER=true
            ;;
        s)  # -s requires an argument: the set of special characters to pick from
            SPECIAL_CHARS=$OPTARG
            ;;
        d)  # boolean flag
            SHOW_ROLLS=true
            ;;
        l)  # boolean flag
            SHOW_LENGTH=true
            ;;
        f)  # -f requires an argument: path to wordlist
            WORDLIST=$OPTARG
            ;;
        h)  usage
            ;;
        :)  # silent mode: getopts sets opt to ':' when a required arg is missing
            echo "Error: -$OPTARG requires an argument" >&2
            exit 1
            ;;
        ?)  # silent mode: getopts sets opt to '?' for unknown flags
            # OPTARG contains the offending flag letter
            echo "Error: unknown option -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# ----- locate the wordlist -----
if [ -z "$WORDLIST" ]; then
    # Look for the wordlist next to this script, then in current directory
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    for candidate in \
        "$SCRIPT_DIR/eff_large_wordlist.txt" \
        "./eff_large_wordlist.txt"; do
    if [ -f "$candidate" ]; then
        WORDLIST=$candidate
        break
    fi
done
fi

if [ -z "$WORDLIST" ] || [ ! -f "$WORDLIST" ]; then
    echo "Error: wordlist not found. Place eff_large_wordlist.txt next to this" >&2
    echo "script or specify with -f. Download from:" >&2
    echo "  https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt" >&2
    exit 1
fi

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

# Roll a single die (1-6) using rejection sampling to avoid modulo bias.
# A byte is 0-255; only 0-251 divides evenly by 6 (252/6 = 42).
# We discard 252-255 and reroll — happens <1.6% of the time.
roll_die() {
    while :; do
        n=$(od -A n -N 1 -t u1 /dev/urandom | tr -d ' ')
        [ "$n" -lt 252 ] && break
    done
    echo $(( n % 6 + 1 ))
}

# Generate a random number 0-9
rand_digit() {
    n=$(od -A n -N 1 -t u1 /dev/urandom | tr -d ' ')
    echo $(( n % 10 ))
}

# Generate a random number from 0 to (max-1)
rand_below() {
    max=$1
    n=$(od -A n -N 2 -t u2 /dev/urandom | tr -d ' ')
    echo $(( n % max ))
}

# Roll 5 dice and look up the word from the EFF wordlist.
# Outputs "DICEKEY<tab>WORD" so the caller can use either part.
roll_word() {
    key=""
    for _i in 1 2 3 4 5; do
        key="${key}$(roll_die)"
    done
    word=$(awk -F'\t' -v k="$key" '$1 == k {print $2; exit}' "$WORDLIST")
    printf '%s\t%s\n' "$key" "$word"
}


# ============================================================================
# GENERATE THE PASSPHRASE
# ============================================================================

# Roll all the words
words=""
rolls=""
i=0
while [ "$i" -lt "$NUM_WORDS" ]; do
    result=$(roll_word)
    key=$(printf '%s' "$result" | cut -f1)
    word=$(printf '%s' "$result" | cut -f2)
    # Build space-separated lists
    if [ -z "$words" ]; then
        words="$word"
        rolls="$key"
    else
        words="$words $word"
        rolls="$rolls $key"
    fi
    i=$(( i + 1 ))
done

# Convert to arrays we can index (using positional parameters trick)
# We'll work with the space-separated string and use a counter

# Pick which word gets the number appended
number_pos=""

if [ "$ADD_NUMBER" = true ]; then
    number_pos=$(rand_below "$NUM_WORDS")
fi

# Rebuild the words with insertions applied
final_words=""
roll_list=""
idx=0
for word in $words; do
    if [ "$ADD_CAP" = true ]; then
        first_char_upper=$(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')
        rest_of_string="${word:1}"
        word="${first_char_upper}${rest_of_string}"
    fi
    # Apply number insertion if this word was selected
    if [ "$ADD_NUMBER" = true ] && [ "$idx" -eq "$number_pos" ]; then
        word="${word}$(rand_digit)"
    fi

    if [ -z "$final_words" ]; then
        final_words="$word"
    else
        final_words="$final_words $word"
    fi

    idx=$(( idx + 1 ))
done

# ----- output -----

# Use special char as delimiter if provided, otherwise space
if [ -n "$SPECIAL_CHARS" ]; then
    char_idx=$(rand_below ${#SPECIAL_CHARS})
        delimiter="${SPECIAL_CHARS:$char_idx:1}"
    else
        delimiter=" "
fi

echo "Passphrase:"
special_char_substituted=$(echo "$final_words" | tr ' ' "$delimiter")
echo "\t$special_char_substituted"

# Show dice rolls if requested
if [ "$SHOW_ROLLS" = true ]; then
    echo ""
    echo "Dice rolls:"
    idx=1
    for roll in $rolls; do
        echo "\tWord $idx: $roll"
        idx=$(( idx + 1 ))
    done
fi

# Show length if requested
if [ "$SHOW_LENGTH" = true ]; then
    echo ""
    echo "Passphrase length:"
    echo "\t${#final_words}"
fi
