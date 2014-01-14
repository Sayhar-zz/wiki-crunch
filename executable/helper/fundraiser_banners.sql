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

select banner, imps, timestamp 
	from (select banner, sum(count) as imps, timestamp 
		from pgehres.bannerimpressions where 
		timestamp <= '20131201010101' and timestamp >= '20130625010101' and banner regexp '(^B13|^B14)' 
		group by banner) 
as one 
where imps > 10000 and banner regexp '(^B13_|^B14_)' order by timestamp asc;
