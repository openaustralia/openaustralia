<?php
/*
Plugin Name: Sidebar Widgets
Plugin URI: http://svn.wp-plugins.org/widgets/trunk
Description: Adds "Sidebar Widgets" panel under Presentation menu
Author: Automattic, Inc.
Author URI: http://automattic.com/
Version: 1.0.20060711
*/


//////////////////////////////////////////////////////////// Global Variables

$registered_sidebars = array();
$registered_widgets = array();
$registered_widget_controls = array();
$registered_widget_styles = array();
$register_widget_defaults = false; // When true, registration is non-destructive.

//////////////////////////////////////////////////////////// Public Functions

function register_sidebars($number = 1, $args = array()) {
	global $registered_sidebars;

	$number = (int) $number;

	if ( is_string($args) )
		parse_str($args, $args);

	$name = $args['name'] ? $args['name'] : __('Sidebar');

	$i = 1;
	while ( $i <= $number ) {
		if ( isset($args['name']) && $number > 1 ) {
			if ( !strstr($name, '%d') )
				$name = "$name %d";
			$args['name'] = sprintf($name, $i);
		}
		register_sidebar($args);
		++$i;
	}
}

function register_sidebar($args = array()) {
	global $registered_sidebars;

	if ( is_string($args) )
		parse_str($args, $args);

	$defaults = array(
		'name' => sprintf(__('Sidebar %d', 'widgets'), count($registered_sidebars) + 1 ),
		'before_widget' => '<li id="%1$s" class="widget %2$s">',
		'after_widget' => "</li>\n",
		'before_title' => '<h2 class="widgettitle">',
		'after_title' => "</h2>\n",
	);

	$sidebar = array_merge($defaults, $args);

	$sidebar['id'] = sanitize_title($sidebar['name']);

	$registered_sidebars[$sidebar['id']] = $sidebar;

	return $sidebar['id'];
}

function unregister_sidebar($name) {
	global $registered_sidebars;

	unset( $registered_sidebars[$name]['id'] );
}

function register_sidebar_widget($name, $output_callback, $classname = '') {
	global $registered_widgets, $register_widget_defaults;

	if ( is_array($name) ) {
		$id = sanitize_title(sprintf($name[0], $name[2]));
		$name = sprintf(__($name[0], $name[1]), $name[2]);
	} else {
		$id = sanitize_title($name);
		$name = __($name);
	}

	if ( (empty($classname) || !is_string($classname)) && is_string($output_callback) )
			$classname = $output_callback;
	
	$widget = array(
		'id' => $id,
		'callback' => $output_callback,
		'classname' => $classname,
		'params' => array_slice(func_get_args(), 2)
	);

	if ( empty($output_callback) )
		unset($registered_widgets[$name]);
	elseif ( is_callable($output_callback) && ( !isset($registered_widgets[$name]) || !$register_widget_defaults) )
		$registered_widgets[$name] = $widget;
}

function unregister_sidebar_widget($name) {
	register_sidebar_widget($name, '');
	unregister_widget_control($name);
}

function register_widget_control($name, $control_callback, $width = 300, $height = 200) {
	global $registered_widget_controls, $register_widget_defaults;

	if ( is_array($name) ) {
		$id = sanitize_title(sprintf($name[0], $name[2]));
		$name = sprintf(__($name[0], $name[1]), $name[2]);
	} else {
		$id = sanitize_title($name);
		$name = __($name);
	}

	$width = (int) $width > 90 ? (int) $width + 60 : 360;
	$height = (int) $height > 60 ? (int) $height + 40 : 240;

	if ( empty($control_callback) )
		unset($registered_widget_controls[$name]);
	elseif ( !isset($registered_widget_controls[$name]) || !$register_widget_defaults )
		$registered_widget_controls[$name] = array(
			'id' => $id,
			'callback' => $control_callback,
			'width' => $width,
			'height' => $height,
			'params' => array_slice(func_get_args(), 4)
		);
}

function unregister_widget_control($name) {
	return register_widget_control($name, '');
}

function dynamic_sidebar($name = 1) {
	global $registered_sidebars, $registered_widgets;

	if ( is_int($name) ) {
		$index = sanitize_title('Sidebar ' . $name);
		$name = sprintf(__('Sidebar %d', 'widgets'), $name);
	} else {
		$index = sanitize_title($name);
	}

	$sidebars_widgets = get_option('sidebars_widgets');

	$sidebar = $registered_sidebars[$index];

	if ( empty($sidebar) || !is_array($sidebars_widgets[$index]) || empty($sidebars_widgets[$index]) )
		return false;

	$did_one = false;
	foreach ( $sidebars_widgets[$index] as $name ) {
		$callback = $registered_widgets[$name]['callback'];

		$params = array_merge(array($sidebar), (array) $registered_widgets[$name]['params']);
		$params[0]['before_widget'] = sprintf($params[0]['before_widget'], $registered_widgets[$name]['id'], $registered_widgets[$name]['classname']);
		if ( is_callable($callback) ) {
			call_user_func_array($callback, $params);
			$did_one = true;
		}
	}

	return $did_one;
}

function is_active_widget($callback) {
	global $registered_widgets;

	$sidebars_widgets = get_option('sidebars_widgets');

	if ( is_array($sidebars_widgets) ) foreach ( $sidebars_widgets as $sidebar => $widgets )
		if ( is_array($widgets) ) foreach ( $widgets as $widget )
			if ( $registered_widgets[$widget]['callback'] == $callback )
				return true;

	return false;
}

function is_dynamic_sidebar() {
	global $registered_widgets, $registered_sidebars;
	$sidebars_widgets = get_option('sidebars_widgets');
	foreach ( $registered_sidebars as $index => $sidebar ) {
		if ( count($sidebars_widgets[$index]) ) {
			foreach ( $sidebars_widgets[$index] as $widget )
				if ( array_key_exists($widget, $registered_widgets) )
					return true;
		}
	}
	return false;
}

