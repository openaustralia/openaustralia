<?php 
get_header();
?>


<?php get_sidebar(); ?>




<div class="mpart">
<!-- loop -->

<?php if (have_posts()) :?>
<?php $postCount=0; ?>
<?php while (have_posts()) : the_post();?>
<?php $postCount++;?>


<h2><a href="<?php the_permalink() ?>" rel="bookmark" title="Permanent Link to <?php the_title(); ?>"><?php the_title(); ?></a></h2>
<h4>Published by <?php the_author() ?> | Filed under <?php the_category(', ') ?></h4>


<?php the_content ('Read the rest of this entry &raquo;'); ?>


<div class="date"><?php comments_popup_link('Comment now &#187;', '1 Comment &#187;', '% Comments &#187;', 'commentslink'); ?> . <?php the_time('F jS, Y') ?> </div>


<br/>

<div class="commentsblock">
<?php comments_template(); ?>
</div>
	
<?php endwhile; ?>
		
<?php else : ?>
				
<h3>
Not Found
</h3>

<strong>Sorry, but you are looking for something that isn't here.</strong>

<?php endif; ?>

<!-- end loop -->
			
</div>
	
<?php get_footer(); ?>