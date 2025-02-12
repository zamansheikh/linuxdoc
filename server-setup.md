To view your current SSH public key in Windows, you can follow these steps:

1. **Open Command Prompt or PowerShell**: Press `Win + R`, type `cmd` or `powershell`, and press Enter.

2. **Navigate to the `.ssh` Directory**: By default, SSH keys are stored in the `.ssh` directory within your user profile. Use the following command to navigate to this directory:

   ```sh
   cd %USERPROFILE%\.ssh
   ```

3. **List the Contents of the `.ssh` Directory**: Use the `dir` command to list the files in the directory:

   ```sh
   dir
   ```

   Look for files named `id_rsa.pub` or `id_ed25519.pub`. These are your public key files. The `.pub` extension indicates that it's a public key.

4. **View the Public Key**: Use the `type` command to display the contents of the public key file. For example:

   ```sh
   type id_rsa.pub
   ```

   or

   ```sh
   type id_ed25519.pub
   ```

   This will display your SSH public key in the terminal.

If you don't see these files, it means you might not have generated an SSH key pair yet. You can generate a new SSH key pair using the following command:

```sh
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Follow the prompts to save the key pair, and then you can view the public key as described above.


The error message `Permission denied (publickey)` indicates that the SSH server is not accepting your public key for authentication. Here are some steps to troubleshoot and resolve this issue:

1. **Ensure the Public Key is Added to the Droplet**:
   - Log in to your cloud provider's control panel (e.g., DigitalOcean).
   - Navigate to your Droplet's settings or access section.
   - Ensure that your public key (`id_rsa.pub`) is added to the list of authorized keys for the `root` user.

2. **Check SSH Key Permissions**:
   - Ensure that the permissions for the `.ssh` directory and the `authorized_keys` file on the Droplet are correct.
   - On the Droplet, run the following commands:
     ```sh
     chmod 700 ~/.ssh
     chmod 600 ~/.ssh/authorized_keys
     ```

3. **Verify SSH Configuration**:
   - Ensure that the SSH daemon on the Droplet is configured to allow public key authentication.
   - Check the `/etc/ssh/sshd_config` file on the Droplet for the following settings:
     ```
     PubkeyAuthentication yes
     AuthorizedKeysFile .ssh/authorized_keys
     ```
   - After making changes, restart the SSH service:
     ```sh
     sudo systemctl restart sshd
     ```

4. **Check for Correct Key Usage**:
   - Ensure that you are using the correct private key. If you have multiple keys, specify the correct one using the `-i` option:
     ```sh
     ssh -i ~/.ssh/id_rsa root@45.55.209.88
     ```

5. **Debugging SSH Connection**:
   - Use the `-v` flag for verbose output to get more details about the connection attempt:
     ```sh
     ssh -v root@45.55.209.88
     ```

6. **Password Authentication**:
   - If you have enabled password authentication, ensure that the root password is correctly set and known.

If you have followed these steps and still encounter issues, double-check that the IP address and the username (`root`) are correct. If the problem persists, you may need to contact your cloud provider's support for further assistance.

systemctl daemon-reload
#   systemctl restart ssh.socket