//////////////////////////////////////////////////////////// Private Functions

function sidebar_admin_setup() {
	global $registered_sidebars;
	if ( count($registered_sidebars) < 1 )
		return;
	$page = preg_replace('!^.*[\\\\/]wp-content[\\\\/][^\\\\/]*plugins[\\\\/]!', '', __FILE__);
	$page = str_replace('\\', '/', $page);
	add_submenu_page('themes.php', __('Sidebar Widgets', 'widgets'), __('Sidebar Widgets', 'widgets'), 5, $page, 'sidebar_admin_page');
	if ( $_GET['page'] == $page ) {
		add_action('admin_head', 'sidebar_admin_head');
		do_action('sidebar_admin_setup');
	}
}

function sidebar_admin_head() {
	global $registered_widgets, $registered_sidebars, $registered_widget_controls;

	if ( file_exists(dirname(__FILE__).'/scriptaculous/scriptaculous.js') )
		$scriptdir = str_replace(str_replace('\\', '/', ABSPATH), get_settings('siteurl').'/', str_replace('\\', '/', dirname(__FILE__))) . '/scriptaculous';
	else
		$scriptdir = get_settings('siteurl') . '/wp-includes/js/scriptaculous';

	$width = 1 + 262 * ( count($registered_sidebars));
	$height = 35 * count($registered_widgets);
	?>
	<style type="text/css">
	body {
		height: 100%;
	}
	#sbadmin #zones {
		width: <?php echo $width; ?>px;
		-moz-user-select: none;
		-khtml-user-select: none;
		user-select: none;
	}
	#sbreset {
		float: left;
		margin: 1px 0;
	}
	.dropzone {
		float: left;
		margin-right: 10px;
		padding: 5px;
		border: 1px solid #bbb;
		background-color: #f0f8ff;
	}
	.dropzone h3 {
		text-align: center;
		color: #333;
	}
	.dropzone ul {
		list-style-type: none;
		width: 240px;
		height: <?php echo $height; ?>px;
		float: left;
		margin: 0;
		padding: 0;
	}
	* .module, #lastmodule {
		width: 238px;
		padding: 0;
		margin: 5px 0;
		cursor: move;
		display: block;
		border: 1px solid #ccc;
		background-color: #fbfbfb;
		text-align: left;
		line-height: 25px;
	}
	* .handle, #lastmodule span {
		display: block;
		width: 216px;
		padding: 0 10px;
		border-top: 1px solid #f2f2f2;
		border-right: 1px solid #e8e8e8;
		border-bottom: 1px solid #e8e8e8;
		border-left: 1px solid #f2f2f2;
	}
	* .popper {
		margin: 0;
		display: inline;
		position: absolute;
		top: 3px;
		right: 3px;
		overflow: hidden;
		text-align: center;
		height: 16px;
		font-size: 18px;
		line-height: 14px;
		cursor: pointer;
		padding: 0 3px 1px;
		border-top: 4px solid #6da6d1;
		background: url( images/fade-butt.png ) -5px 0px;
	}
	* html .popper {
		padding: 1px 6px 0;
		font-size: 16px;
	}
	#sbadmin p.submit {
		padding-right: 10px;
		clear: left;
	}
	.placematt {
		position: absolute;
		cursor: default;
		margin: 10px 0 0;
		padding: 0;
		width: 238px;
		background-color: #ffe;
	}
	* html .placematt {
		margin-top: 5px;
	}
	.placematt h4 {
		text-align: center;
		margin-bottom: 5px;
	}
	.placematt span {
		padding: 0 10px 10px;
		text-align: justify;
	}
	#palettediv {
		border: 1px solid #bbb;
		background-color: #f0f8ff;
		height: 180px;
		margin-top: 10px;
	}
	#palettediv h3 {
		text-align: center;
		color: #333;
	}
	#palettediv ul {
		padding: 0 0 0 10px;
	}
	#palettediv .module, #lastmodule {
		margin-right: 10px;
		float: left;
		width: 120px;
	}
	#palettediv .handle, #lastmodule span {
		height: 40px;
		font-size: 90%;
		width: 110px;
		padding: 0 5px;
	}
	#palettediv .popper {
		visibility: hidden;
	}
	#lastmodule {
		visibility: hidden;
	}
	* html #palettediv ul {
		margin: 0;
		padding: 0 0 0 10px;
	}
	* html #palettediv .module {
		float: none;
		display: inline;
	}
	#controls {
		height: 0px;
	}
	.control {
		position: absolute;
		display: block;
		background: #f9fcfe;
		padding: 0;
	}
	.controlhandle {
		cursor: move;
		background-color: #6da6d1;
		border-bottom: 2px solid #448abd;
		color: #333;
		display: block;
		margin: 0 0 5px;
		padding: 4px;
		font-size: 120%;
	}
	.controlcloser {
		cursor: pointer;
		font-size: 120%;
		display: block;
		position: absolute;
		top: 2px;
		right: 8px;
		padding: 0 3px;
		font-weight: bold;
	}
	.controlform {
		margin: 20px 30px;
	}
	.controlform p {
		text-align: center;
	}
	.control .checkbox {
		border: none;
		background: transparent;
	}
	.hidden {
		display: none;
	}
	#shadow {
		background: black;
		display: none;
		position: absolute;
		top: 0px;
		left: 0px;
		width: 100%;
	}
	</style>

	<script language="JavaScript" type="text/javascript" src="<?php echo $scriptdir; ?>/prototype.js"></script>
	<script language="JavaScript" type="text/javascript" src="<?php echo $scriptdir; ?>/scriptaculous.js"></script>
	<script language="JavaScript" type="text/javascript" src="<?php echo $scriptdir; ?>/dragdrop.js"></script>
	<script type="text/javascript">
		// <![CDATA[
		var cols = [<?php $a = array(); foreach ( $registered_sidebars as $index => $sidebar ) $a[] = "'$index'"; echo implode(', ', $a); ?>];
		var widgets = [<?php $a = array(); foreach ( $registered_widgets as $name => $widget ) $a[] = "'{$widget['id']}'"; echo implode(', ', $a); ?>];
		var controldims = new Array;
