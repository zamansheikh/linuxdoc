To connect to your Windows machine using SSH, run this command on your client machine:  

bash
ssh user@115.127.156.13


Replace `user` with your actual Windows username.

---

### *If You Set Up SSH Keys*
If you've already added your *public key* to `C:\Users\USER\.ssh\authorized_keys`, the connection should work *without a password*.

---

### *If It Asks for a Password*
- Enter your *Windows login password*.
- If login fails, ensure your firewall allows SSH and that the OpenSSH server is running:
  powershell
  Get-Service sshd
  

---

### *If Connection Is Refused*
- Make sure your router/firewall allows *port 22* for SSH.
- Check if the OpenSSH service is running on your Windows machine:
  powershell
  netstat -an | findstr :22
  

Let me know if you run into any issues! 🚀


To generate an SSH key pair and add the public key to your Windows OpenSSH server, follow these steps:

---

### *Step 1: Generate SSH Key on the Client Machine*  
On the machine you want to connect *from* (Linux, Mac, or Windows), open a terminal and run:  
bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
  
- `-t rsa` → Specifies RSA as the key type  
- `-b 4096` → Creates a 4096-bit key for better security  
- `-f ~/.ssh/id_rsa` → Saves the key in the default location  

*Press Enter* to accept the default save location (`~/.ssh/id_rsa`).  
You can *set a passphrase* for extra security or leave it empty.

---

### *Step 2: Copy the Public Key to Your Windows Machine*  
Now you need to transfer the *public* key (`id_rsa.pub`) to your Windows machine.

#### *Option 1: Use SSH Copy (if SSH already works with a password)*
If you can connect to your Windows machine using a password, run:  
bash
ssh-copy-id user@your_windows_ip

Replace `user` with your Windows username and `your_windows_ip` with the actual IP.

#### *Option 2: Manually Copy the Key (if SSH isn't accessible yet)*  
1. Open the *public key* file on the client machine:  
   bash
   cat ~/.ssh/id_rsa.pub
   
   Example output:
   
   ssh-rsa AAAAB3...your_public_key_here... user@client-machine
   
2. *On Your Windows Machine*, manually add the key to the `authorized_keys` file:  
   - Open *Notepad* or *PowerShell* on Windows.
   - Open the file:
     powershell
     notepad C:\Users\USER\.ssh\authorized_keys
     
   - Paste the entire public key from Step 1 into this file.
   - Save and close the file.

---

### *Step 3: Ensure Correct Permissions on Windows*
Run the following commands in *PowerShell (Run as Administrator)* on the Windows machine:

powershell
# Set correct permissions for the SSH folder
icacls C:\Users\USER\.ssh\authorized_keys /inheritance:r /grant USER:F

Replace `USER` with your actual Windows username.

---

### *Step 4: Restart the SSH Service on Windows*
Run in PowerShell (Admin):
powershell
Restart-Service sshd

OR
powershell
net stop sshd
net start sshd


---

### *Step 5: Test SSH Key Authentication*
Now, on your *client machine*, try to SSH into Windows:
bash
ssh user@your_windows_ip

If everything is set up correctly, it should log in *without asking for a password*! 🎉  

Would you like to also configure auto-login with an SSH config file? 🚀
