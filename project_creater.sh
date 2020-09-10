#!bin/bash

usage() {
  echo "Usage ${0} -p [-da]" >&2
  echo 'Create a Django project.' >&2
  echo '  -p  PROJECT_NAME  Specify the project name.' >&2
  echo '  -d  DATABASE      Database name.' >&2
  echo '  -a  APP(S)        App(s) seperated with ",".' >&2
  exit 1
}

# Install Python
if [[ $(dpkg -l | grep python3 | wc -l) -eq 0 ]]
then
  echo "python3 will be installed."
  apt-get -y install python3
fi

if [[ "${?}" -ne 0 ]]
then
  echo "Could not install python3." >&2
  exit 1
fi

# Install Python venv
if [[ $(dpkg -l | grep python3-venv | wc -l) -eq 0 ]]
then
  echo "python3-venv will be installed."
  apt-get -y install python3-venv
fi

if [[ "${?}" -ne 0 ]]
then
  echo "Could not install python3-venv." >&2
  exit 1
fi

# Install Pip3
if [[ $(dpkg -l | grep python3-pip | wc -l) -eq 0 ]]
then
  echo "python3-pip will be installed."
  apt-get -y install python3-pip
fi

if [[ "${?}" -ne 0 ]]
then
  echo "Could not install python3-pip." >&2
  exit 1
fi

while getopts p:d: OPTION
do
  case ${OPTION} in
    p)
      PROJECT_NAME="${OPTION}"
      ;;
    d)
      DATABASE="${OPTION}"
      ;;
    a)
      APPS=${OPTION}
      ;;
    ?)
      usage
      ;;
  esac
done

# Ensure that a package name has been defined.
if [[ $($PROJECT_NAME | wc -l) -eq 0 ]]
then
  usage
fi

# Create and activate virtual environment.
python3 -m venv venv
source venv/bin/activate

# Install python packages.
pip3 install django

case "${DATABASE}" in
  postgresql|postgres)
    pip3 install psycopg2
    ;;
  oracle|Oracle)
    pip install cx_Oracle
    ;;
  mysql|mySQL)
    pip install mysql-connector-python
    ;;
esac

# Create Django package.

django-admin createproject "${PACKAGE_NAME}"