<?php foreach ( $registered_widget_controls as $name => $widget ) : ?>
			controldims['<?php echo $widget['id']; ?>control'] = new Array;
			controldims['<?php echo $widget['id']; ?>control']['width'] = <?php echo (int) $widget['width']; ?>;
			controldims['<?php echo $widget['id']; ?>control']['height'] = <?php echo (int) $widget['height']; ?>;
<?php endforeach; ?>
		function initWidgets() {
<?php foreach ( $registered_widget_controls as $name => $widget ) : ?>
			$('<?php echo $widget['id']; ?>popper').onclick = function() {popControl('<?php echo $widget['id']; ?>control');};
			$('<?php echo $widget['id']; ?>closer').onclick = function() {unpopControl('<?php echo $widget['id']; ?>control');};
			new Draggable('<?php echo $widget['id']; ?>control', {revert:false,handle:'controlhandle',starteffect:function(){},endeffect:function(){},change:function(o){dragChange(o);}});
			if ( true && window.opera )
				$('<?php echo $widget['id']; ?>control').style.border = '1px solid #bbb';
<?php endforeach; ?>
			if ( true && window.opera )
				$('shadow').style.background = 'transparent';
			new Effect.Opacity('shadow', {to:0.0});
			widgets.map(function(o) {o='widgetprefix-'+o; Position.absolutize(o); Position.relativize(o);} );
			$A(Draggables.drags).map(function(o) {o.startDrag(null); o.finishDrag(null);});
			for ( var n in Draggables.drags ) {
				if ( Draggables.drags[n].element.id == 'lastmodule' ) {
					Draggables.drags[n].destroy();
					break;
				}
			}
			resetPaletteHeight();
		}
		function resetDroppableHeights() {
			var max = 6;
			cols.map(function(o) {var c = $(o).childNodes.length; if ( c > max ) max = c;} );
			var height = 35 * ( max + 1);
			cols.map(function(o) {h = (($(o).childNodes.length + 1) * 35); $(o).style.height = (h > 280 ? h : 280) + 'px';} );
		}
		function resetPaletteHeight() {
			var p = $('palette'), pd = $('palettediv'), last = $('lastmodule');
			p.appendChild(last);
			if ( Draggables.activeDraggable && last.id == Draggables.activeDraggable.element.id )
				last = last.previousSibling;
			var y1 = Position.cumulativeOffset(last)[1] + last.offsetHeight;
			var y2 = Position.cumulativeOffset(pd)[1] + pd.offsetHeight;
			var dy = y1 - y2;
			pd.style.height = (pd.offsetHeight + dy + 9) + "px";
		}
		function maxHeight(elm) {
			htmlheight = document.body.parentNode.clientHeight;
			bodyheight = document.body.clientHeight;
			var height = htmlheight > bodyheight ? htmlheight : bodyheight;
			$(elm).style.height = height + 'px';
		}
		function dragChange(o) {
			el = o.element ? o.element : $(o);
			var p = Position.page(el);
			var right = p[0];
			var top = p[1];
			var left = $('shadow').offsetWidth - (el.offsetWidth + left);
			var bottom = $('shadow').offsetHeight - (el.offsetHeight + top);
			if ( right < 1 ) el.style.left = 0;
			if ( top < 1 ) el.style.top = 0;
			if ( left < 1 ) el.style.left = (left + right) + 'px';
			if ( bottom < 1 ) el.style.top = (top + bottom) + 'px';
		}
		function popControl(elm) {
			el = $(elm);
			el.style.width = controldims[elm]['width'] + 'px';
			el.style.height = controldims[elm]['height'] + 'px';
			var x = ( document.body.clientWidth - controldims[elm]['width'] ) / 2;
			var y = ( document.body.parentNode.clientHeight - controldims[elm]['height'] ) / 2;
			el.style.position = 'absolute';
			el.style.right = '' + x + 'px';
			el.style.top = '' + y + 'px';
			el.style.zIndex = 1000;
			el.className='control';
			$('shadow').onclick = function() {unpopControl(elm);};
	        window.onresize = function(){maxHeight('shadow');dragChange(elm);};
			popShadow();
		}
		function popShadow() {
			maxHeight('shadow');
			var shadow = $('shadow');
			shadow.style.zIndex = 999;
			shadow.style.display = 'block';
	        new Effect.Opacity('shadow', {duration:0.5, from:0.0, to:0.2});
		}
		function unpopShadow() {
	        new Effect.Opacity('shadow', {to:0.0});
			$('shadow').style.display = 'none';
		}
		function unpopControl(el) {
			$(el).className='hidden';
			unpopShadow();
		}
		function serializeAll() {
<?php foreach ( $registered_sidebars as $index => $sidebar ) : ?>
			$('<?php echo $index; ?>order').value = Sortable.serialize('<?php echo $index; ?>');
<?php endforeach; ?>
		}
		function updateAll() {
			resetDroppableHeights();
			resetPaletteHeight();
			cols.map(function(o){
				var pm = $(o+'placematt');
				if ( $(o).childNodes.length == 0 ) {
					pm.style.display = 'block';
					Position.absolutize(o+'placematt');
				} else {
					pm.style.display = 'none';
				}
			});
		}
		function noSelection(event) {
			if ( document.selection ) {
				var range = document.selection.createRange();
				range.collapse(false);
				range.select();
				return false;
			}
		}
		addLoadEvent(updateAll);
		addLoadEvent(initWidgets);
		Event.observe(window, 'resize', resetPaletteHeight);
		// ]]>
	</script>
	<?php
	do_action('sidebar_admin_head');
}

