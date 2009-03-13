SIDEBAR WIDGETS PLUGIN
AUTOMATTIC, INC.
MARCH 2006


WHAT IS THIS ALL ABOUT?

It's called Sidebar Widgets because it allows you to move things (widgets)
around, in and out of your sidebar. A widget is something that you might want
on your sidebar, such as a category list or the most recent comments or a link
to your admin pages. There is even a widget that lets you type whatever you
want in the sidebar, such as some HTML or Javascript code.


HOW DO I INSTALL IT?

First you have to put the files where they belong. We recommend putting all of
the php script files in wp-content/plugins/widgets and keeping any new widget
plugins there unless another location is specified.

Here it is in graphic form:
- wp-content
	- plugins
		- widgets
			| delicious.php
			| gsearch.php
			| rss.png
			| widgets.php
			- scriptaculous
				| builder.js
				| controls.js
				| dragdrop.js
				| effects.js
				| MIT-LICENSE
				| prototype.js
				| scriptaculous.js
				| slider.js
				\ unittest.js
	- themes
		- classic
			| functions.php (optional)
			\ sidebar.php (optional)
		- default
			| functions.php (optional)
			\ sidebar.php (optional)

It will also work if you place the scriptaculous directory in wp-includes/js.
It will also work if you store the RSS icon in wp-includes/images. It's pretty
flexible.

Installing the plugin files isn't enough, however. You must have a theme that
supports sidebar widgets. To help you with that, we've included updated files
for the WordPress 2.0 Default Theme (Kubrick) and the Classic theme. There are
many themes that rely on Classic's script files, so it's probably a good idea to
install the new Classic files unless you have modified the theme yourself.

Don't forget to activate the Widgets plugin.


I HAVE INSTALLED AND ACTIVATED THE PLUGIN. NOW HOW DO I USE IT?

Assuming you chose the Kubrick theme, you should now see a "Sidebar Widgets"
item in the Presentation menu. This gives you a screen with two columns: a
palette and a sidebar. The palette has all of the available widgets and the
other column represents your sidebar. You can drag the widgets between the
columns to create the exact combination that pleases you and your visitors.

If you find that the widgets are not draggable, there are two likely causes:
you installed the scriptaculous files in the wrong place, or your web browser
is not running the scripts. 

Some of the widgets will have a little icon on the right side of the draggable
widget device. Click that icon to reveal that widget's options. Click the X or
the area outside the options box to return to the widget page. Your options are
not saved until you click "Save changes" on the widget page.

Two of the included widgets, Text and RSS, can be replicated several times.
Below the palette you will find forms to change the number of Text and RSS
widgets available. Reducing the number will only cause the extra widgets to be
removed from the visual interface; the contents of the widgets is preserved.


WHAT IF I DON'T LIKE KUBRICK?

You should. He was a visionary film producer. You are entitled to your opinion,
however, so we'll give you a little tutorial on fixing up other themes.


HOW DO I FIX UP MY THEME?

First you have to ask yourself, "Do I know anything about my theme? Does it use
an unordered list to create the sidebar?" (If you can't answer that, you'll
need in-depth help on this task and that means either paying somebody a lot of
money. Better yet, you can learn HTML. Sorry, we don't teach that here.)

Here is an example of good sidebar markup:
<ul id="sidebar">
 <li id="about">
  <h2>About</h2>
  <p>This is my blog.</p>
 </li>
 <li id="links">
  <h2>Links</h2>
  <ul>
   <li><a href="http://example.com">Example</a></li>
  </ul>
 </li>
</ul>

Notice that the entire sidebar is an unordered list and the titles are in <h2>
tags. Not every theme is built this way and it's not necessary to do so, but
it's the simplest, most common, most semantically correct and the most widget-
friendly sidebar markup there is. The element with id="links" is the equivalent
of one basic widget.

When activated, the Dynamic Sidebar plugin gives you a few functions to use in
your template just like template tags. These functions let WordPress replace
your theme's sidebar with a dynamic one while still falling back on the old
sidebar in case you deactivate the plugin or remove all the widgets.

Here is an example of a basic sidebar upgrade using the same markup as above:
<ul id="sidebar">
<?php if ( function_exists('dynamic_sidebar') && dynamic_sidebar() ) : else : ?>
 <li id="about">
  <h2>About</h2>
  <p>This is my blog.</p>
 </li>
 <li id="links">
  <h2>Links</h2>
  <ul>
   <li><a href="http://example.com">Example</a></li>
  </ul>
 </li>
<?php endif; ?>
</ul>

See? We just added two lines to the template and now it'll display a dynamic
sidebar if possible, otherwise display the old sidebar. Disabling the plugin
or removing all the widgets from the sidebar in the admin interface will cause
the old sidebar to be displayed.

