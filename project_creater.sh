#!bin/bash

usage() {
  echo "Usage ${0} -p [-dasm]" >&2
  echo 'Create a Django project.' >&2
  echo '  -p  PROJECT_NAME  Specify the project name.' >&2
  echo '  -d  DATABASE      Database name.' >&2
  echo '  -a  APP(S)        App(s) to be created and set up.' >&2
  echo '  -s                Update settings: add static root rules.'
  echo '  -m                Update settings: add media root rules.'
  exit 1
}
# Check required packages are installed.
if [[ $(dpkg -l | grep python3 | wc -l) -eq 0 ]]; then
  echo "Install python3 and try again." >&2
  exit 1
fi

if [[ $(dpkg -l | grep python3-venv | wc -l) -eq 0 ]]; then
  echo "Install python3-venv and try again." >&2
  exit 1
fi

# Install Pip3
if [[ $(dpkg -l | grep python3-pip | wc -l) -eq 0 ]]; then
  echo "Install pip3 and try again" >&2
  exit 1
fi

while getopts p:d:a:sm OPTION; do
  case ${OPTION} in
  p)
    PROJECT_NAME="${OPTARG}"
    ;;
  d)
    DATABASE="${OPTARG}"
    ;;
  a)
    APPS="${APPS},${OPTARG}"
    PARSE_APPS_PATTERN="s/,/\\n/g"
    ;;
  s)
    ADD_STATIC_ROOT_RULES=1
    ;;
  m)
    ADD_MEDA_ROOT_RULES=1
    ;;
  ?)
    usage
    ;;
  esac
done

# Ensure that a package name has been defined.
# if [[ $($PROJECT_NAME | wc -l) -eq 0 ]]
if [[ -z "${PROJECT_NAME}" ]]; then
  usage
fi

# Create and activate virtual environment.
python3 -m venv venv
source venv/bin/activate

# Install python packages.
pip3 install django

case "${DATABASE}" in
postgresql | postgres)
  # Sometimes there is an issue with install psycopg2 on linux.
  POST_MSG="${POST_MSG}Run pip3 install pyscopg2\n"
  ;;
oracle)
  pip install cx_Oracle
  ;;
mysql)
  pip install mysql-connector-python
  ;;
?)
  POST_MSG="${POST_MSG}Database (${DATABASE}) not recognised.\n"
  POST_MSG="${POST_MSG}Please run pip install manually.\n"
  ;;
esac

# Start django project.
django-admin startproject "${PROJECT_NAME}"
cd "${PROJECT_NAME}"

# Django start app
echo "${APPS}" | sed "{$PARSE_APPS_PATTERN}" | {
  while read app; do
    if [[ $(echo "${app}" | wc -w) -ne 0 ]]; then
      python3 manage.py startapp "${app}"
    fi
  done
}

# Update settings.
cd "${PROJECT_NAME}"

# Static root rules.
if [[ "${ADD_STATIC_ROOT_RULES}" -eq 1 ]]; then
  echo "STATIC_ROOT = os.path.join(BASE_DIR, 'static')" >>settings.py
  echo "STATICFILES_DIRS = [" >>settings.py
  echo "    os.path.join(BASE_DIR, '${PROJECT_NAME}/static')," >>settings.py
  echo "]" >>settings.py
  echo "" >>settings.py
fi

# Media root rules.
if [[ "${ADD_MEDA_ROOT_RULES}" -eq 1 ]]; then
  echo "# Media Folder Settings" >>settings.py
  echo "MEDIA_ROOT = os.path.join(BASE_DIR, 'media')" >>settings.py
  echo "MEDIA_URL = '/media/'" >>settings.py
  echo "" >>settings.py
fi

# Update ``SECRET_KEY``, ``DEBUG`` and ``TEMPLATES`` variables.
sed -i.bak "s/from pathlib import Path/from pathlib import Path\nimport os/" settings.py
DJANGO_SECRET_KEY=$(grep SECRET_KEY settings.py | awk -F"'" '{print $2}')
POST_MSG="${POST_MSG}Run export DJANGO_SECRET_KEY='${DJANGO_SECRET_KEY}'\n"
sed -i.bak "s/SECRET_KEY = '.*/SECRET_KEY = os.getenv('DJANGO_SECRET_KEY')/" settings.py
sed -i.bak "s/DEBUG = True/DEBUG = bool(int(os.getenv('DJANGO_DEBUG', 0)))/" settings.py
sed -i.bak "s/'DIRS': \[\],/'DIRS': [os.path.join(BASE_DIR, 'templates')],/" settings.py