function sidebar_admin_page() {
	global $registered_widgets, $registered_sidebars, $registered_widget_controls;

	if ( count($registered_sidebars) < 1 ) {
?>
	<div class="wrap">
	<h2><?php _e('About Dynamic Sidebars'); ?></h2>
	<p><?php _e("You can modify your theme's sidebar, rearranging and configuring widgets right in this screen! Well, you could if you had a compatible theme. You're seeing this message because your theme isn't ready for widgets. <a href='http://andy.wordpress.com/widgets/get-ready'>Get it ready!</a>"); ?></p>
	</div>
<?php
		return;
	}
	$sidebars_widgets = get_option('sidebars_widgets');
	if ( empty($sidebars_widgets) ) {
		$sidebars_widgets = get_widget_defaults();
	}

	if ( isset($_POST['action']) ) {
		check_admin_referer('widgets-save-widget-order');
		switch ( $_POST['action'] ) {
			case 'default' :
				$sidebars_widgets = get_widget_defaults();
				update_option('sidebars_widgets', $sidebars_widgets);
				break;
			case 'save_widget_order' :
				$sidebars_widgets = array();
				foreach ( $registered_sidebars as $index => $sidebar ) {
					$postindex = $index . 'order';
					parse_str($_POST[$postindex], $order);
					$new_order = $order[$index];
					if ( is_array($new_order) )
						foreach ( $new_order as $sanitized_name )
							foreach ( $registered_widgets as $name => $widget )
								if ( $sanitized_name == $widget['id'] )
									$sidebars_widgets[$index][] = $name;
				}
				update_option('sidebars_widgets', $sidebars_widgets);
				break;
		}
	}

	ksort($registered_widgets);

	$inactive_widgets = array();
	foreach ( $registered_widgets as $name => $widget ) {
		$is_active = false;
		foreach ( $registered_sidebars as $index => $sidebar ) {
			if ( is_array($sidebars_widgets[$index]) && in_array($name, $sidebars_widgets[$index]) ) {
				$is_active = true;
				break;
			}
		}
		if ( ! $is_active )
			$inactive_widgets[] = $name;
	}

	$containers = array('palette');
	foreach ( $registered_sidebars as $index => $sidebar )
		$containers[] = $index;
	$c_string = '';
	foreach ( $containers as $container )
		$c_string .= "\"$container\",";
	$c_string = substr($c_string, 0, -1);
	?>
	<?php if ( $_POST['action'] ) { ?>
	<div class="fade updated" id="message">
	<p><?php printf(__('Sidebar Updated. <a href="%s">View site &raquo;</a>'), get_settings('home') . '/'); ?></p>
	</div>
	<?php } ?>
	<div class="wrap">
	<h2><?php _e('Sidebar Arrangement'); ?></h2>
	<p><?php _e("You can drag and drop widgets into your sidebar below."); ?></p>
	<form id="sbadmin" method="POST" onsubmit="serializeAll()">
	<div id="zones">
<?php $i = 1; foreach ( $registered_sidebars as $index => $sidebar ) : ?>
	<input type="hidden" id="<?php echo $index; ?>order" name="<?php echo $index; ?>order" value="" />
	<div class="dropzone">
		<h3><?php echo $sidebar['name']; ?></h3>
		<div id="<?php echo $index; ?>placematt" class="module placematt"><span class="handle"><h4><?php _e('Default Sidebar'); ?></h4><?php _e('Your theme will display its usual sidebar when this box is empty. Dragging widgets into this box will replace the usual sidebar with your customized sidebar.'); ?></span></div>
		<ul id="<?php echo $index; ?>"><?php if ( is_array($sidebars_widgets[$index]) ) foreach ( $sidebars_widgets[$index] as $name ) widget_draggable($name); ?></ul>
	</div>
<?php endforeach; ?>
	<br class="clear" />
	</div>
	<div id="palettediv">
		<h3><?php _e('Available Widgets'); ?></h3>
		<ul id="palette"><?php foreach ( $inactive_widgets as $name ) widget_draggable($name); ?><li id="lastmodule"><span></span></li></ul>
	</div>

	<script type="text/javascript">
	// <![CDATA[
<?php foreach ( $containers as $container ) : ?>
	Sortable.create("<?php echo $container; ?>",
	{dropOnEmpty:true,containment:[<?php echo $c_string; ?>],handle:'handle',constraint:false,onUpdate:updateAll,format:/^widgetprefix-(.*)$/});
<?php endforeach; ?>
	// ]]>
	</script>
	<p class="submit">
	<?php if ( function_exists('wp_nonce_field') ) wp_nonce_field('widgets-save-widget-order'); ?>
	<input type="hidden" name="action" id="action" value="save_widget_order" />
	<input type="submit" value="<?php _e('Save Changes &raquo;', 'widgets'); ?>" />
	</p>
	<div id="controls">
<?php foreach ( $registered_widget_controls as $name => $widget ) : ?>
		<div class="hidden" id="<?php echo $widget['id']; ?>control">
			<span class="controlhandle"><?php echo $name; ?></span>
			<span id="<?php echo $widget['id']; ?>closer" class="controlcloser">&#215;</span>
			<div class="controlform">
<?php call_user_func_array($widget['callback'], $widget['params']); ?>
			</div>
		</div>
<?php endforeach; ?>
	</div>
	</form>
	<br class="clear" />
	</div>
	<div id="shadow"> </div>
<?php
	do_action('sidebar_admin_page');
}

function widget_draggable($name) {
	global $registered_widgets, $registered_widget_controls;
	if ( !isset($registered_widgets[$name]) )
		return;
	$san_name = sanitize_title($registered_widgets[$name]['id']);
	$poptitle = __('Configure', 'widgets');
	$popper = $registered_widget_controls[$name] ? " <div class='popper' id='{$san_name}popper' title='$poptitle'>&#8801;</div>" : '';
	echo "<li class='module' id='widgetprefix-$san_name'><span class='handle'>$name$popper</span></li>";
}

