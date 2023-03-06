# deployInstraction

<h1>Initial requirements.txt file</h1>
```
Django==4.1.6
gunicorn==20.1.0
Pillow==9.3.0
psycopg2-binary==2.9.5
python-dotenv==0.21.0
whitenoise==6.2.0
```

<h1>Configure Django after deploy</h1>

<h2>Settings.py</h2>

<h3>Add dotenv in your project, that store private data ( e.g DJANGO_SECRET_KEY or DB data )</h3>

```
from django.conf import settings
from dotenv import load_dotenv

load_dotenv()
```

<h3>In main folder create .env file</h3>
```
DJANGO_SECRET_KEY=key
POSTGRES_PORT=port ( default - 5432 )
POSTGRES_HOST=host ( which in docker-compose )
POSTGRES_USER=user_name
POSTGRES_PASSWORD=password
POSTGRES_DB=db ( which in docker-compose )
```

<h2>Fix some fields in your settings.py file</h2>

<h3>Get DJANGO_SECRET_KEY form your .env file</h3>

```
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY")
```

<h3>Set DEBAG to False</h3>

```
DEBUG = False
```

<h3>Add to ALLOWED_HOSTS server IP and domain. And set CSRF politic</h3>
```
ALLOWED_HOSTS = ["0.0.0.0", "server_ip", "ex.ru"]
CSRF_TRUSTED_ORIGINS = ['https://ex.ru']
CSRF_COOKIE_SECURE = True
```

<h3>Add to INSTALLED_APPS whitenoise libary and staticfiles fields, that to get static files on server</h3>

```
INSTALLED_APPS = [
    'whitenoise.runserver_nostatic',
    'django.contrib.staticfiles',
]
```

<h3>Add whitenoise to MIDDLEWARE</h3>
```
MIDDLEWARE = [
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
]
```


<h3>Change your DB to Postgres</h3>
```
if DEBUG:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
else:
    DATABASES = {
        'default': {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.environ.get("POSTGRES_DB"),
            "USER": os.environ.get("POSTGRES_USER"),
            "PASSWORD": os.environ.get("POSTGRES_PASSWORD"),
            "HOST": os.environ.get("POSTGRES_HOST"),
            "PORT": os.environ.get("POSTGRES_PORT"),
        }
    }
```

<h3>Configur your static and media files path</h3>
```
STATIC_URL = '/static/'
STATIC_ROOT = 'static'

MEDIA_URL = '/media/'
MEDIA_ROOT = 'media'

STATICFILES_STORAGE = 'whitenoise.storage.CompressedStaticFilesStorage'
```

<h2>Add some files to urls.py</h2>

<h3>Connect your static and media files</h3>

```
from core import views
from django.contrib import admin
from django.urls import path, include
from django.conf.urls.static import static
from App import settings


urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('core.urls')),
]

urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
```

<h2>Create Dockerfile in main folder</h2>

```
FROM python:3

SHELL ["/bin/bash", "-c"]

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

RUN pip install --upgrade pip

RUN useradd -rms /bin/bash <USER> && chmod 777 /opt /run

WORKDIR /<USER>
RUN mkdir /<USER>/static && mkdir /<USER>/media && chown -R <USER>:<USER> /<USER> && chmod 775 /<USER>

COPY --chown=<USER>:<USER> . .

RUN pip install -r requirements.txt

USER <USER>

CMD ["gunicorn", "-b", "0.0.0.0:8000", "App.wsgi:application"]
```

<h2>Create docker-compose.yml file in main folder</h2>

```
version: "3.9"

services:
  postgres:
    image: postgres:15
    container_name: postgres
    volumes:
      - ~/.pg/pg_data/<USER>/var/lib/postgresql/data # save db files to folder
    env_file:
      - .env

  web:
    build: .
    depends_on:
      - postgres
    volumes:
      - static_volume:/<USER>/static # get static from prodject folder
      - media_volume:/<USER>/media # get media from prodject folder
    env_file:
      - .env
    command: >
      bash -c "python manage.py collectstatic --noinput && python manage.py makemigrations && python manage.py migrate && python manage.py makemigrations core && python manage.py migrate core && gunicorn -b 0.0.0.0:8000 App.wsgi:application" # start django App on 8000 port
  nginx:
    build:
      dockerfile: ./Dockerfile
      context: ./docker/nginx/
    container_name: nginx
    image: nginx
    volumes:
      - static_volume:/<USER>/static # get static from prodject folder 
      - media_volume:/<USER>/media # get media from prodject folder

    depends_on:
      - web
    ports:
      - "80:80" # for HTTP connection 
      - "443:443" # for SSL, HTTPS connection

volumes:
  static_volume: # connect static
  media_volume: # connect media
```

