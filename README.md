# N8N LXC with Ngrok

Purpose of these scripts is to run and stop N8N and [Ngrok](https://ngrok.com/) process at the same time in one command. Tested on Debian N8N LXC Container inside Proxmox pve.

If you use Ephemeral Domain in your Ngrok setting. 
```bash
n8nXngrokDynamic.sh
```

If you use static domain in your Ngrok setting. 
```bash
n8nXngrokStatic.sh
```

To stop both n8n and Ngrok instance (Dynamic or Static).
```bash
n8nstop.sh
```

## Installation

```bash
git clone https://github.com/stubbornZen/n8nXngrokScript.git
cd n8nXngrokScript/Automated\ Scripts
sudo cp *.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/*.sh
```
Now you can run these scipt from anywhere on your terminal.

## Configuration

After installation, you need to perform some important configurations to ensure the scripts work correctly.

### 1. Choose and Edit Your "Start" Script

**A. For Dynamic (Ephemeral) Domain Users:**
If you're using `n8nXngrokDynamic.sh`, no additional configuration is typically needed within the script itself, as it automatically retrieves the ngrok URL. Just make sure your `ngrok` is configured with an `authtoken` in `~/.config/ngrok/ngrok.yml`.

**B. For Static/Reserved Domain Users:**
If you're using `n8nXngrokStatic.sh`, you **must** edit the script to define your static ngrok domain. You can also use a `.env` file if you want to separate configuration from the script.

```bash
sudo nano /usr/local/bin/n8nXngrokStatic.sh
```
Change the following line to match your static/reserved ngrok domain:

```bash
# SET THE STATIC NGROK DOMAIN
export NGROK_DOMAIN="your-ngrok-static-domain-here"
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change. Any feedback are expected!

Please make sure to update tests as appropriate.

## License

[MIT](https://choosealicense.com/licenses/mit/)