function get_widget_defaults() {
	global $registered_sidebars;
	foreach ( $registered_sidebars as $index => $sidebar )
		$defaults[$index] = array();
	return $defaults;
}


//////////////////////////////////////////////////////////// Standard Widgets

function widget_pages($args) {
	extract($args);
	$options = get_option('widget_pages');
	$title = empty($options['title']) ? __('Pages') : $options['title'];
	echo $before_widget . $before_title . $title . $after_title . "<ul>\n";
	wp_list_pages("title_li=");
	echo "</ul>\n" . $after_widget;
}

function widget_pages_control() {
	$options = $newoptions = get_option('widget_pages');
	if ( $_POST["pages-submit"] ) {
		$newoptions['title'] = strip_tags(stripslashes($_POST["pages-title"]));
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_pages', $options);
	}
	$title = htmlspecialchars($options['title'], ENT_QUOTES);
?>
			<p><label for="pages-title"><?php _e('Title:'); ?> <input style="width: 250px;" id="pages-title" name="pages-title" type="text" value="<?php echo $title; ?>" /></label></p>
			<input type="hidden" id="pages-submit" name="pages-submit" value="1" />
<?php
}

function widget_links($args) {
	global $wp_db_version;
	extract($args);

	if ( $wp_db_version < 3582 ) {
		// This ONLY works with li/h2 sidebars.
		get_links_list();
	} else {
		wp_list_bookmarks(array('title_before'=>$before_title, 'title_after'=>$after_title));
	}
}

function widget_search($args) {
	extract($args);
?>
		<?php echo $before_widget; ?>
			<form id="searchform" method="get" action="<?php bloginfo('home'); ?>">
			<div>
			<input type="text" name="s" id="s" size="15" /><br />
			<input type="submit" value="<?php _e('Search'); ?>" />
			</div>
			</form>
		<?php echo $after_widget; ?>
<?php
}

function widget_archives($args) {
	extract($args);
	$options = get_option('widget_archives');
	$c = $options['count'] ? '1' : '0';
	$title = empty($options['title']) ? __('Archives') : $options['title'];
?>
		<?php echo $before_widget; ?>
			<?php echo $before_title . $title . $after_title; ?>
			<ul>
			<?php wp_get_archives("type=monthly&show_post_count=$c"); ?>
			</ul>
		<?php echo $after_widget; ?>
<?php
}

function widget_archives_control() {
	$options = $newoptions = get_option('widget_archives');
	if ( $_POST["archives-submit"] ) {
		$newoptions['count'] = isset($_POST['archives-count']);
		$newoptions['title'] = strip_tags(stripslashes($_POST["archives-title"]));
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_archives', $options);
	}
	$count = $options['count'] ? 'checked="checked"' : '';
	$title = htmlspecialchars($options['title'], ENT_QUOTES);
?>
			<p><label for="archives-title"><?php _e('Title:'); ?> <input style="width: 250px;" id="archives-title" name="archives-title" type="text" value="<?php echo $title; ?>" /></label></p>
			<p style="text-align:right;margin-right:40px;"><label for="archives-count">Show post counts <input class="checkbox" type="checkbox" <?php echo $count; ?> id="archives-count" name="archives-count" /></label></p>
			<input type="hidden" id="archives-submit" name="archives-submit" value="1" />
<?php
}

function widget_meta($args) {
	extract($args);
	$options = get_option('widget_meta');
	$title = empty($options['title']) ? __('Meta') : $options['title'];
?>
		<?php echo $before_widget; ?>
			<?php echo $before_title . $title . $after_title; ?>
			<ul>
			<?php wp_register(); ?>
			<li><?php wp_loginout(); ?></li>
			<li><a href="<?php bloginfo('rss2_url'); ?>" title="<?php _e('Syndicate this site using RSS 2.0'); ?>"><?php _e('Entries <abbr title="Really Simple Syndication">RSS</abbr>'); ?></a></li>
			<li><a href="<?php bloginfo('comments_rss2_url'); ?>" title="<?php _e('The latest comments to all posts in RSS'); ?>"><?php _e('Comments <abbr title="Really Simple Syndication">RSS</abbr>'); ?></a></li>
			<li><a href="http://wordpress.com/" title="<?php _e('Powered by Wordpress, state-of-the-art semantic personal publishing platform.'); ?>">WordPress.com</a></li>
			<?php wp_meta(); ?>
			</ul>
		<?php echo $after_widget; ?>
<?php
}
function widget_meta_control() {
	$options = $newoptions = get_option('widget_meta');
	if ( $_POST["meta-submit"] ) {
		$newoptions['title'] = strip_tags(stripslashes($_POST["meta-title"]));
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_meta', $options);
	}
	$title = htmlspecialchars($options['title'], ENT_QUOTES);
?>
			<p><label for="meta-title"><?php _e('Title:'); ?> <input style="width: 250px;" id="meta-title" name="meta-title" type="text" value="<?php echo $title; ?>" /></label></p>
			<input type="hidden" id="meta-submit" name="meta-submit" value="1" />
<?php
}

function widget_calendar($args) {
	extract($args);
	$options = get_option('widget_calendar');
	$title = $options['title'];
	if ( empty($title) )
		$title = '&nbsp;';
	echo $before_widget . $before_title . $title . $after_title;
	echo '<div id="calendar_wrap">';
	get_calendar();
	echo '</div>';
	echo $after_widget;
}
function widget_calendar_control() {
	$options = $newoptions = get_option('widget_calendar');
	if ( $_POST["calendar-submit"] ) {
		$newoptions['title'] = strip_tags(stripslashes($_POST["calendar-title"]));
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_calendar', $options);
	}
	$title = htmlspecialchars($options['title'], ENT_QUOTES);
?>
			<p><label for="calendar-title"><?php _e('Title:'); ?> <input style="width: 250px;" id="calendar-title" name="calendar-title" type="text" value="<?php echo $title; ?>" /></label></p>
			<input type="hidden" id="calendar-submit" name="calendar-submit" value="1" />
<?php
}

