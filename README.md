# Django Project Creator
A bash script to create and setup a Django project.

**NAME**
    django_project_creator - Django Project Creator

**SYNOPSIS**
    bash django_project_creator -p PROJECT_NAME [options]

**OPTIONS**
    -p      Project name.
    -d      Database type (postgresql, oracle or mysql).
    -a      App(s) to be created and set up.
    -s      Option to update static root settings.
    -m      Option to update media root settings.

**DESCRIPTION**
    **django_project_creator** is a bash script that would create a Django project on a Ubuntu machine.
    The script will do the following:
    * Install python3, python3-venv and python3-pip if it is not already installed.
    * Creates a virtual environment and installs Django.
    * Creates a django project using the PACKAGE_NAME and APPS.
    * Set static root and media root rules.
    * Update ``SECRET_KEY`` and ``DEBUG`` to read from environment variables.
    * Update ``TEMPLATES`` rule in settings.
    * If the database argument (-d) is recognised, then set the appropriate environment for ``DB_ENGINE``.
    * If the database argument (-d) is recongised, then update the database settings.
    * In the projects root ``urls.py`` file, create include rules routing to an url file in each app directory.
    * Inside each app directory create a ``urls.py`` file with basic configurations.
    * Remove ``views.py`` and ``tests.py`` in each directory and create a views and tests directory with an ``__init__.py`` inside each directory.
    * In each app directory create template and static directories with related sub-directories.
