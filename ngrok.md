![image](https://github.com/user-attachments/assets/0d516989-f26f-4f04-ad85-ea4e7f224002)# Setting Up ngrok

ngrok is a tool that allows you to expose a local server to the internet securely. Follow these steps to set up and use ngrok.

---

## Prerequisites

- A computer running Windows, macOS, or Linux.
- An active internet connection.
- Basic knowledge of using a terminal/command prompt.

---

## Step 1: Download ngrok

1. Go to the [official ngrok website](https://ngrok.com/).
2. Click on **Sign Up** if you don’t have an account. Follow the instructions to create one.
3. Download the ngrok executable for your operating system:
   - For **Windows**: Download the `.zip` file.
   - For **macOS/Linux**: Download the binary file.

---

## Step 2: Install ngrok

### On Windows
1. Extract the downloaded `.zip` file.
2. Move the `ngrok.exe` file to a folder of your choice (e.g., `C:\ngrok`).
3. Add the folder to your system's PATH variable (optional but recommended):
   - Open **Control Panel > System > Advanced System Settings**.
   - Click **Environment Variables**.
   - Edit the **Path** variable under **System Variables** and add the folder path.

### On macOS/Linux
1. Open a terminal.
2. Move the downloaded file to `/usr/local/bin` for global use:
   ```bash
   mv ~/Downloads/ngrok /usr/local/bin/ngrok
   ```
3. Grant execute permissions:
   ```bash
   chmod +x /usr/local/bin/ngrok
   ```

---

## Step 3: Connect Your ngrok Account

1. Log in to your ngrok account on the website.
2. Locate your **authtoken** in the dashboard.
3. In your terminal, run:
   ```bash
   ngrok config add-authtoken YOUR_AUTHTOKEN
   ```
   Replace `YOUR_AUTHTOKEN` with the token from your ngrok dashboard.

---

## Step 4: Start ngrok

1. Open your terminal or command prompt.
2. Run the following command to expose your local server (e.g., running on port 8000):
   ```bash
   ngrok http http://localhost:8080
   ```
   Or use you local IP and PORT:
    ```bash
   ngrok http http://192.168.10.70:3000
   ```
4. ngrok will provide a public URL that you can share to access your local server from the internet.

---

## Step 5: Additional Features

### Subdomain (Pro Feature)
To use a custom subdomain (Pro plan required):
```bash
ngrok http --subdomain=your-subdomain 8000
```

### Inspect Traffic
ngrok provides a web interface to inspect traffic:
- Open [http://localhost:4040](http://localhost:4040) in your browser.

---

## Step 6: Stop ngrok
To stop ngrok, press `Ctrl+C` in the terminal running ngrok.

---

## Troubleshooting

- **Error: 'Command not found'**: Ensure ngrok is installed correctly and added to the PATH.
- **Connection Refused**: Verify that your local server is running and accessible on the specified port.

---

For detailed documentation, visit the [ngrok Docs](https://ngrok.com/docs/).
