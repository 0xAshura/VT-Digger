# VT-Digger 

![GitHub](https://img.shields.io/github/license/0xAshura/VT-Digger)
![GitHub issues](https://img.shields.io/github/issues/0xAshura/VT-Digger)
![GitHub stars](https://img.shields.io/github/stars/0xAshura/VT-Digger)
![GitHub forks](https://img.shields.io/github/forks/0xAshura/VT-Digger)

<b> A powerful VirusTotal subdomain enumeration tool that efficiently extracts subdomains while respecting API rate limits. <b>

## Features

- **Multi-domain support**: Process single domain or files containing multiple domains.
- **Multi-API key support**: Rotate between multiple VirusTotal API keys to maximize rate limits.
- **Smart rate limiting**: Automatically respects VirusTotal's free API limits (4 requests/min per key)
- **Flexible output**: Option to output full subdomains or just the subdomain parts.

## Requirements

- Bash shell
- `jq` (JSON processor)
- `curl`
- VirusTotal API key(s)

## Installation

```bash
git clone https://github.com/0xAshura/vt-digger.git
cd vt-digger
chmod +x vt-digger.sh
```

## 📖 Usage

```bash
./vt-digger.sh [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `-d, --domain DOMAIN` | Single domain to query |
| `-f, --file FILE` | File containing list of domains (one per line) |
| `-k, --keys FILE` | File containing API keys (one per line) |
| `-o, --output FILE` | Output file (default: vt_subdomains.txt) |
| `-s, --subdomains-only` | Output only prefix of subdomains |
| `-r, --recursive` | Enable recursive subdomain enumeration |
| `-D, --delay SECONDS` | Delay between requests (default: 15) |
| `-v, --verbose` | Enable verbose output |
| `-h, --help` | Show this help message |

## Examples

1. **Single domain with API keys file**:
   ```bash
   ./vt-digger.sh -d example.com -k api_keys.txt
   ```

2. **Multiple domains from file**:
   ```bash
   ./vt-digger.sh -f domains.txt -k api_keys.txt -o results.txt
   ```

3. **Prefix of Subdomains only**:
   ```bash
   ./vt-digger.sh -d example.com -k api_keys.txt -s
   ```

4. **Verbose mode with custom delay**:
   ```bash
   ./vt-digger.sh -d example.com -k api_keys.txt -v -D 20
   ```

5. **Recursive mode with custom delay**:
   ```bash
   ./vt-digger.sh -d example.com -k api_keys.txt -r -D 20
   ```

##  Configuration

1. Create a file with your VirusTotal API keys (one per line):
   ```bash
   echo "your_api_key_1" > api_keys.txt
   echo "your_api_key_2" >> api_keys.txt
   # Add more keys as needed
   ```

2. Create a file with domains to scan (one per line):
   ```bash
   echo "example.com" > domains.txt
   echo "example.org" >> domains.txt
   # Add more domains as needed
   ```

## API Rate Limits

VT-Digger automatically respects VirusTotal's free API limits:
- 4 requests per minute per API key
- 500 requests per day per API key
- 15,500 requests per month per API key
- **I personally prefer having minimum 5 api keys so you will not hit rate limit as well as you will able to retrieve all the subdomains.**

The tool uses smart key rotation to maximize your available requests while staying within limits.

##  Output

The tool generates a file with all discovered subdomains. By default, it outputs full subdomain names (e.g., `sub.example.com`). With the `-s` flag, it outputs only the subdomain parts (e.g., `sub`).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

