---
description: >-
  An introduction to the Tina4 mindset and code bases across the various
  language sets
---

# Introduction

The Tina4 documentation is powered by mkdocs which runs in a python environment. The following instructions can be used
to setup your python environment. This can be used to either serve a local copy of your documentation or build a static
html site of your documentation.

Please visit www.python.org to download the version of python for your operating system.

Installation

MacOS / Linux

```bash
python3 -m venv venv
source ./venv/bin/activate
pip install uv
uv sync

```
Windows

Setup and activate your python virtual environment

```bash  
py -m venv .venv
.venv/Scripts/activate
```
Install and sync the uv python package manager as per the ```uv.lock``` file.
```
py -m pip install uv
py -m uv sync
```


Running

This will create a local webserver to view the pages on your browser while developing or as a means to view them.
```bash
uv run mkdocs serve

```
Building

This will build a static html site in the /site folder.
```bash
uv run mkdocs build

```