<h2>Create nginx config</h2>

<h3>Create docker folder in main directory</h3>
```
sudo mkdir /docker/
sudo  /docker/nginx.conf #file

```

<h3>Configure Dockerfile for nginx</h3>

```
# in docker filder
sudo nano /docker/Dockerfile #file
```

```
FROM nginx:latest

SHELL ["/bin/bash", "-c"]

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d
COPY proxy_params /etc/nginx

RUN apt-get update && apt-get install -y apt-transport-https
RUN apt-get install -y --no-install-recommends certbot python3-certbot-nginx
```

<h3>Configure nginx.conf</h3>

```
# in docker folder

upstream web {
    server web:8000;
}

server {
    listen 80;
    listen [::]:80;
    server_name mydomain.ru;

    location / {
        proxy_pass http://web;
        include proxy_params;
    }

    location /static/ {
        alias /<USER>/static/;
    }

    location /media/ {
        alias /<USER>/media/;
    }

    client_max_body_size 20M;
}
```

<h3>Configure proxy_params file</h3>

```
proxy_set_header Host $http_host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-NginX-Proxy true;
proxy_set_header Upgrade $http_upgrade;
proxy_pass_header Set-Cookie;
```


<h1>On Server with Docker</h1>

<h3>Add new user:</h3>

```
sudo adduser <User>
sudo adduser <User> sudo
sudo usermod -aG sudo <User>
```

<h3>Provide to new user</h3>

```
sudo su - <User>
```

<h3>Init git repo</h3>

```
sudo git init
sudo git clone <https://myrepo>
cd <Repo folder>
```

<h3>Installing some dependencies</h3>
<h4>Update Ubuntu</h4>

```
sudo apt-get update
```

<h4>Install python, pip and venv</h4>

```
sudo apt-get install python3 python3-pip python3-virtualenv
```

<h4>Install apparmor</h4>

```
sudo apt install apparmor -y
```

<h3>Activate venv</h3>

```
sudo virtualenv venv
```

```
source venv/bin/activate
```

<h2>Start docker</h2>

<h3>docker-compose up</h3>

```
sudo docker-compose up -d --build
```

<h2>Useful commands for docker</h2>

<h3>Check all docker containers</h3>

```
sudo docker ps
```

<h3>Delete all docker containers</h3>

```
sudo docker ps -aq | sudo xargs docker stop | sudo xargs docker rm
```

```
sudo docker system prune
```

```
sudo docker images

sudo docker rmi <image id>
```

<h3>Bash to docker container</h3>

```
sudo docker exec -it <container id> bash
```

<h2>Intsall certbot ( add HTTPS and SSL certificates )</h2>

<h3>Bash to nginx container</h3>

```
sudo docker -it <nginx container id> bash
```

<h3>Create certificates for your domain and add in to nginx config</h3>

```
certbot --nginx --email myemail@email.com --agree-tos --no-eff-email -d www.mydomain.com
```

<h3>Chelck new certificates</h3>

```
cat /etc/nginx/conf.d/default.conf
```

<h3>After that, you should have it: </h3>
```
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name mydomain.com;

    location /static {
        alias /vol/static;
    }

    location / {
        proxy_pass app:8000;
        include proxy_params;
    }

    client_max_body_size 20M;

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/mydomain.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/mydomain.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = mydomain.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80 default_server;
    listen [::]:80 default_server;
    server_name mydomain.com;
    return 404; # managed by Certbot
}
```

<h3>Exit nginx container</h3>

```
Press Ctrl + D
```

<h2>Its All, Thank you</h2>