Now there is one more thing to be done to the theme. Assuming you are using
WordPress 2.0 or higher, this change will be made within functions.php in your
theme's directory. (WordPress 1.5 users: we don't encourage people to use
WordPress 1.5 anymore, so you won't find any help here. We don't even know if
it's possible because it hasn't been tested.)

Here is an example of functions.php for a theme that does not yet have such a
file (no blank lines at the beginning or end of the file, please):
<?php
if ( function_exists('register_sidebar') )
	register_sidebar();
?>

That's it, just four lines. This code tells the plugin that your theme will need
exactly one dynamic sidebar. At this point, your admin interface should have an
extra item in the Presentation menu: Sidebar Widgets. Try dragging some widgets
from the palette on the left into the box marked Sidebar 1 and saving your
changes. Got it working? Fantastic.


MY SIDEBAR ISN'T A LIST. WHAT DO I DO?

We knew you'd ask that. You'll have to discover your sidebar's design pattern,
then use some extra parameters to tell the plugin how to format them to work
with your theme. We'll work through one example.

Here's the original markup:
<div id="sidebar">
 <div class="title">About</div>
 <p>This is my blog.</p>
 <div class="title">Links</div>
 <ul>
  <li><a href="http://example.com">Example</a></li>
 </ul>
</div>

Yes, we've seen markup like this. It's the second most common sidebar design
pattern, which is why we chose it for the example. The first difference is that
the sidebar is not built inside a <ul> tag. That means we should not be wrapping
any of our widgets in <li> tags. The second difference is that our titles are
wrapped in <div class="title"> instead of <h2> tags.

We fix both of these issues by adding some parameters to the code in
functions.php:
<?php
if ( function_exists('register_sidebar') )
	register_sidebar(array(
		'before_widget' => '', // Removes <li>
		'after_widget' => '', // Removes </li>
		'before_title' => '<div class="title">', // Replaces <h2>
		'after_title' => '</div>', // Replaces </h2>
	));
?>

And here is the sidebar.php markup with our special template tags inserted:
<div id="sidebar">
<?php if ( function_exists('dynamic_sidebar') && dynamic_sidebar() ) : else : ?>
 <div class="title">About</div>
 <p>This is my blog.</p>
 <div class="title">Links</div>
 <ul>
  <li><a href="http://example.com">Example</a></li>
 </ul>
<?php endif; ?>
</div>

That's it. Your HTML markup is taken care of.

Well, mostly taken care of. The default before_widget is a little bit more than
just <li>. It includes an id and class. Well, sort of, but this is where it gets
complicated. The default before_widget includes sprintf directives %1$s and
%2$s, which are replaced by the id and class, respectively. The id is generated
by sanitizing the widget name (which is why you should name your widget
carefully: you don't want duplicate id's in one HTML document!) and the class is
generated from the widget's callback. This ensures all Text and RSS widgets, for
instance, have unique id's and similar classnames. Additionally, there is a 
widget" class for each widget.

So, if you want your theme to be most flexible you should use this instead of
the empty strings shown above:
		'before_widget' => '<div id="%1$s" class="widget %2$s">',
		'after_widget' => '</div>';

Now your HTML markup is REALLY taken care of.


THE SEARCH WIDGET IS UGLY. I WANT MY THEME'S ORIGINAL SEARCH BOX AS A WIDGET.

The widgets are CSS-selectable so that you can style them very specifically.
However, the markup might not be to your liking. Many themes will look better
if they supply their own widgets to replace some of the basic widgets, such as
Search and Meta. It's usually best to copy the existing markup from sidebar.php
into a new widget in functions.php, then use the registration functions to
replace the standard widget with the custom one.

You can do this with any part of the theme's sidebar, or all of them. Here's an
example of how to do this:
function widget_mytheme_search() {
?>
	<< PASTE YOUR SEARCH FORM HERE >>
<?php
}
if ( function_exists('register_sidebar_widget') )
	register_sidebar_widget(__('Search'), 'widget_mytheme_search');


GREAT, I HAVE THE HTML MARKUP LOOKING GOOD BUT IT LOOKS AWEFUL IN THE BROWSER!

Yeah, we knew that would happen. Your theme was probably written before widgets
were born so the author didn't know she should make the stylesheet flexible
enough to handle new markup in the sidebar. If you know some CSS, you should be
able to handle the problems with a few new rules at the end of your stylesheet.
Look in your blog's markup for the selectors (id and/or class) belonging to each
widget you want to style.

If CSS is a mystery to you, we regret that we can't offer you any help. As much
as we'd like to help you with this, it just isn't possible due to the wild
variations of themes. Contact your theme's author and ask her to update the
theme for better compatibility with widgets.


I'M A THEME AUTHOR. WHAT'S WITH ALL THIS EMAIL ASKING ME TO UPDATE MY THEME?