function widget_text($args, $number = 1) {
	extract($args);
	$options = get_option('widget_text');
	$title = $options[$number]['title'];
	if ( empty($title) )
		$title = '&nbsp;';
	$text = $options[$number]['text'];
?>
		<?php echo $before_widget; ?>
			<?php $title ? print($before_title . $title . $after_title) : null; ?>
			<div class="textwidget"><?php echo $text; ?></div>
		<?php echo $after_widget; ?>
<?php
}

function widget_text_control($number) {
	$options = $newoptions = get_option('widget_text');
	if ( !is_array($options) )
		$options = $newoptions = array();
	if ( $_POST["text-submit-$number"] ) {
		$newoptions[$number]['title'] = strip_tags(stripslashes($_POST["text-title-$number"]));
		$newoptions[$number]['text'] = stripslashes($_POST["text-text-$number"]);
		if ( !current_user_can('unfiltered_html') )
			$newoptions[$number]['text'] = stripslashes(wp_filter_post_kses($newoptions[$number]['text']));
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_text', $options);
	}
	$title = htmlspecialchars($options[$number]['title'], ENT_QUOTES);
	$text = htmlspecialchars($options[$number]['text'], ENT_QUOTES);
?>
			<input style="width: 450px;" id="text-title-<?php echo "$number"; ?>" name="text-title-<?php echo "$number"; ?>" type="text" value="<?php echo $title; ?>" />
			<textarea style="width: 450px; height: 280px;" id="text-text-<?php echo "$number"; ?>" name="text-text-<?php echo "$number"; ?>"><?php echo $text; ?></textarea>
			<input type="hidden" id="text-submit-<?php echo "$number"; ?>" name="text-submit-<?php echo "$number"; ?>" value="1" />
<?php
}

function widget_text_setup() {
	$options = $newoptions = get_option('widget_text');
	if ( isset($_POST['text-number-submit']) ) {
		$number = (int) $_POST['text-number'];
		if ( $number > 9 ) $number = 9;
		if ( $number < 1 ) $number = 1;
		$newoptions['number'] = $number;
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_text', $options);
		widget_text_register($options['number']);
	}
}

function widget_text_page() {
	$options = $newoptions = get_option('widget_text');
?>
	<div class="wrap">
		<form method="POST">
			<h2><?php _e('Text Widgets', 'widgets'); ?></h2>
			<p style="line-height: 30px;"><?php _e('How many text widgets would you like?', 'widgets'); ?>
			<select id="text-number" name="text-number" value="<?php echo $options['number']; ?>">
<?php for ( $i = 1; $i < 10; ++$i ) echo "<option value='$i' ".($options['number']==$i ? "selected='selected'" : '').">$i</option>"; ?>
			</select>
			<span class="submit"><input type="submit" name="text-number-submit" id="text-number-submit" value="<?php _e('Save'); ?>" /></span></p>
		</form>
	</div>
<?php
}

function widget_text_register() {
	$options = get_option('widget_text');
	$number = $options['number'];
	if ( $number < 1 ) $number = 1;
	if ( $number > 9 ) $number = 9;
	for ($i = 1; $i <= 9; $i++) {
		$name = array('Text %s', 'widgets', $i);
		register_sidebar_widget($name, $i <= $number ? 'widget_text' : /* unregister */ '', $i);
		register_widget_control($name, $i <= $number ? 'widget_text_control' : /* unregister */ '', 460, 350, $i);
	}
	add_action('sidebar_admin_setup', 'widget_text_setup');
	add_action('sidebar_admin_page', 'widget_text_page');
}

function widget_categories($args) {
	extract($args);
	$options = get_option('widget_categories');
	$c = $options['count'] ? '1' : '0';
	$h = $options['hierarchical'] ? '1' : '0';
	$title = empty($options['title']) ? __('Categories') : $options['title'];
?>
		<?php echo $before_widget; ?>
			<?php echo $before_title . $title . $after_title; ?>
			<ul>
			<?php wp_list_cats("sort_column=name&optioncount=$c&hierarchical=$h"); ?>
			</ul>
		<?php echo $after_widget; ?>
<?php
}

function widget_categories_control() {
	$options = $newoptions = get_option('widget_categories');
	if ( $_POST['categories-submit'] ) {
		$newoptions['count'] = isset($_POST['categories-count']);
		$newoptions['hierarchical'] = isset($_POST['categories-hierarchical']);
		$newoptions['title'] = strip_tags(stripslashes($_POST['categories-title']));
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_categories', $options);
	}
	$count = $options['count'] ? 'checked="checked"' : '';
	$hierarchical = $options['hierarchical'] ? 'checked="checked"' : '';
	$title = wp_specialchars($options['title']);
?>
			<p><label for="categories-title"><?php _e('Title:'); ?> <input style="width: 250px;" id="categories-title" name="categories-title" type="text" value="<?php echo $title; ?>" /></label></p>
			<p style="text-align:right;margin-right:40px;"><label for="categories-count"><?php _e('Show post counts', 'widgets'); ?> <input class="checkbox" type="checkbox" <?php echo $count; ?> id="categories-count" name="categories-count" /></label></p>
			<p style="text-align:right;margin-right:40px;"><label for="categories-hierarchical" style="text-align:right;"><?php _e('Show hierarchy', 'widgets'); ?> <input class="checkbox" type="checkbox" <?php echo $hierarchical; ?> id="categories-hierarchical" name="categories-hierarchical" /></label></p>
			<input type="hidden" id="categories-submit" name="categories-submit" value="1" />
<?php
}

