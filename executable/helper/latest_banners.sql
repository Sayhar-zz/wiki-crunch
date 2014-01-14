#select 
#	banner, imps 
#from 
#	(
#	select  
#		banner, sum(count) as imps 
#	from 
#		pgehres.bannerimpressions 
#	where 
#		timestamp >= '20131201000000' 
#		and banner regexp '^B13' 
#	group by 
#		banner
#	) 
#as 
#	one 
#where 
#	imps > 10000 
#and 
#	banner regexp '^B13_12';

select banner, imps from (select banner, sum(count) as imps from pgehres.bannerimpressions where timestamp >= '20131201000000' and banner regexp '^B13' group by banner) as one where imps > 10000 and banner regexp '^B13_12';
