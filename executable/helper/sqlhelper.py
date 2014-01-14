#Sahar Massachi for wikimedia
#GPL3
#April 23, 2013
"""called as a module by test-tsv.py
contains:
    constructors of sql queries:
        banner
        donor
        landing
"""
import sys
import calendar
import time
import re
import pdb    #pdb.set_trace()
##TODO: create a new banner table with a row_id id that's the id from pgehres.bannerimpressions. Then do an if duplicate clause



def banner(testid, testname, whereclause, stime):  
    #try:
    stime = calendar.timegm(time.strptime(stime, "%Y%m%d%H%M%S"))
    #except:
    #    stime = calendar.timegm(time.strptime('20101130000000', "%Y%m%d%H%M%S"))
    if(stime >= 1328054400):
        # > Wed, 01 Feb 2012 00:00:00 GMT
        return(bannerGehres(testid, testname, whereclause))
    if(stime >= 1289519700):
        # 2010-11-11 23:55
        return(bannerFaulkner(testid, testname, whereclause))
    else:
        return("#ERROR - too early")


def bannerinsertclause(id=True):
    clause = "INSERT INTO test.test_banner("
    if(id):
        clause += "\n\t id,"
    clause +="""test_id,
    test_name,
    banner,
    unixtime,
    timestamp,
    country,
    language,
    campaign,
    imps)
    """
    return clause
    

def bannerFaulkner(testid, testname, whereclause):
    whereclause = whereclause.replace('\ttimestamp', '\ton_minute').replace('\tbanner', "\tutm_source").replace('pc.iso_code', "country").replace("pl.iso_code", 'lang')
    
    #faulkner can't deal with campaign
    m = re.search("campaign regexp .*?($| and)", whereclause)
    if(m):
        m = m.group(0)
        cutstart = whereclause.find(m)
        cutlength = len(m)
        whereclause = whereclause[0:cutstart] + whereclause[cutstart+cutlength:]
        whereclause = whereclause.strip().strip(" and")
    
    doInsert = False
    insert = bannerinsertclause(False)
    
    begin = "SELECT '" + str(testid) + "' as test_id, \n\t'" + testname + "' as test_name," + """
    utm_source as banner,
    unix_timestamp(on_minute) as unixtime,
    SUBSTR(UPPER(country),1,4) as country,
    SUBSTR(LOWER(lang),1,4) as language,
    """ + 'NULL' + """ as campaign,
    sum(counts) as imps    
    FROM
    faulkner.banner_impressions
    """
    end = """
    GROUP BY
    banner, country, language, unixtime
    """
    insertend = 'ON DUPLICATE KEY UPDATE test.test_banner.id=id;'

    if(doInsert):
        return(insert + begin + whereclause + end + insertend)
    else:
        return(begin+whereclause+end+";")
    
def bannerGehres( testid, testname, code):
    code = code.replace('\trequest_time', '\ttimestamp')
    doInsert = False
    insert = bannerinsertclause()
    begin = """SELECT
    '""" + str(testid) + """' as test_id,\n\t'"""  + testname + """' as test_name,
	bi.banner as banner,
	unix_timestamp(bi.timestamp) as unixtime,
	SUBSTR(UPPER(pc.iso_code),1,4) as country,
	SUBSTR(LOWER(pl.iso_code),1,4) as language,
	bi.campaign as campaign,
	sum(bi.count) as imps
    FROM 
    pgehres.bannerimpressions bi
    left join pgehres.country pc on bi.country_id=pc.id
    left join pgehres.language pl on bi.language_id=pl.id
    """

    end = """
    GROUP BY
	bi.banner,
	bi.campaign,
	pc.iso_code,
	pl.iso_code,
	bi.timestamp
    ORDER BY 
    bi.timestamp ASC,
    bi.banner,
    pc.iso_code,
    pl.iso_code"""
    insertend = 'ON DUPLICATE KEY UPDATE test.test_banner.id=id;'

    if(doInsert):
        return(insert + begin + code + end + insertend)
    else:
        return(begin+code+end+";")