function widget_recent_entries($args) {
	extract($args);
	$title = __('Recent Posts', 'widgets');
	$r = new WP_Query('showposts=10');
	if ($r->have_posts()) :
?>
		<?php echo $before_widget; ?>
			<?php echo $before_title . $title . $after_title; ?>
			<ul>
			<?php  while ($r->have_posts()) : $r->the_post(); ?>
			<li><a href="<?php the_permalink() ?>"><?php if ( get_the_title() ) the_title(); else the_ID(); ?> </a></li>
			<?php endwhile; ?>
			</ul>
		<?php echo $after_widget; ?>
<?php
	endif;
}

function widget_recent_comments($args) {
	global $wpdb, $comments, $comment;
	extract($args, EXTR_SKIP);
	$options = get_option('widget_recent_comments');
	$title = empty($options['title']) ? __('Recent Comments', 'widgets') : $options['title'];
	$comments = $wpdb->get_results("SELECT comment_author, comment_author_url, comment_ID, comment_post_ID FROM $wpdb->comments WHERE comment_approved = '1' ORDER BY comment_date_gmt DESC LIMIT 5");
?>

		<?php echo $before_widget; ?>
			<?php echo $before_title . $title . $after_title; ?>
			<ul id="recentcomments"><?php
			if ( $comments ) : foreach ($comments as $comment) :
			echo  '<li class="recentcomments">' . sprintf(__('%1$s on %2$s'), get_comment_author_link(), '<a href="'. get_permalink($comment->comment_post_ID) . '#comment-' . $comment->comment_ID . '">' . get_the_title($comment->comment_post_ID) . '</a>') . '</li>';
			endforeach; endif;?></ul>
		<?php echo $after_widget; ?>
<?php
}

function widget_recent_comments_control() {
	$options = $newoptions = get_option('widget_recent_comments');
	if ( $_POST["recent-comments-submit"] ) {
		$newoptions['title'] = strip_tags(stripslashes($_POST["recent-comments-title"]));
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_recent_comments', $options);
	}
	$title = htmlspecialchars($options['title'], ENT_QUOTES);
?>
			<p><label for="recent-comments-title"><?php _e('Title:'); ?> <input style="width: 250px;" id="recent-comments-title" name="recent-comments-title" type="text" value="<?php echo $title; ?>" /></label></p>
			<input type="hidden" id="recent-comments-submit" name="recent-comments-submit" value="1" />
<?php
}

function widget_recent_comments_style() {
?>
<style type="text/css">.recentcomments a{display:inline !important;padding: 0 !important;margin: 0 !important;}</style>
<?php
}

function widget_recent_comments_register() {
	register_sidebar_widget(array('Recent Comments', 'widgets'), 'widget_recent_comments');
	register_widget_control(array('Recent Comments', 'widgets'), 'widget_recent_comments_control', 300, 90);
	
	if ( is_active_widget('widget_recent_comments') )
		add_action('wp_head', 'widget_recent_comments_style');
}

function widget_rss($args, $number = 1) {
	if ( file_exists(ABSPATH . WPINC . '/rss.php') )
		require_once(ABSPATH . WPINC . '/rss.php');
	else
		require_once(ABSPATH . WPINC . '/rss-functions.php');
	extract($args);
	$options = get_option('widget_rss');
	$num_items = (int) $options[$number]['items'];
	$show_summary = $options[$number]['show_summary'];
	if ( empty($num_items) || $num_items < 1 || $num_items > 10 ) $num_items = 10;
	$url = $options[$number]['url'];
	if ( empty($url) )
		return;
	while ( strstr($url, 'http') != $url )
		$url = substr($url, 1);
	$rss = fetch_rss($url);
	$link = wp_specialchars(strip_tags($rss->channel['link']), 1);
	while ( strstr($link, 'http') != $link )
		$link = substr($link, 1);
	$desc = wp_specialchars(strip_tags(html_entity_decode($rss->channel['description'], ENT_QUOTES)), 1);
	$title = $options[$number]['title'];
	if ( empty($title) )
		$title = htmlentities(strip_tags($rss->channel['title']));
	if ( empty($title) )
		$title = $desc;
	if ( empty($title) )
		$title = __('Unknown Feed', 'widgets');
	$url = wp_specialchars(strip_tags($url), 1);
	if ( file_exists(dirname(__FILE__) . '/rss.png') )
		$icon = str_replace(ABSPATH, get_settings('siteurl').'/', dirname(__FILE__)) . '/rss.png';
	else
		$icon = get_settings('siteurl').'/wp-includes/images/rss.png';
	$title = "<a class='rsswidget' href='$url' title='Syndicate this content'><img width='14' height='14' src='$icon' alt='RSS' /></a> <a class='rsswidget' href='$link' title='$desc'>$title</a>";
?>
		<?php echo $before_widget; ?>
			<?php $title ? print($before_title . $title . $after_title) : null; ?>
			<ul>
<?php
	if ( is_array( $rss->items ) ) {
		$rss->items = array_slice($rss->items, 0, $num_items);
		foreach ($rss->items as $item ) {
			while ( strstr($item['link'], 'http') != $item['link'] )
				$item['link'] = substr($item['link'], 1);
			$link = wp_specialchars(strip_tags($item['link']), 1);
			$title = wp_specialchars(strip_tags($item['title']), 1);
			if ( empty($title) )
				$title = __('Untitled');
			$desc = '';
			if ( $show_summary ) {
				$summary = '<div class="rssSummary">' . $item['description'] . '</div>';
			} else {
				$desc = str_replace(array("\n", "\r"), ' ', wp_specialchars(strip_tags(html_entity_decode($item['description'], ENT_QUOTES)), 1));
				$summary = '';
			}
			echo "<li><a class='rsswidget' href='$link' title='$desc'>$title</a>$summary</li>";
		}
	} else {
		echo __('<li>An error has occured; the feed is probably down. Try again later.</li>', 'widgets');
	}
?>
			</ul>
		<?php echo $after_widget; ?>
<?php
}

