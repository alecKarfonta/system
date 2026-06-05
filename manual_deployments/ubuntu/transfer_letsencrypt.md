When reinstalling Ubuntu while preserving your Let's Encrypt certificates managed by Certbot, you'll need to back up the relevant directories and restore them after your fresh installation. Here's how to handle this:

## Back up before reinstalling:

1. Back up the certificates and Certbot configuration:
   ```bash
   sudo tar -czf letsencrypt-backup.tar.gz /etc/letsencrypt
   ```

2. Back up your nginx configuration files:
   ```bash
   sudo tar -czf nginx-backup.tar.gz /etc/nginx
   ```

3. Copy these backup files to an external drive, cloud storage, or another safe location.

## After reinstalling Ubuntu:

1. Install nginx and certbot:
   ```bash
   sudo apt update
   sudo apt install nginx certbot python3-certbot-nginx
   ```

2. Restore your backups:
   ```bash
   sudo tar -xzf letsencrypt-backup.tar.gz -C /
   sudo tar -xzf nginx-backup.tar.gz -C /
   ```

3. Set proper permissions:
   ```bash
   sudo chown -R root:root /etc/letsencrypt
   sudo chmod -R 755 /etc/letsencrypt/live
   sudo chmod -R 755 /etc/letsencrypt/archive
   ```

4. Restart nginx:
   ```bash
   sudo systemctl restart nginx
   ```

5. Verify auto-renewal is working:
   ```bash
   sudo certbot renew --dry-run
   ```

Important notes:
- This preserves your certificates and their renewal configuration
- If your domain is pointing to a new IP address, update your DNS records accordingly
- If your server setup changes significantly, you might need to adjust your nginx configs

Would you like more specific guidance on any part of this process?