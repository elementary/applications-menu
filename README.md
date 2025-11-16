# Applications Menu
[![Translation status](https://l10n.elementary.io/widgets/wingpanel/-/applications-menu/svg-badge.svg)](https://l10n.elementary.io/engage/wingpanel/?utm_source=widget)

Lightweight and stylish app launcher.

![Screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies. Use your package manager (apt) to install them:
* bc
* gettext
* libgee-0.8-dev
* libgranite-dev >= 6.1.0
* libgtk-3-dev
* libhandy-1-dev >= 0.83.0
* libjson-glib-dev
* libswitchboard-3-dev
* libwingpanel-dev
* libzeitgeist-2.0-dev
* meson
* pkg-config
* valac

To build the application locally, clone this repo to your machine. Then, cd to the directory in terminal and run the following commands to configure the build environment and build the application

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install

To run the tests, use `ninja test`

    ninja test