def donor(testid, testname, code, bannernames, landingregexp):

    code = code.replace('\tbanner', '\tutm_source').replace('\tcampaign', '\tutm_campaign').replace('\ttimestamp', '\tts').replace('pl.iso_code', 'language').replace('pc.iso_code', 'country').replace('\trequest_time', '\tts')
    
    exists_XX = False
    for b in bannernames:
        if (b[-3] == '_') & (b[-2:].isupper()):
            exists_XX = True
    
    ##EXCEPTION
    if(testid == 1366651685):
        exists_XX = False


    #if(banner regexp ".*_[A-Z][A-Z]$", left(banner,length(banner)-3), banner) as banner,
    
    doInsert = False
    
    insert = """INSERT INTO test.test_donor(
    contribution_id,
    test_id,
    test_name,
    banner,
    unixtime,
    timestamp,
    country,
    language,
    campaign,
    amount,
    paymenttype,
    amountsource,
    currency,
    landingpage)
    """

    #if(banner regexp ".*_[A-Z][A-Z]$", left(banner,length(banner)-3), banner) as banner,
    #substring_index(utm_source, ".", 1) as banner,
    
    begin = """SELECT 
    ct.id as contributionid, 
    '""" + str(testid) + "' as test_id,\n\t'" + testname + "' as test_name,\n\t" 
    
    banner = 'substring_index(utm_source, ".", 1)' if exists_XX  else """if( substring_index(utm_source, ".", 1)  regexp ".*_[A-Z][A-Z]$",
        left(substring_index(utm_source, ".", 1), length(substring_index(utm_source, ".", 1))-3  ),
        substring_index(utm_source, ".", 1)
    )"""
    
    begin_end = """unix_timestamp(ts) as unixtime,
    ts as timestamp,
    SUBSTR(UPPER(ct.country),1,4) as country,
	SUBSTR(LOWER(ct.language),1,4) as language,
    utm_campaign as campaign,
	total_amount as amount,
	substring_index(utm_source, ".", -1) as paymenttype,
	substring_index(cc.source, ' ', -1) as amountsource,
	left(cc.source, 3) as currency,
    SUBSTRING_INDEX( SUBSTRING_INDEX( utm_source, '.', 2 ), '.' ,-1 ) as landing
    FROM
	drupal.contribution_tracking ct
	left join civicrm.civicrm_contribution cc on ct.contribution_id = cc.id
    """
    
    begin = begin + banner + ' as banner,\n\t' + begin_end
    end = """
    ORDER BY
    ct.ts ASC"""
    insertend = 'ON DUPLICATE KEY UPDATE test.test_donor.contribution_id=ct.id;'
    
    code = code.replace('utm_source', banner)
    if landingregexp != "":
        code = code + " and\n\tSUBSTRING_INDEX( SUBSTRING_INDEX( utm_source, '.', 2 ), '.' ,-1 ) regexp " + landingregexp
    if(doInsert):
        return(insert + begin + code + end + insertend)
    else:
        return(begin+code+end+";" )
    

def landing(testid, testname, whereclause, landingregexp, bannernames, stime):
    #try:
    stime = calendar.timegm(time.strptime(stime, "%Y%m%d%H%M%S"))
    #except:
    #    stime = calendar.timegm(time.strptime('20101130000000', "%Y%m%d%H%M%S"))
    if(stime >= 1328662798):
        # 2012-02-08 00:59:58  GMT
        return(landingGehres(testid, testname, whereclause, landingregexp, bannernames, stime))
    if(stime >= 1289566500):
        # 2010-11-12 04:55:00
        return(landingFaulkner(testid, testname, whereclause, landingregexp, bannernames, stime))
    else:
        return("#ERROR - too early")
    
def landinginsert():
    clause = """INSERT INTO test.test_lp(
        test_id,
        test_name,
        banner,
        landingpage,
        unixtime,
        country,
        language,
        campaign"""
    clause += ")"
    return clause

