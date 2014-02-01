SELECT
banner, count(contributionid)
from
(SELECT 
    substring_index(utm_source, ".", 1) as banner,
    ts as timestamp,
    ct.id as contributionid,
    total_amount as amount
	FROM
	drupal.contribution_tracking ct
	left join civicrm.civicrm_contribution cc on ct.contribution_id = cc.id
    WHERE 
    ts > '20140101010101' and
	unix_timestamp(ts) >= unix_timestamp(NOW()) - 60
)
as lastminute
group by banner
ORDER BY count(contributionid) desc
LIMIT 2;
