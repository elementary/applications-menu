# Applications Menu
[![l10n](https://l10n.elementary.io/widgets/wingpanel/applications-menu/svg-badge.svg)](https://l10n.elementary.io/projects/wingpanel/applications-menu)

## Building and Installation

You'll need the following dependencies:
* cmake
* libgee-0.8-dev
* libgnome-menu-dev
* libgranite-dev
* libgtk-3-dev
* libjson-glib-dev
* libplank-dev
* libsoup2.4-dev
* libunity-dev
* libwnck-3-dev
* libzeitgeist-2.0-dev
* pkg-config
* valac

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`

    sudo make install
