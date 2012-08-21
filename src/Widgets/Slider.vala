public interface Slingshot.Slider : Gtk.Widget {
    public abstract void slide_to (Gtk.Widget w);
    public abstract void slide_from (Gtk.Widget w);
    public abstract void slide_fade (Gtk.Widget w);
}

public class Slingshot.SliderClutter : GtkClutter.Embed, Slider
{
    const Clutter.AnimationMode anim_mode = Clutter.AnimationMode.EASE_IN_OUT_SINE;
    Clutter.Container stage;
    GtkClutter.Actor active_actor;
    GtkClutter.Actor next_actor;
    Gtk.Widget active_w;
    public int sens = 1;
    construct
    {
        stage = get_stage() as Clutter.Container;
        assert(stage != null);
        size_allocate.connect(on_size_allocate);
                children = new List<Gtk.Widget>();
    }

    public void on_size_allocate(Gtk.Allocation rect)
    {
        if(rect.width != 0.0)
        {
            float width = (float)get_allocated_width();
            active_actor.width = width;
            active_actor.height = (float)rect.height;
        }
    }

    public void slide(Gtk.Widget w)
    {
        if(sens == 0)
            slide_to(w);
        else if(sens == 1)
            slide_from(w);
        else if(sens == 2)
            slide_fade(w);
    }

    public void slide_to(Gtk.Widget w)
    {
        first = true;
        if(active_actor == null)
        {
            active_actor = new GtkClutter.Actor();
            (active_actor.get_widget() as Gtk.Bin).add(w);
            stage.add_actor(active_actor);
            w.show_all ();
            show_all();
        }
        else
        {
            //if(next_actor != null) next_actor.destroy();
            next_actor = active_actor;

            active_actor = new GtkClutter.Actor();
            put_widget_in_actor (active_actor, w);
            active_actor.x = get_allocated_width();
            active_actor.animate(anim_mode, 300, x: 0.0);
            double width = (double)get_allocated_width();
            next_actor.animate(anim_mode, 300, x: -width);

            stage.add_actor(active_actor);
            w.show_all ();
            show_all();

        }
        active_w = w;
    }

    void put_widget_in_actor (GtkClutter.Actor active_actor, Gtk.Widget w) {

        if (w.get_parent () == null)
        (active_actor.get_widget() as Gtk.Bin).add(w);
        else
        w.reparent((active_actor.get_widget() as Gtk.Bin));
        active_actor.width = get_allocated_width();
        active_actor.height = get_allocated_height();
    }

    public void slide_fade(Gtk.Widget w)
    {
        first = true;
        if(active_actor == null)
        {
            active_actor = new GtkClutter.Actor();
            (active_actor.get_widget() as Gtk.Bin).add(w);
            stage.add_actor(active_actor);
            w.show_all ();
            show_all();
        }
        else
        {
            //if(next_actor != null) next_actor.destroy();
            next_actor = active_actor;

            active_actor = new GtkClutter.Actor();
            put_widget_in_actor (active_actor, w);
            active_actor.x = 0.0f;
            active_actor.opacity = 0;
            active_actor.animate(Clutter.AnimationMode.EASE_OUT_QUAD, 400, opacity:255);
            next_actor.animate(Clutter.AnimationMode.EASE_OUT_QUAD, 400, opacity:0);

            stage.add_actor(active_actor);
            w.show_all ();
            show_all();

        }
        active_w = w;
    }

    public void slide_from(Gtk.Widget w)
    {
        first = true;
        if(active_actor == null)
        {
            active_actor = new GtkClutter.Actor();
            (active_actor.get_widget() as Gtk.Bin).add(w);
            stage.add_actor(active_actor);
            w.show_all ();
            show_all();
        }
        else
        {
            //if(next_actor != null) next_actor.destroy();
            next_actor = active_actor;

            active_actor = new GtkClutter.Actor();
            put_widget_in_actor (active_actor, w);
            active_actor.x = -get_allocated_width();
            active_actor.animate(anim_mode, 300, x: 0.0);
            double width = (double)get_allocated_width();
            next_actor.animate(anim_mode, 300, x: width);

            stage.add_actor(active_actor);
            w.show_all ();
            show_all();

        }
        active_w = w;
    }


    internal List<Gtk.Widget> children;

    bool first = true;
    int max_height = 0;
    public override void get_preferred_height(out int size1, out int size2){
        active_w.get_preferred_height(out size1, out size2);
        max_height = size1 = size2 = int.max(max_height, size2);

    }
    int max_width = 0;
    public override void get_preferred_width(out int size1, out int size2){
        active_w.get_preferred_width(out size1, out size2);
        max_width = size1 = size2 = int.max(max_width, size2);

    }
}

public class Slingshot.SliderFall : Gtk.Grid, Slider {

    public SliderFall () {
    }

    Gtk.Widget? old_w = null;
    public void slide_to (Gtk.Widget w) {
        if (old_w != null) remove (old_w);
        w.hexpand = w.vexpand = true;
        add (w);
        old_w = w;
        show_all ();
    }
    public void slide_from (Gtk.Widget w) {
        slide_to (w);
    }
    public void slide_fade (Gtk.Widget w) {
        slide_to (w);
    }
}

public Slingshot.Slider get_slider () {
    unowned string[] a = null;
    if (GtkClutter.init (ref a) == Clutter.InitError.SUCCESS) {
        return new Slingshot.SliderClutter ();
    }
    else
        return new Slingshot.SliderFall ();
}
