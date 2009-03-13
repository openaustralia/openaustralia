<?php 
get_header();
?>


<?php get_sidebar(); ?>


<div class="mpart">
<!-- loop -->



			<?php if (have_posts()) : ?>
	
			<?php $post = $posts[0]; // Hack. Set $post so that the_date() works. ?>
			<?php /* If this is a category archive */ if (is_category()) { ?>				
			<h1>Archive for the '<?php echo single_cat_title(); ?>' Category </h1> <p>(<em>Chronologically Listed</em>)</p>
			
			<?php /* If this is a daily archive */ } elseif (is_day()) { ?>
			<h1>Archive for <?php the_time('F jS, Y'); ?></h1>
			
		 <?php /* If this is a monthly archive */ } elseif (is_month()) { ?>
			<h1>Archive for <?php the_time('F, Y'); ?></h1>
	
			<?php /* If this is a yearly archive */ } elseif (is_year()) { ?>
			<h1>Archive for <?php the_time('Y'); ?></h1>
			
			<?php /* If this is a search */ } elseif (is_search()) { ?>
			<h1>Search Results</h1>
			
			<?php /* If this is an author archive */ } elseif (is_author()) { ?>
			<h1>Author Archive</h1>
	
			<?php /* If this is a paged archive */ } elseif (isset($_GET['paged']) && !empty($_GET['paged'])) { ?>
			<h1>Blog Archives</h1>
	
			<?php } ?>

		 	<ul>

		 	<?php while (have_posts()) : the_post(); ?>
			<li><a href="<?php the_permalink() ?>"><?php the_title(); ?></a> |
			<small>
			Posted by <?php the_author() ?> on <?php the_time('M d Y');?>
			</small>
			 
			</li>
		
			<?php endwhile; ?>
			</ul>
		
		<div class="navigation">
			<div class="left"><?php next_posts_link('&laquo; Previous Entries') ?></div>
			<div class="right"><?php previous_posts_link('Next Entries &raquo;') ?></div>
		</div>

	
	<?php else : ?>

		<h1>Not Found</h1>

	<?php endif; ?>

<!-- end loop -->

			
</div>
		

<?php get_footer(); ?>