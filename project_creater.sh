#!bin/bash

usage() {
  echo "Usage ${0} -p [-dasm]" >&2
  echo 'Create a Django project.' >&2
  echo '  -p  PROJECT_NAME  Specify the project name.' >&2
  echo '  -d  DATABASE      Database name.' >&2
  echo '  -a  APP(S)        App(s) seperated with ",".' >&2
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
  pip3 install psycopg2
  ;;
oracle | Oracle)
  pip install cx_Oracle
  ;;
mysql | mySQL)
  pip install mysql-connector-python
  ;;
esac

# Start django project.
django-admin startproject "${PROJECT_NAME}"
cd "${PROJECT_NAME}"

# Django start app
echo "${APPS}" | sed s/,/\\n/g | {
  while read app; do
    if [[ $(echo "${app}" | wc -w) -ne 0 ]]; then
      python3 manage.py startapp "${app}"
    fi
  done
}

# Update settings.
cd "${PROJECT_NAME}"

# Static root rules.
echo "aaaa ${ADD_STATIC_ROOT_RULES}"
if [[ "${ADD_STATIC_ROOT_RULES}" -eq 1 ]]
then
  echo "STATIC_ROOT = os.path.join(BASE_DIR, 'static')" >> settings.py
  echo "STATICFILES_DIRS = [" >> settings.py
  echo "    os.path.join(BASE_DIR, '${PROJECT_NAME}/static')," >> settings.py
  echo "]" >> settings.py
  echo "" >> settings.py
fi

# Media root rules.
if [[ "${ADD_MEDA_ROOT_RULES}"  -eq 1 ]]
then
  echo "# Media Folder Settings" >> settings.py
  echo "MEDIA_ROOT = os.path.join(BASE_DIR, 'media')" >> settings.py
  echo "MEDIA_URL = '/media/'" >> settings.py
  echo "" >> settings.py
fi

sed -i.bak "s/SECRET_KEY = '.*/SECRET_KEY = os.getenv('DJANGO_SECRET_KEY')/" settings.py
