# Applications Menu
[![Translation status](https://l10n.elementary.io/widgets/wingpanel/-/applications-menu/svg-badge.svg)](https://l10n.elementary.io/engage/wingpanel/?utm_source=widget)

Lightweight and stylish app launcher.

![Screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:
* libappstream-dev
* libgee-0.8-dev
* libgnome-menu-3-dev
* libgranite-dev >= 5.2.1
* libgtk-3-dev
* libhandy-0.0-dev
* libjson-glib-dev
* libplank-dev
* libsoup2.4-dev
* libswitchboard-2.0-dev
* libunity-dev
* libwingpanel-2.0-dev
* libzeitgeist-2.0-dev
* meson
* pkg-config
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
