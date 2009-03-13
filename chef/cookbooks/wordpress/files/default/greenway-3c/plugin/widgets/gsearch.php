<?php
/*
Plugin Name: Google Search widget
Description: Adds a sidebar widget to let users search your site with Google.
Author: Automattic, Inc.
Version: 1.0
Author URI: http://automattic.com
*/

// Put functions into one big function we'll call at the plugins_loaded
// action. This ensures that all required plugin functions are defined.
function widget_gsearch_init() {

	// Check for the required plugin functions. This will prevent fatal
	// errors occurring when you deactivate the dynamic-sidebar plugin.
	if ( !function_exists('register_sidebar_widget') )
		return;

	// This is the function that outputs our little Google search form.
	function widget_gsearch($args) {
		
		// $args is an array of strings that help widgets to conform to
		// the active theme: before_widget, before_title, after_widget,
		// and after_title are the array keys. Default tags: li and h2.
		extract($args);

		// Each widget can store its own options. We keep strings here.
		$options = get_option('widget_gsearch');
		$title = $options['title'];
		$buttontext = $options['buttontext'];

		// These lines generate our output. Widgets can be very complex
		// but as you can see here, they can also be very, very simple.
		echo $before_widget . $before_title . $title . $after_title;
		$url_parts = parse_url(get_bloginfo('home'));
		echo '<div style="margin-top:5px;text-align:center;"><form id="gsearch" action="http://www.google.com/search" method="get" onsubmit="this.q.value=\'site:'.$url_parts['host'].' \'+this.rawq.value"><input name="rawq" size="20" /><input type="hidden" name="q" value="" /><input value="'.$buttontext.'" name="submit" type="submit" /></form></div>';
		echo $after_widget;
	}

	// This is the function that outputs the form to let the users edit
	// the widget's title. It's an optional feature that users cry for.
	function widget_gsearch_control() {

		// Get our options and see if we're handling a form submission.
		$options = get_option('widget_gsearch');
		if ( !is_array($options) )
			$options = array('title'=>'', 'buttontext'=>__('Google Search', 'widgets'));
		if ( $_POST['gsearch-submit'] ) {

			// Remember to sanitize and format use input appropriately.
			$options['title'] = strip_tags(stripslashes($_POST['gsearch-title']));
			$options['buttontext'] = strip_tags(stripslashes($_POST['gsearch-buttontext']));
			update_option('widget_gsearch', $options);
		}

		// Be sure you format your options to be valid HTML attributes.
		$title = htmlspecialchars($options['title'], ENT_QUOTES);
		$buttontext = htmlspecialchars($options['buttontext'], ENT_QUOTES);
		
		// Here is our little form segment. Notice that we don't need a
		// complete form. This will be embedded into the existing form.
		echo '<p style="text-align:right;"><label for="gsearch-title">' . __('Title:') . ' <input style="width: 200px;" id="gsearch-title" name="gsearch-title" type="text" value="'.$title.'" /></label></p>';
		echo '<p style="text-align:right;"><label for="gsearch-buttontext">' . __('Button Text:', 'widgets') . ' <input style="width: 200px;" id="gsearch-buttontext" name="gsearch-buttontext" type="text" value="'.$buttontext.'" /></label></p>';
		echo '<input type="hidden" id="gsearch-submit" name="gsearch-submit" value="1" />';
	}
	
	// This registers our widget so it appears with the other available
	// widgets and can be dragged and dropped into any active sidebars.
	register_sidebar_widget(array('Google Search', 'widgets'), 'widget_gsearch');

	// This registers our optional widget control form. Because of this
	// our widget will have a button that reveals a 300x100 pixel form.
	register_widget_control(array('Google Search', 'widgets'), 'widget_gsearch_control', 300, 100);
}

// Run our code later in case this loads prior to any required plugins.
add_action('widgets_init', 'widget_gsearch_init');

?>