You should be happy they like your theme well enough to contact you rather than
switch to somebody else's themes. Well done on making users happy! We're making
this plugin available now to see how the WordPress community likes it and to
give people a chance to write widgets. If all goes well, this feature will be
integrated into the standard WordPress distribution and any themes that don't
support widgets will, if you believe our crystal ball, become very unpopular
very fast.

We're sorry if that seems threatening. It hurt us more than it hurt you.


THIS WIDGET THING SEEMS MIGHTY POWERFUL. WHAT ELSE CAN I DO WITH IT?

You have no idea how glad we are that you asked that. Here are a few ideas:

* Write a theme that includes a special widget to set it apart from the others.

* How about this for a special widget: a WordPress loop to show asides.

* Register a replacement widget that buffers the original widget and transforms
it somehow.

* Remember that a "sidebar" is really just a name for a list. It can be
displayed vertically or horizontally.

* Remember that a "widget" is really just a name for a configurable code
snippet. It can be invisible or it can be absolutely positioned.

* Use the id and class attributes of any or all widgets in scripts to animate
your sidebar.

* Heck, use script.aculo.us or dbx (included with WordPress) to make your
widgets draggable or even collapsible. Ain't scripting sweet?

* Remember that the widget control API is just for convenience. You can always
set up your own admin page instead. 

* Support your users and get feedback so you can improve your widget. Put a link
to your email or your site at the bottom of your widget control.

* Send a link to your widgets to widgets@wordpress.com for review. We might put
them up for everyone to use. You could be internet famous.


I HAVE A THEME WITH MORE THAN ONE SIDEBAR. HOW DO I MAKE THEM ALL DYNAMIC?

Oh, that's easy. Instead of register_sidebar() you should use
register_sidebars(n) where n is the number of sidebars. Then place the
appropriate number in the dynamic_sidebar() function, starting with 1. There are
several ways to dse these functions but they aren't all documented here. You can
even give your sidebars names rather than numbers, which lets you maintain a
different set of saved sidebars for each theme. But if you need to know so much
about the plugin, why aren't you reading the source code?


THANKS FOR THIS PLUGIN! BLOGGING IS EVEN MORE FUN NOW! HOW CAN I REPAY YOU?

Aww, you're welcome. Just keep on blogging and encourage others to blog, too.
Also, encourage people to develop new widgets. Maybe they'll accept donations
for their work.


HOW DO I DEVELOP NEW WIDGETS?

We included the Google Search and del.icio.us plugins as samples to show you
what a widget plugin might look like. The Google Search widget is commented
within inches of its life. Additionally, there are a few guidelines to follow.

* Don't execute any code while the plugin is loaded. Use the plugins_loaded hook
or you risk fatal errors due to undefined functions, or missing the boat
completely because your plugin loaded before the one it depends on.

* Use register_sidebar_widget($name, $callback) to add your widget to the admin
interface.

* Follow this template:
function widget_myuniquewidget($args) {
	extract($args);
?>
		<?php echo $before_widget; ?>
			<?php echo $before_title . 'My Unique Widget' . $after_title; ?>
			Hello, World!
		<?php echo $after_widget; ?>
<?php
}
register_sidebar_widget('My Unique Widget', 'widget_myuniquewidget');

* Don't leave out $before_widget, $after_widget, $before_title, or $after_title
by accident. They are required for compatibility with various themes.

* Name your widget and its functions carefully. Those strings will be used as
HTML attributes and you don't want to cause identical id's in a single HTML
document.

* Localization is done internally to preserve the HTML id attribute. If you want
your widget name localized with a textdomain, pass array($name, $textdomain)
instead of $name.

* To accommodate multi-widgets (e.g. Text and RSS) you can also pass a
replacement value with the name: array($name_as_sprintf_pattern, $textdomain,
$replacement). See the source.

* You may use the variables mentioned above in different ways, or neglect them
in some circumstances. Some widgets may not need a title, for example. Some
widgets will use the $before_widget and $after_widget several times, or as
arguments to tell another template tag how to format its output.

* Optionally, use this syntax to add a configuration page to the admin:
register_widget_control($name, $callback [, $width [, $height ] ]);
Your callback will be used within the main form, so you don't have to worry
about <form> tags or a button to submit the form.

* Namespace your form elements so they don't conflict with other widgets.

* Each widget must have a unique name. You can replace an already-registered
widget by registering another one with the same name, supplying your own
callback.

* Any extra arguments to register_sidebar_widget() or register_widget_control()
will be passed to your callback. See the Text and RSS widgets for examples.

* Any widget or control can be "unregistered" by passing an empty string to the
registration function.

* There are some undocumented functions. You are encouraged to read the source
code and see how we've created the standard widgets using these functions.

* Please test your widgets with several themes other than Classic and Default
(they both use the ul/li/h2 markup).

* Please audit the security of your widgets before distributing them.

* If you would like your widget to be considered for use on WordPress.com, send
a link (no attachments please) to widgets@wordpress.com and we'll have a look.