def landingFaulkner(testid, testname, whereclause, landingregexp, bannernames, starttime):
    whereclause = whereclause.replace('\tbanner', '\tutm_source').replace('\tcampaign', '\tutm_campaign').replace('pl.iso_code', 'lang').replace('pc.iso_code', 'country').replace('\ttimestamp', '\trequest_time')
    
    doInsert = False
    
    #EXCEPTION:
    if(testid in [1369230920, 1369231016, 1369231118, 1369231201]):
        landingregexp = landingregexp.replace('WMFJAControlUS$','WMFJAControl$')
        
    sqlstatements = ""
    
    insert = landinginsert()
    end = ";"
    insertend = 'ON DUPLICATE KEY UPDATE test.test_lp.banner=banner\n'
    
    begin = """SELECT
    '""" + str(testid) + "' as test_id,\n\t'" + testname + "' as test_name," + """
    utm_source as banner,
    landing_page as landingpage,
    unix_timestamp(request_time) as unixtime,
    SUBSTR(UPPER(country),1,4) as country,
    SUBSTR(LOWER(lang),1,4) as language,
    utm_campaign as campaign
    FROM faulkner.landing_page_requests lp
    """
    
    whereclause = whereclause
    
    if(landingregexp != ""):
        whereclause += " and \n\tlanding_page regexp " + landingregexp + "\n"
    
    if(doInsert):
        sqlstatements += (insert + begin + whereclause + end + insertend)
    else:
        sqlstatements += (begin+whereclause+end+"\n")

    return sqlstatements


def landingGehres(testid, testname, code, landingregexp, bannernames, starttime):
    #NOTE: This code will fail badly if one banner is EXACTLY like the other banner + "_[A-Z][A-Z]". We are going to consider this an edge case and not worry about it.
    
    code = code.replace('\tbanner', '\tutm_source').replace('\tcampaign', '\tutm_campaign').replace('request_time', 'timestamp')
    doInsert = False
    
    sqlstatements = ""
    if starttime == "": 
        #default to landingpageimpression_raw_2012
        starttime = calendar.timegm(time.strptime("2012-01-01 01:00:00", "%Y-%m-%d %H:%M:%S"))
    cutofftime = calendar.timegm(time.strptime("2013-01-31 18:00:04", "%Y-%m-%d %H:%M:%S"))
    whichTable = 'pgehres.landingpageimpression_raw_2012' if (starttime < cutofftime) else 'pgehres.landingpageimpression_raw'
    
    insert = landinginsert()
    
    end = """ORDER BY 
    timestamp ASC"""
    
    insertend = 'ON DUPLICATE KEY UPDATE test.test_lp.lp_id=lp.id\n'
    
    for b in bannernames: 
        
        bannerstring = """if(substring_index(utm_source, '.', 1) regexp """ + "'" + b + "(_[A-Z][A-Z])+$', '""" + b +   """', substring_index(utm_source, '.', 1))"""
        
        
        begin = """SELECT
        '""" + str(testid) + "' as test_id,\n\t\t'" + testname + "' as test_name,\n\t" + bannerstring + """ as banner,
        landingpage,
        unix_timestamp(timestamp) as unixtime,
        SUBSTR(UPPER(pc.iso_code),1,4) as country,
    	SUBSTR(LOWER(pl.iso_code),1,4) as language,
        utm_campaign as campaign
        FROM """ +"\n\t\t"+ whichTable + """ lp
            left join pgehres.country pc on lp.country_id=pc.id
            left join pgehres.language pl on lp.language_id=pl.id
        """
        code = code.replace('utm_source', bannerstring)
        where = code + " and  \n\tsubstring_index(utm_source, '.', 1) regexp '" + b + "(_[A-Z][A-Z])*$'\n"
        if(landingregexp != ""):
            where += " and landingpage regexp " + landingregexp + "\n"
        
        
        #'if(utm_source regexp "' + b + '(_[A-Z][A-Z])*$", b, '

        
        if(doInsert):
            sqlstatements += (insert + begin + where + end + insertend)
        else:
            sqlstatements += (begin+where+end+";\n")

    return sqlstatements




def convert(name):
    return(re.sub('(.)([A-Z]{1})', r'\1 \2', name))

def mysql_prefix(dbname, tablename, tid):
    toreturn = "DELETE FROM " + str(dbname) + "." + str(tablename) + " WHERE test_id = '" + str(tid) + "'; \n"
    toreturn = toreturn + "INSERT INTO " + str(dbname) + "." + str(tablename) + "\n"
    return toreturn

