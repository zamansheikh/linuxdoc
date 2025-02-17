To route traffic from your domain (DNS) to port 5130 on your DigitalOcean droplet, where your website is hosted using `npm run dev`, you need to configure your web server (like Nginx) to forward requests to port 5130.

### Steps to achieve this:

1. **Make sure your server is listening on port 5130:**
   - Since you're using `npm run dev`, your application is running on port 5130 locally. Ensure that it's correctly running and listening on this port.

2. **Set up DNS:**
   - In DigitalOcean, go to **Networking** -> **Domains**.
   - Create or update an **A record** that points to your droplet's public IP address.
     - For example:
       - **Host**: `@` for the root domain (e.g., `example.com`) or `www` for `www.example.com`.
       - **Value**: Your droplet's public IP address.

3. **Install Nginx (if not already installed):**
   If Nginx is not installed on your droplet, install it using:
   ```bash
   sudo apt update
   sudo apt install nginx
   ```

4. **Configure Nginx to proxy traffic to port 5130:**
   - Create a new Nginx server block (virtual host) or modify the default one to proxy the traffic to port 5130.

   Edit the Nginx config file:
   ```bash
   sudo nano /etc/nginx/sites-available/default
   ```

   Add the following configuration to route all traffic to port 5130:
   ```nginx
   server {
       listen 80;
       server_name example.com;  # Replace with your domain

       location / {
           proxy_pass http://127.0.0.1:5130;  # Forward requests to port 5130
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

   - Replace `example.com` with your domain name.
   - The `proxy_pass` will forward the HTTP requests coming to port 80 (default HTTP port) to your website running on port 5130.

5. **Check for syntax errors in Nginx configuration:**
   Before restarting Nginx, make sure there are no syntax errors:
   ```bash
   sudo nginx -t
   ```

6. **Restart Nginx:**
   After confirming there are no errors, restart Nginx to apply the changes:
   ```bash
   sudo systemctl restart nginx
   ```

7. **Firewall Setup:**
   - If you're using **UFW** (Uncomplicated Firewall), make sure the HTTP port (80) is allowed:
     ```bash
     sudo ufw allow 80/tcp
     sudo ufw allow 5130/tcp  # If the server is still running on 5130
     sudo ufw reload
     ```

8. **Check Your Website:**
   - Now, when users hit your domain (e.g., `http://example.com`), they should be routed to your application running on port 5130.

### Notes:
- **Using `npm run dev`:** Keep in mind that `npm run dev` is generally used for development environments, and it's not meant for production traffic. For a production setup, consider using a tool like **PM2** to run your Node.js app in the background or use Docker, or even host the app with a more robust process manager.
- **SSL/HTTPS:** For secure connections, consider setting up SSL certificates with **Let's Encrypt** and configuring Nginx to serve your site over HTTPS.

Let me know if you need more help with this setup!