function widget_rss_control($number) {
	$options = $newoptions = get_option('widget_rss');
	if ( $_POST["rss-submit-$number"] ) {
		$newoptions[$number]['items'] = (int) $_POST["rss-items-$number"];
		$newoptions[$number]['url'] = strip_tags(stripslashes($_POST["rss-url-$number"]));
		$newoptions[$number]['title'] = trim(strip_tags(stripslashes($_POST["rss-title-$number"])));
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_rss', $options);
	}
	$url = htmlspecialchars($options[$number]['url'], ENT_QUOTES);
	$items = (int) $options[$number]['items'];
	$title = htmlspecialchars($options[$number]['title'], ENT_QUOTES);
	if ( empty($items) || $items < 1 ) $items = 10;
?>
			<p style="text-align:center;"><?php _e('Enter the RSS feed URL here:', 'widgets'); ?></p>
			<input style="width: 400px;" id="rss-url-<?php echo "$number"; ?>" name="rss-url-<?php echo "$number"; ?>" type="text" value="<?php echo $url; ?>" />
			<p style="text-align:center;"><?php _e('Give the feed a title (optional):', 'widgets'); ?></p>
			<input style="width: 400px;" id="rss-title-<?php echo "$number"; ?>" name="rss-title-<?php echo "$number"; ?>" type="text" value="<?php echo $title; ?>" />
			<p style="text-align:center; line-height: 30px;"><?php _e('How many items would you like to display?', 'widgets'); ?> <select id="rss-items-<?php echo $number; ?>" name="rss-items-<?php echo $number; ?>"><?php for ( $i = 1; $i <= 10; ++$i ) echo "<option value='$i' ".($items==$i ? "selected='selected'" : '').">$i</option>"; ?></select></p>
			<input type="hidden" id="rss-submit-<?php echo "$number"; ?>" name="rss-submit-<?php echo "$number"; ?>" value="1" />
<?php
}

function widget_rss_setup() {
	$options = $newoptions = get_option('widget_rss');
	if ( isset($_POST['rss-number-submit']) ) {
		$number = (int) $_POST['rss-number'];
		if ( $number > 9 ) $number = 9;
		if ( $number < 1 ) $number = 1;
		$newoptions['number'] = $number;
	}
	if ( $options != $newoptions ) {
		$options = $newoptions;
		update_option('widget_rss', $options);
		widget_rss_register($options['number']);
	}
}

function widget_rss_page() {
	$options = $newoptions = get_option('widget_rss');
?>
	<div class="wrap">
		<form method="POST">
			<h2><?php _e('RSS Feed Widgets', 'widgets'); ?></h2>
			<p style="line-height: 30px;"><?php _e('How many RSS widgets would you like?', 'widgets'); ?>
			<select id="rss-number" name="rss-number" value="<?php echo $options['number']; ?>">
<?php for ( $i = 1; $i < 10; ++$i ) echo "<option value='$i' ".($options['number']==$i ? "selected='selected'" : '').">$i</option>"; ?>
			</select>
			<span class="submit"><input type="submit" name="rss-number-submit" id="rss-number-submit" value="<?php _e('Save'); ?>" /></span></p>
		</form>
	</div>
<?php
}

function widget_rss_register() {
	$options = get_option('widget_rss');
	$number = $options['number'];
	if ( $number < 1 ) $number = 1;
	if ( $number > 9 ) $number = 9;
	for ($i = 1; $i <= 9; $i++) {
		$name = array('RSS %s', 'widgets', $i);
		register_sidebar_widget($name, $i <= $number ? 'widget_rss' : /* unregister */ '', $i);
		register_widget_control($name, $i <= $number ? 'widget_rss_control' : /* unregister */ '', 410, 200, $i);
	}
	add_action('sidebar_admin_setup', 'widget_rss_setup');
	add_action('sidebar_admin_page', 'widget_rss_page');

	if ( is_active_widget('widget_rss') )
		add_action('wp_head', 'widget_rss_head');
}

function widget_rss_head() {
?>
<style type="text/css">a.rsswidget{display:inline !important;}a.rsswidget img{background:orange;color:white;}</style>
<?php
}

function widgets_init() {
	global $register_widget_defaults;
	load_plugin_textdomain('widgets', 'wp-content/plugins/widgets');
	add_action('admin_menu', 'sidebar_admin_setup');

	$register_widget_defaults = true;
	widget_text_register();
	widget_rss_register();
	widget_recent_comments_register();
	register_sidebar_widget('Pages', 'widget_pages');
	register_widget_control('Pages', 'widget_pages_control', 300, 90);
	register_sidebar_widget(array('Calendar', 'widgets'), 'widget_calendar');
	register_widget_control(array('Calendar', 'widgets'), 'widget_calendar_control', 300, 90);
	register_sidebar_widget('Archives', 'widget_archives');
	register_widget_control('Archives', 'widget_archives_control', 300, 90);
	register_sidebar_widget('Links', 'widget_links');
	register_sidebar_widget(array('Meta', 'widgets'), 'widget_meta');
	register_widget_control(array('Meta', 'widgets'), 'widget_meta_control', 300, 90);
	register_sidebar_widget('Search', 'widget_search');
	register_sidebar_widget('Categories', 'widget_categories');
	register_widget_control('Categories', 'widget_categories_control', 300, 150);
	register_sidebar_widget(array('Recent Posts', 'widgets'), 'widget_recent_entries');
	$register_widget_defaults = false;

	do_action('widgets_init');
}

/////////////////////////////////////////////////////////// Actions and Registrations

add_action('init', 'widgets_init', 5);
?>
