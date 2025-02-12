Here’s a handy **tmux cheat sheet** with the most commonly used commands and shortcuts. Tmux is a terminal multiplexer that allows you to manage multiple terminal sessions within a single window.

---

### **Starting and Managing Sessions**
| Command/Shortcut               | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| `tmux`                         | Start a new session.                                                       |
| `tmux new -s session_name`     | Start a new session with a specific name.                                  |
| `tmux ls`                      | List all active sessions.                                                  |
| `tmux attach -t session_name`  | Attach to a specific session by name.                                      |
| `tmux kill-session -t session_name` | Kill a specific session by name.                                       |
| `tmux kill-server`             | Kill all sessions and stop the tmux server.                                |

---

### **Pane Management**
| Shortcut                        | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| `Ctrl+b %`                      | Split the current pane vertically.                                         |
| `Ctrl+b "`                      | Split the current pane horizontally.                                       |
| `Ctrl+b arrow_key`              | Move between panes (e.g., `Ctrl+b →` to move right).                        |
| `Ctrl+b x`                      | Close the current pane.                                                    |
| `Ctrl+b z`                      | Zoom into the current pane (maximize). Press again to restore.             |
| `Ctrl+b {`                      | Move the current pane to the left.                                         |
| `Ctrl+b }`                      | Move the current pane to the right.                                        |
| `Ctrl+b Space`                  | Toggle between pane layouts.                                               |
| `Ctrl+b Alt+arrow_key`          | Resize the current pane (e.g., `Ctrl+b Alt+→` to resize right).            |

---

### **Window Management**
| Shortcut                        | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| `Ctrl+b c`                      | Create a new window.                                                       |
| `Ctrl+b ,`                      | Rename the current window.                                                 |
| `Ctrl+b n`                      | Switch to the next window.                                                 |
| `Ctrl+b p`                      | Switch to the previous window.                                             |
| `Ctrl+b 0-9`                    | Switch to a specific window by number (e.g., `Ctrl+b 2` for window 2).     |
| `Ctrl+b w`                      | List all windows for selection.                                            |
| `Ctrl+b &`                      | Close the current window.                                                  |

---

### **Session Management**
| Shortcut                        | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| `Ctrl+b d`                      | Detach from the current session (session continues running in the background).|
| `Ctrl+b s`                      | List all sessions for selection.                                           |
| `Ctrl+b $`                      | Rename the current session.                                                |

---

### **Copy Mode (Scroll and Select Text)**
| Shortcut                        | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| `Ctrl+b [`                      | Enter copy mode (scroll and select text).                                  |
| `Ctrl+Space`                    | Start selecting text in copy mode.                                         |
| `Alt+w`                         | Copy the selected text to the tmux buffer.                                 |
| `Ctrl+b ]`                      | Paste the text from the tmux buffer.                                       |
| `q`                             | Exit copy mode.                                                            |

---

### **Miscellaneous**
| Shortcut                        | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| `Ctrl+b ?`                      | Show all key bindings (help).                                              |
| `Ctrl+b :`                      | Enter command mode (e.g., to run commands like `kill-session`).            |
| `Ctrl+b t`                      | Show a clock in the current pane.                                          |
| `Ctrl+b r`                      | Refresh the current client.                                                |
| `Ctrl+b l`                      | Switch to the last active window or pane.                                  |

---

### **Customizing tmux**
You can customize tmux by editing the `~/.tmux.conf` file. Here are some common configurations:
```bash
# Set prefix to Ctrl+a instead of Ctrl+b
unbind C-b
set-option -g prefix C-a
bind C-a send-prefix

# Enable mouse support
set -g mouse on

# Set default terminal to 256 colors
set -g default-terminal "screen-256color"

# Start window and pane numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Reload tmux config without restarting
bind r source-file ~/.tmux.conf \; display "Reloaded tmux config!"
```

---

Let me know if you need further clarification or advanced tmux tips! 😊