# Update database settings.
if [[ -z "${DATABASE}" ]]; then
  POST_MSG="${POST_MSG}Database argument is not set.\n"
  POST_MSG="${POST_MSG}Database settings will not be updated.\n"
  POST_MSG="${POST_MSG}Creating sqlite3 database.\n"
  touch ../db.sqlite3
  chmod 755 ../db.sqlite3
else
  case "${DATABASE}" in
  postgres | postgresql)
    POST_MSG="${POST_MSG}Run export DB_ENGINE=django.db.backends.postgresql\n"
    DATABASE_SETTINGS_UPDATED=1
    ;;
  mysql)
    POST_MSG="${POST_MSG}Run export DB_ENGINE=django.db.backends.mysql\n"
    DATABASE_SETTINGS_UPDATED=1
    ;;
  oracle)
    POST_MSG="${POST_MSG}Run export DB_ENGINE=django.db.backends.oracle\n"
    DATABASE_SETTINGS_UPDATED=1
    ;;
  ?)
    POST_MSG="{$POST_MSG}Database (${DATABASE}) not recognised.\n"
    POST_MSG="{$POST_MSG}Please update database settings manually.\n"
    ;;
  esac

  if [[ "${DATABASE_SETTINGS_UPDATED}" -eq 1 ]]; then
    sed -i.bak "s/'django.db.backends.sqlite3',/os.getenv('DB_ENGINE'),/" settings.py
    sed -i.bak "s/BASE_DIR \/ 'db.sqlite3',/os.getenv('DB_NAME'),\n\t\t'USER': os.getenv('DB_USER'),\n\t\t'PASSWORD': os.getenv('DB_PASSWORD'),\n\t\t'PORT': os.getenv('DB_PORT'),\n\t\t'HOST': os.getenv('DB_HOST')/" settings.py
  fi
fi

# Update root URLs.
echo -e '"""Root URL Configurations."""' >urls.py
echo -e "from django.contrib import admin" >>urls.py
echo -e "from django.urls import path, include" >>urls.py
echo -e "from django.conf import settings" >>urls.py
echo -e "from django.conf.urls.static import static" >>urls.py
echo -e "" >>urls.py
echo -e "" >>urls.py
echo -e "urlpatterns = [" >>urls.py
echo -e "\tpath('admin/', admin.site.urls)," >>urls.py

echo "${APPS}" | sed "{$PARSE_APPS_PATTERN}" | {
  while read app; do
    if [[ $(echo "${app}" | wc -w) -ne 0 ]]; then
      # Update the root urls.py to include each app.
      echo -e "\tpath('${app}/', include('${app}.urls'))," >>urls.py
      sed -i.bak "s/'django.contrib.admin',/'${app}',\n\t'django.contrib.admin',/" settings.py
    fi
  done
}
echo "] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)" >>urls.py

# Set up files within each app.
cd ..
echo "${APPS}" | sed "{$PARSE_APPS_PATTERN}" | {
  while read app; do
    if [[ $(echo "${app}" | wc -w) -ne 0 ]]; then
      # Create templates and static directories.
      mkdir -p "${app}/templates/${app}"
      mkdir -p "${app}/static/${app}/css"
      mkdir -p "${app}/static/${app}/sass"
      mkdir -p "${app}/static/${app}/js"
      mkdir -p "${app}/static/${app}/ts"
      mkdir -p "${app}/static/${app}/img"

      # Set up views and urls.
      echo "from django.urls import path" >"${app}/urls.py"
      echo "from . import views" >>"${app}/urls.py"
      echo "" >>"${app}/urls.py"
      echo "" >>"${app}/urls.py"
      echo "urlpatterns = []" >>"${app}/urls.py"
      rm "${app}/views.py"
      rm "${app}/tests.py"
      mkdir -p "${app}/views"
      mkdir -p "${app}/tests"
      touch "${app}/views/__init__.py"
      touch "${app}/tests/__init__.py"
    fi
  done
}

echo "\nSetup complete. Please run the adhere to the following:"
echo -e ${POST_MSG}

if [[ "${UID}" -eq 0 ]]
then
  echo "You have run this script as root."
  echo "You may wish to change the ownership (chown) and group (chgrp) to your own user if you are not root."
fi

echo "Run manage.py migration commands."