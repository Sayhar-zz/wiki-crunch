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

select banner, imps, timestamp, campaign 
	from (select banner, sum(count) as imps, min(timestamp) as timestamp , campaign
		from pgehres.bannerimpressions where 
		timestamp <= '20141201010101' and 
		timestamp >= '20131125010101' and 
		banner regexp '(^B13_|^B14_)' 
		group by banner) 
as one 
where imps > 10000 and banner regexp '(^B13_|^B14_)' order by timestamp asc;
#remember - imps is total impressions throughout the whole test.