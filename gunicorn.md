# Internal Dialogue Application

This document provides step-by-step instructions to set up, run, and deploy the Internal Dialogue Django application using a Python virtual environment, tmux for session management, Gunicorn as the WSGI server, and systemd for service management.

---

## Prerequisites

* **Python 3.6+** installed on your system
* **pip** (Python package installer)
* **tmux** for terminal multiplexing
* **systemd** (for service management)
* **sudo** privileges for creating system directories and services

---

## 1. Clone the Repository

```bash
git clone <your-repo-url>
cd <your-repo-directory>
```

---

## 2. Set Up a Python Virtual Environment

1. **Create and activate** the virtual environment:

   ```bash
   python -m venv venv
   source venv/bin/activate       # On Windows: venv\Scripts\activate
   ```

2. **Install project dependencies** inside the virtual environment:

   ```bash
   pip install -r requirements.txt
   pip install gunicorn            # Ensure Gunicorn is installed in the venv
   ```

3. **Exit** the virtual environment when done:

   ```bash
   deactivate
   ```

---

## 3. Prepare Static Files Directory

Create the directory where static assets will be collected:

```bash
sudo mkdir -p /var/www/flashlubitshwhi-Internal-dialogue/static
sudo chown $USER:$USER /var/www/flashlubitshwhi-Internal-dialogue/static
```

---

## 4. Database Migrations

1. **Activate** the virtual environment again:

   ```bash
   source venv/bin/activate
   ```

2. **Generate and apply** database migrations:

   ```bash
   python manage.py makemigrations
   python manage.py migrate
   ```

---

## 5. Running the Development Server

Start the Django development server on port 8000:

```bash
python manage.py runserver 0.0.0.0:8000
```

Access the application at `http://<server-ip>:8000/`.

---

## 6. Using tmux for Session Management

1. **Open** a new tmux session:

   ```bash
   ```

tmux new -s internal-dialogue

````

2. **Create a new window** within tmux (press <kbd>Ctrl</kbd>+<kbd>b</kbd>, then <kbd>c</kbd>):
- Window 1: Run the Django development server.
- Window 2: Run Gunicorn (for production).

3. **Detach** from tmux (press <kbd>Ctrl</kbd>+<kbd>b</kbd>, then <kbd>d</kbd>) and **re-attach** later:

```bash
tmux attach -t internal-dialogue
````

---

## 7. Running with Gunicorn (Production)

In a separate tmux window, **activate** the virtual environment and start Gunicorn:

```bash
source venv/bin/activate
gunicorn --bind 0.0.0.0:8001 internal_dialogue.wsgi:application
```

This binds the app to port 8001.

---

## 8. Setup systemd Service for Gunicorn

1. **Create** the service file:

   ```bash
   ```

sudo nano /etc/systemd/system/gunicorn.service

````

2. **Paste** the following configuration into `gunicorn.service`:

```ini
[Unit]
Description=Gunicorn daemon for Internal Dialogue
After=network.target

[Service]
User=<your-username>
Group=www-data
WorkingDirectory=/path/to/your/repo
ExecStart=/path/to/your/repo/venv/bin/gunicorn \
 --access-logfile - \
 --workers 3 \
 --bind 0.0.0.0:8001 \
 internal_dialogue.wsgi:application

[Install]
WantedBy=multi-user.target
````

> **Note:** Replace `<your-username>` and `/path/to/your/repo` with your actual user and project path.

3. **Reload** systemd to apply the new service:

```bash
sudo systemctl daemon-reload
```

4. **Enable** Gunicorn to start on boot:

```bash
sudo systemctl enable gunicorn
```

5. **Start** the Gunicorn service:

```bash
sudo systemctl start gunicorn
```

6. **Check** the status of the service:

```bash
sudo systemctl status gunicorn
```

---

## 9. Collect Static Files (Optional for Production)

If you plan to serve static files via a web server (e.g., Nginx), collect them:

```bash
source venv/bin/activate
python manage.py collectstatic
```

The files will be placed in `/var/www/flashlubitshwhi-Internal-dialogue/static` as configured.

---

## 10. Conclusion

You now have the Internal Dialogue application running in development and production modes. Use tmux to manage your sessions, and systemd to keep Gunicorn running as a service. Happy coding!
