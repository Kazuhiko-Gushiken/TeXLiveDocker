# TeXLiveDocker

Quick docker based LaTeX compilation environment that uses TeX Live as a base and a plethora of other common packages.

## Requirements:

- Docker

---

## Installation for Windows and MacOS:

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/), load it up, and follow any instructions to install and/or update WSL. Once it's setup, find a folder to put this into. Then, download the [zip of the repo](https://github.com/Kazuhiko-Gushiken/TeXLiveDocker/archive/refs/heads/main.zip). Unzip this into the folder of your choosing. If you're on Windows, run the `build-docker.bat` and if you're on a Unix based OS (Linux/MacOS) run `build-docker.sh`. Let it build. 

Once finished, place any `.tex` files into the [input](https://github.com/Kazuhiko-Gushiken/TeXLiveDocker/tree/main/input) folder, just as is or in a folder to organize.

Once you finish a `.tex` file or want to test, run the `compile.bat` if you're on Windows or `compile.sh` if you're on a Unix based OS (Linux/MacOS). It'll prompt you with which files or directories you'd like to process. Type a sepcific one and press enter, or press enter without anything to process everything.

All the outputs will be found in the [output](https://github.com/Kazuhiko-Gushiken/TeXLiveDocker/tree/main/output) folder. Any errors will be found in the error file in the [failed](https://github.com/Kazuhiko-Gushiken/TeXLiveDocker/tree/main/failed) folder. Everything else, such as logs, will be placed in the [build](https://github.com/Kazuhiko-Gushiken/TeXLiveDocker/tree/main/build) folder.

## Installation for Linux:

Pretty much all the same, but you'll need to install and setup docker with permissions and such in CLI, but you're using linux so I can only assume you know what you're doing.