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

# Install Python
if [[ $(dpkg -l | grep python3 | wc -l) -eq 0 ]]; then
  echo "python3 will be installed."
  apt-get -y install python3
fi

if [[ "${?}" -ne 0 ]]; then
  echo "Could not install python3." >&2
  exit 1
fi

# Install Python venv
if [[ $(dpkg -l | grep python3-venv | wc -l) -eq 0 ]]; then
  echo "python3-venv will be installed."
  apt-get -y install python3-venv
fi

if [[ "${?}" -ne 0 ]]; then
  echo "Could not install python3-venv." >&2
  exit 1
fi

# Install Pip3
if [[ $(dpkg -l | grep python3-pip | wc -l) -eq 0 ]]; then
  echo "python3-pip will be installed."
  apt-get -y install python3-pip
fi

if [[ "${?}" -ne 0 ]]; then
  echo "Could not install python3-pip." >&2
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
  echo "Please install psycopg2 manually."
  ;;
oracle)
  pip install cx_Oracle
  ;;
mysql)
  pip install mysql-connector-python
  ;;
?)
  echo "Database (${DATABASE}) not recognised."
  echo "Please run pip install manually."
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
sed -i.bak "s/SECRET_KEY = '.*/SECRET_KEY = os.getenv('DJANGO_SECRET_KEY')/" settings.py
sed -i.bak "s/DEBUG = True/DEBUG = bool(int(os.getenv('DJANGO_DEBUG', 0)))/" settings.py
sed -i.bak "s/'DIRS': \[\],/'DIRS': [os.path.join(BASE_DIR, 'templates')],/" settings.py

# Update database settings.
if [[ -z "${DATABASE}" ]]; then
  echo "Database argument is not set."
  echo "Database settings will not be updated"
else
  case "${DATABASE}" in
  postgres | postgresql)
    export DB_ENGINE=django.db.backends.postgresql
    DATABASE_SETTINGS_UPDATED=1
    ;;
  mysql)
    export DB_ENGINE=django.db.backends.mysql
    DATABASE_SETTINGS_UPDATED=1
    ;;
  oracle)
    export DB_ENGINE=django.db.backends.oracle
    DATABASE_SETTINGS_UPDATED=1
    ;;
  ?)
    echo "Database (${DATABASE}) not recognised."
    echo "Please update database settings manually."
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
  done
}

# Make migrations.
python3 manage.py makemigrations
