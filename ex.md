To execute your script directly from GitHub, follow these steps:

### 1. **Using `curl` and `bash`**
Run this command in your terminal to download and execute the script in one step:
```bash
curl -sSL https://raw.githubusercontent.com/zamansheikh/LinuxDoctor/main/sdk-setup.sh | bash
```
- `-sSL`: Ensures silent mode and follows redirects.
- `bash`: Executes the script immediately.

---

### 2. **Using `wget` and `bash`**
If you prefer `wget`, use:
```bash
wget -qO- https://raw.githubusercontent.com/zamansheikh/LinuxDoctor/main/sdk-setup.sh | bash
```
- `-qO-`: Downloads the script and pipes it to `bash`.

---

### 3. **Download and Execute Manually**
If you want to inspect the script before executing:
```bash
wget https://raw.githubusercontent.com/zamansheikh/LinuxDoctor/main/sdk-setup.sh
chmod +x sdk-setup.sh
./sdk-setup.sh
```

---

### 4. **Execute with `sudo` (If Required)**
If your script requires `sudo`, use:
```bash
curl -sSL https://raw.githubusercontent.com/zamansheikh/LinuxDoctor/main/sdk-setup.sh | sudo bash
```
⚠️ **Warning:** Running scripts directly from the internet with `sudo` can be risky. Make sure to review the script before executing with elevated privileges.

---

Let me know if you need any modifications! 🚀
