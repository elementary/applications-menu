namespace Slingshot.Utils {
    private void menu_popup_on_keypress (Gtk.Popover popover) {
        popover.halign = END;
        popover.set_pointing_to (Gdk.Rectangle () {
            x = (int) popover.get_root ().get_width (),
            y = (int) popover.get_root ().get_height () / 2
        });
        popover.popup ();
    }

    private void menu_popup_at_pointer (Gtk.Popover popover, double x, double y) {
        var rect = Gdk.Rectangle () {
            x = (int) x,
            y = (int) y
        };
        popover.pointing_to = rect;
        popover.popup ();
    }
}
