<div id="main">
<div id="right_side">
<div class="pad">

<img src="http://i71.photobucket.com/albums/i136/headsetop/pic2.jpg" alt="building image" />



<!-- sidebar -->

<br/>
<form id="searchform" method="get" action="<?php echo $_SERVER['PHP_SELF']; ?>">
<input type="text" name="s" id="s" size="43" /> <input type="submit" value="<?php _e('Search'); ?>"/>
</form>

<br/>

<center>
<a href="<?php bloginfo('rss2_url'); ?>"><img src="http://i71.photobucket.com/albums/i136/headsetop/rss.gif" alt="rss feed" /></a>
</center>



<div id="right_side_left">


<?php global $notfound; ?>
 <?php /* Creates a menu for pages beneath the level of the current page */
  if (is_page() and ($notfound != '1')) {
   $current_page = $post->ID;
   while($current_page) {
    $page_query = $wpdb->get_row("SELECT ID, post_title, post_status, post_parent FROM $wpdb->posts WHERE ID = '$current_page'");
    $current_page = $page_query->post_parent;
   }
   $parent_id = $page_query->ID;
   $parent_title = $page_query->post_title;
 

if ($wpdb->get_results("SELECT * FROM $wpdb->posts WHERE post_parent = '$parent_id' AND post_status != 'attachment'")) { ?>


<div class="sb-pagemenu">

<h2><?php echo $parent_title; ?> <?php _e('Subpages:'); ?></h2>
				
     <ul><?php wp_list_pages('sort_column=menu_order&title_li=&child_of='. $parent_id); ?></ul>
   
    <?php if ($parent_id != $post->ID) { ?>
     <a href="<?php echo get_permalink($parent_id); ?>"><?php printf(__('Back to %s'), $parent_title ) ?></a>
    <?php } ?>
   </div>
 <?php } } ?>
 
 <?php if (is_attachment()) { ?>
  <div class="sb-pagemenu">
   <a href="<?php echo get_permalink($post->post_parent); ?>" rev="attachment"><?php printf(__('Back to \'%s\''), get_the_title($post->post_parent) ) ?></a>
  </div>
<br/><br/>
 <?php } ?>


<?php if ( function_exists('dynamic_sidebar') && dynamic_sidebar(1) ) : else : ?>


<h3><?php _e('Categories:'); ?></h3>
	<ul class="sidemenu">
	<?php wp_list_cats(); ?>
	</ul>
 
<br/>

 
<h3><?php _e('Archives:'); ?> </h3>

 	<ul class="sidemenu">
	 <?php wp_get_archives('type=monthly'); ?>
 	</ul>

<br/>
<?php endif; ?>

</div>

<!-- //////////////////////////////////END LEFT SIDEBAR///////////////// -->

<div id="right_side_right">

<?php if ( function_exists('dynamic_sidebar') && dynamic_sidebar(2) ) : else : ?>

<h3><?php _e('Meta:'); ?> </h3>
<ul class="sidemenu">
		<?php wp_register(); ?>
		<li><?php wp_loginout(); ?></li>
		<li><a href="feed:<?php bloginfo('rss2_url'); ?>" title="<?php _e('Syndicate this site using RSS'); ?>"><?php _e('<abbr title="Really Simple Syndication">RSS</abbr>'); ?></a></li>
		<li><a href="feed:<?php bloginfo('comments_rss2_url'); ?>" title="<?php _e('The latest comments to all posts in RSS'); ?>"><?php _e('Comments <abbr title="Really Simple Syndication">RSS</abbr>'); ?></a></li>
		
<?php wp_meta(); ?>
</ul>
<br/>
  



<br/>

<?php endif; ?>


<!-- end sidebar -->

<br/>

</div>

</div>
</div>



<div id="left_side">

			<div class="intro">
				<div class="pad">Keeping a tab on those who are elected to represent us. 			
				</div>
</div>