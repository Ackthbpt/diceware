# Diceware Passphrase Generator

A POSIX-portable diceware passphrase generator using the EFF large wordlist and `/dev/urandom` for cryptographic randomness.

This is intended to as portable as possible, so there are no dependencies beyond a POSIX shell, `awk`, `od`, and `tr`.

## Usage

```
./diceware.sh [OPTIONS]
```

## Options

| Flag | Description |
|------|-------------|
| `-w NUM` | Number of words (default: 6) |
| `-n` | Append a random digit (0-9) to a random word |
| `-c` | Capitalize each word |
| `-s CHARS` | Use a random character from CHARS as the word separator (default: space) |
| `-l` | Show total passphrase length |
| `-d` | Show dice rolls alongside each word |
| `-f FILE` | Path to EFF wordlist file (default: auto-detect) |
| `-h` | Show help |

## Examples

```bash
./diceware.sh                  # 6-word passphrase
./diceware.sh -w 8             # 8-word passphrase
./diceware.sh -w 7 -n          # 7 words + a random digit appended to one
./diceware.sh -n -s '-'        # 6 words, hyphen-separated, with a digit
./diceware.sh -c -s '.'        # 6 capitalized words, dot-separated
./diceware.sh -d               # show dice rolls for verification
```

## How it works

Each word is selected by rolling five virtual dice using `/dev/urandom`, producing a key like `34251` that maps to a word in the EFF wordlist. Rejection sampling eliminates modulo bias in the random number generation, therefore bytes outside the evenly-divisible range are discarded and rerolled.

The EFF large wordlist contains 7,776 words (6^5), giving approximately 12.9 bits of entropy per word. A standard 6-word passphrase provides ~77 bits of entropy.

| Words | Entropy (bits) |
|-------|---------------|
| 4 | ~51.7 |
| 5 | ~64.6 |
| 6 | ~77.5 |
| 7 | ~90.5 |
| 8 | ~103.4 |

## Setup

The most recent EFF large wordlist is included here, but if you want to download again just in case it's updated:

```bash
curl -O https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt
chmod +x diceware.sh
```

The `eff_large_wordlist.txt` file needs to be in the same directory as the script.  If it's not, use `-f` to specify an alternate path.
