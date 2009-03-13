	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<head profile="http://gmpg.org/xfn/11">
	<meta http-equiv="Content-Type" content="<?php bloginfo('html_type'); ?>; charset=<?php bloginfo('charset'); ?>" />

	<title><?php bloginfo('name'); ?><?php wp_title(); ?></title>
	

	<meta name="author" content="headsetoptions" />
	<meta http-equiv="Content-Type" content="<?php bloginfo('html_type'); ?>; charset=<?php bloginfo('charset'); ?>" />
	<meta name="generator" content="WordPress <?php bloginfo('version'); ?>" /> <!-- leave this for stats -->


	<style type="text/css" media="screen">
		@import url( <?php bloginfo('stylesheet_url'); ?> );
	</style>

	<link rel="alternate" type="application/rss+xml" title="RSS 2.0" href="<?php bloginfo('rss2_url'); ?>" />
	<link rel="alternate" type="text/xml" title="RSS .92" href="<?php bloginfo('rss_url'); ?>" />
	<link rel="alternate" type="application/atom+xml" title="Atom 0.3" href="<?php bloginfo('atom_url'); ?>" />
	
	<link rel="pingback" href="<?php bloginfo('pingback_url'); ?>" />
    <?php wp_get_archives('type=monthly&format=link'); ?>
	<?php //comments_popup_script(); // off by default ?>

	<?php wp_head(); ?>


</head>

<body>



<div class="content">
	<div id="top">
				<div id="icons">
					<a href="<?php echo get_settings('home'); ?>/" title="Home page"><img src="http://i71.photobucket.com/albums/i136/headsetop/home.gif" alt="Home" /></a>
					<a href="<?php echo get_settings('home'); ?>/contact/" title="Contact us"><img src="http://i71.photobucket.com/albums/i136/headsetop/contact.gif" alt="Contact" /></a>
					<a href="<?php echo get_settings('home'); ?>/sitemap/" title="Sitemap"><img src="http://i71.photobucket.com/albums/i136/headsetop/sitemap.gif" alt="Sitemap" /></a>
				</div>
				<h1><?php bloginfo('name'); ?></h1>
				<h2><?php bloginfo('description'); ?></h2>
	</div>

	<div id="menu">
		<ul>	
<li><a class="<?php if ( is_home() ){ ?>current<?php } ?>" href="<?php echo get_settings('home'); ?>/">Home</a></li>
<?php wp_list_pages('sort_column=menu_order&depth=1&title_li='); ?>
		</ul>
	</div>
