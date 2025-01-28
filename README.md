# LinuxDoctor

To install Arch Linux alongside Windows on your NVMe SSD, follow these steps. Since you've decided to use the `archinstall` tool, this will streamline the process. Make sure you back up any important data from your personal file partition to avoid accidental loss.

### Steps to Install Arch Linux on `nvme0n1p5`

---

#### **1. Prepare Your System**
1. **Download the Arch Linux ISO**:
   - Get the latest Arch Linux ISO from the official website: [Arch Linux Downloads](https://archlinux.org/download/).

2. **Create a Bootable USB**:
   - Use tools like Rufus (Windows) or `dd` (Linux) to create a bootable USB drive with the Arch Linux ISO.

3. **Boot into Live Environment**:
   - Restart your system and boot into the Arch Linux USB via BIOS/UEFI boot menu.

---

#### **2. Verify Disk Layout**
1. Check your disk layout with:
   ```bash
   lsblk
   ```
   - Identify your partitions and confirm `nvme0n1p5` is the one intended for Arch Linux installation.

2. **Unmount Any Mounted Partitions**:
   If any partitions are mounted, unmount them:
   ```bash
   umount /dev/nvme0n1p5
   ```

---

#### **3. Launch `archinstall` Tool**
1. Start the `archinstall` script:
   ```bash
   archinstall
   ```

2. **Interactive Setup**:
   - **Select Keyboard Layout**: Choose your preferred layout.
   - **Select Mirrors**: Use the default mirrors or customize for faster download speeds.
   - **Disk Selection**: Choose `nvme0n1p5` as the installation partition.
   - **Formatting**: Select `ext4` (or another Linux file system) to format the partition.
   - **Bootloader**:
     - Choose `systemd-boot` or `GRUB` as your bootloader.
     - Configure it to recognize both Windows and Arch Linux for dual booting.
   - **Root Password**: Set a root password.
   - **User Creation**: Create a regular user account.

3. Proceed with the installation by following the prompts. The tool will automate the process.

---

#### **4. Configure Dual Boot**
1. After installation, ensure your bootloader is configured to dual-boot Windows and Arch Linux:
   - If using `systemd-boot`, ensure the `loader.conf` file includes both OS entries.
   - If using GRUB, update the configuration:
     ```bash
     grub-mkconfig -o /boot/grub/grub.cfg
     ```

2. Reboot to test if you can select between Windows and Arch Linux.

---

#### **5. Post-Installation**
1. After booting into Arch Linux, update your system:
   ```bash
   pacman -Syu
   ```

2. Install essential tools and configure additional settings as needed.

3. If required, reinstall `os-prober` (useful for detecting other OSes):
   ```bash
   pacman -S os-prober
   grub-mkconfig -o /boot/grub/grub.cfg
   ```

---

### Notes
- Make sure `Secure Boot` is disabled in your BIOS/UEFI.
- Back up all critical data before modifying partitions.


To ensure you format only the `nvme0n1p5` partition for Arch Linux without affecting other partitions, follow these steps carefully:

---

### **Step-by-Step Guide to Partition and Format `nvme0n1p5`**

---

#### **1. Verify the Partition**
- Boot into the Arch Linux live environment.
- Use `lsblk` to list your partitions and confirm `nvme0n1p5` is the correct partition:
  ```bash
  lsblk
  ```
  Output example:
  ```
  nvme0n1      931.5G
  ├─nvme0n1p1    100M  (EFI - Windows Boot)
  ├─nvme0n1p2    200G  (Windows OS)
  ├─nvme0n1p3    300G  (Personal Files)
  ├─nvme0n1p4    ---
  ├─nvme0n1p5    100G  (Partition for Arch Linux)
  ```

#### **2. Unmount the Partition**
- If `nvme0n1p5` is mounted, unmount it:
  ```bash
  umount /dev/nvme0n1p5
  ```

#### **3. Format `nvme0n1p5`**
- Choose the file system you want for Arch Linux. Most common choices are:
  - **ext4**: Default Linux file system.
  - **btrfs**: Modern file system with snapshot features.

- Format the partition (this will erase only `nvme0n1p5`):
  - For `ext4`:
    ```bash
    mkfs.ext4 /dev/nvme0n1p5
    ```
  - For `btrfs`:
    ```bash
    mkfs.btrfs /dev/nvme0n1p5
    ```

#### **4. Mount the Partition**
- After formatting, mount `nvme0n1p5` to a directory (e.g., `/mnt`) for installation:
  ```bash
  mount /dev/nvme0n1p5 /mnt
  ```

#### **5. Set Up EFI (if needed)**
- If your system is UEFI, ensure the EFI partition (usually `nvme0n1p1`) is mounted as well:
  ```bash
  mkdir -p /mnt/boot
  mount /dev/nvme0n1p1 /mnt/boot
  ```

#### **6. Proceed with Installation**
- After formatting and mounting `nvme0n1p5`, you can safely proceed with the Arch Linux installation using `archinstall`. The tool will use `/mnt` as the root installation target without affecting other partitions.

---

### **Precautions**
- **Double-check Partition Names**: Use `lsblk` or `fdisk -l` to ensure you're working with the correct partition.
- **Backup Data**: Ensure all critical data on other partitions is backed up, even if you’re not modifying them.
- **Do Not Select "Wipe Disk"**: During `archinstall`, ensure you select the manual disk partitioning option and do not choose "Wipe Disk," as this erases the entire drive.



To access your Arch Linux system from Windows using SSH, you need to configure your Linux system as an SSH server and use an SSH client on Windows. Here’s a detailed guide:

---

### **Steps to Set Up SSH Access**

#### **1. Install SSH Server on Arch Linux**
1. Boot into your Arch Linux system.
2. Install the `openssh` package:
   ```bash
   sudo pacman -S openssh
   ```

3. Enable and start the SSH service:
   ```bash
   sudo systemctl enable sshd
   sudo systemctl start sshd
   ```

4. Verify the SSH service is running:
   ```bash
   systemctl status sshd
   ```
   You should see a message indicating that the SSH server is active and running.

---

#### **2. Check Your Linux System's IP Address**
1. Find your system's IP address:
   ```bash
   ip addr
   ```
   Look for the `inet` address under your active network interface (e.g., `eth0` or `wlan0`).

   Example:
   ```
   inet 192.168.1.100/24
   ```
   The IP address here is `192.168.1.100`.

2. Make sure your Linux system is reachable from Windows by pinging it:
   ```cmd
   ping 192.168.1.100
   ```
   Replace `192.168.1.100` with your Linux system’s IP address.

---

#### **3. Configure the Firewall (if applicable)**
If you use a firewall on Arch Linux, allow SSH connections (port 22):
```bash
sudo ufw allow ssh
sudo ufw enable
```

---

#### **4. Use an SSH Client on Windows**
1. **Option 1: Use Windows Built-In SSH Client**
   - Open PowerShell or Command Prompt.
   - Use the `ssh` command to connect to your Linux system:
     ```bash
     ssh username@192.168.1.100
     ```
     Replace `username` with your Linux username and `192.168.1.100` with the IP address of your Linux machine.

2. **Option 2: Use PuTTY (Third-Party SSH Client)**
   - Download and install [PuTTY](https://www.putty.org/).
   - Open PuTTY and:
     - Enter the IP address of your Linux system in the "Host Name (or IP address)" field.
     - Set the port to `22`.
     - Click "Open" to connect.
   - Log in with your Linux username and password.

---

#### **5. (Optional) Set Up a Static IP for Linux**
If your Linux system's IP address changes frequently, configure a static IP or use DHCP reservation on your router.

---

#### **6. Test SSH Access**
After setting up everything:
- Open your SSH client on Windows.
- Enter your Linux username and password when prompted.
- You should now have remote access to your Arch Linux system.

---

### **Optional: Improve Security**
- **Change Default SSH Port**: Edit `/etc/ssh/sshd_config` and change the `Port` setting.
- **Use SSH Key Authentication**: Generate SSH keys on Windows using `ssh-keygen` and copy the public key to your Linux system (`~/.ssh/authorized_keys`).
- **Disable Root Login**: In `/etc/ssh/sshd_config`, set:
  ```text
  PermitRootLogin no
  ```
  Restart the SSH service:
  ```bash
  sudo systemctl restart sshd
  ```

