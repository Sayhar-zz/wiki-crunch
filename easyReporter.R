#!/usr/bin/env Rscript

#options("repos"="http://cran.us.r-project.org")    ## US mirror

#package installation problems? Try: http://mazamascience.com/WorkingWithData/?p=1185

#First try without the lib= parameter, then if that doesn't work, use it
#install.packages("xtable", lib="~/.R/library")
#install.packages("plyr", lib="~/.R/library")
#install.packages("reshape", lib="~/.R/library")
#install.packages("latticeExtra", lib="~/.R/library")
#install.packages("binom", lib="~/.R/library")
#install.packages("RSQLite", lib="~/.R/library")
#install.packages("getopt", lib="~/.R/library")
###SETTINGS:
isshadow <- FALSE
issample <- FALSE
isold <- FALSE
variable_in_testname <- FALSE


library(xtable, quietly=TRUE)
library(latticeExtra, quietly=TRUE)
if(isshadow | issample){
	library(RSQLite, quietly=TRUE)
	#library(getopt, quietly=TRUE)
    library(binom, quietly=TRUE)
	library(plyr, quietly=TRUE)
	suppressMessages(suppressWarnings(library(reshape, quietly=TRUE)))
}else{
	library(RMySQL, quietly=TRUE)
	library(binom, lib="~/.R/library", quietly=TRUE)
    library(plyr, lib="~/.R/library", quietly=TRUE)
	suppressMessages(suppressWarnings(library(reshape, lib="~/.R/library", quietly=TRUE)))
}
if(issample){
	
}

#for backwards compatibility
paste0 <- function(...){return(paste(...,sep=""));}
Sys.setenv(TZ='UTC')


comment <- "
Welcome to the easyReporter engine.
This one file is meant to be run as a script, or copy/pasted into Rstudio.

This engine is explicitly made to analyze old (nonstandard!) wikimedia A/B tests. 
It can also deal with new (more standard!) tests as well. 
It isn't meant to be used in the future - though we call it an engine it's more 
of a glorified script. EG meant to accomplish a task once and not be reused.

Therefore you might see ugly or inconsistent code. I've tried to keep it to a minimum,
but we agreed to put a premium on speed rather than correctness, seeing as how
a new engine would need to be written for automatically turning new A/B tests
into results.

Use the flag sample=TRUE to see this in action with sample data

DEPENDENCIES:
	EITHER: 
testingdb.db                <- a sqlite db with pre-filled landings, banners, and donors tables.
executable/importDB.sh    	<- script to import specific tsv files into those testingdb.db tables.
data/TLBVVCL.tsv		  	<- TLBVVCL stands for Test, Landing, Banner, Variable, Value, Country, Language.
								This is the file that helps us split tests into subtests by identifying
								which landings or banners are in which values for which variables, per test.
								(Also, if we should split by country and language)
data/screenshots.tsv		<- table linking each banner or landing page to a screenshot.
	OR:
the relevant wikimedia mariadb (called fr_test)
data/easyform.tsv 			<- the newer streamlined info for newer tests
	OR: 
sample/easyform.tsv 		<- sample test
sample/banners.tsv 			<- banners from sample test
sample/donors.tsv 			<- clicks/donations from sample test

OUTPUT:
reports/*                 <- each sub-test gets its own folder
reports/allreports/*      <- each sub-test gets its own html file with a bit of data
testingdb.db                 <- four new tables: error, meta, polish, and polishCUM
								error : table listing tests that did not turn into reports
								meta : table with the topline info on analyzed tests
								polish: standardized info on #donations / minute / value
								polishCUM: Cumulative version of polish
								#screenshots: link subtests to screenshots



TERMINOLOGY:
test / test_id 		<- signified by a name like: 1366661271 (old tests) or B13_1129_avg (new tests). Corresponds to an actual test run in wikipedia
subtest 			<- named like so: <test_id><variable><COUNTRY><language> . The unit of analysis. One test may
							contain several subtests. It may be broken into different subtests by country and 
							language, it might be broken into a banner-testing and a landing-page subtest, etc.
variable 			<- the thing being tested in a subtest. For example, the 'color' variable in 1366645535color
							shows that we are testing the effects of changing the color of the banner. 
value 				<- the different variations are called values. So, if 'color' was a variable, then 'yellow' and
							'blue' might be values. In a test with two variations - 'color' and 'askstring', there 
							might be four banners - blue3, yellow3, blue5, yellow5. blue, yellow, 3, and 5 are values, 
							and the subtest on the color variable would lump yellow3 and yellow5 in the 'yellow' value,
							and blue3 and blue5 in the 'blue' value.
testname 			<- here we are a bit inconsistent. In a few places, testname refers to the more-or-less-human-readable
							description of what a test is about.  In others, testname is the canonical identifier for
							a particular subtest. For example, 1366645609ifEveryoneDonatedUS.
banner 				<- a banner is the first fundraising frame shown to visitors. In many newer tests, 'dropdown' banners are
							those that show extra information when clicked. Older tests often instead sent you to a landing page.
landing 			<- in older tests, sometimes clicking on a banner took you to a different page that asked for your payment info.

"

genMetaTable <- function(){
	if(isshadow | issample){
		drv <- dbDriver("SQLite") 
		con <- dbConnect(drv, "testingdb")
	}else{ 
		con <- dbConnect(MySQL(), dbname="fr_test")
	}
	on.exit(dbDisconnect(con))

	if(!dbExistsTable(con, 'meta') || nrow(dbReadTable(con,"meta")) < 1){
		size <- 0
		metatable <- data.frame(test_id = character(size), var=character(size), multiple=character(size), country=character(size), language=character(size), winner = character(size), loser=character(size), bestguess=numeric(size), p = numeric(size), lowerbound=numeric(size), upperbound=numeric(size), totalimpressions=integer(size), totaldonations=integer(size), time=integer(size), type=integer(size), testname=character(size), dollarimprovement=numeric(size), dollarlower=numeric(size), dollarupper=numeric(size), dollarimprovementpct=numeric(size), dollarlowerpct=numeric(size), dollarupperpct=numeric(size), stringsAsFactors=FALSE)
	} else{
		metatable <- dbReadTable(con, 'meta')
	}
	return(metatable)
}

genErrorTable <- function(){
	
	if(isshadow | issample){
		drv <- dbDriver("SQLite") 
		con <- dbConnect(drv, "testingdb")
	}else{ 
		con <- dbConnect(MySQL(), dbname="fr_test")
	}
	on.exit(dbDisconnect(con))
	if(!dbExistsTable(con, 'error') || nrow(dbReadTable(con,"error")) < 1){
		errortable <- data.frame(character(), character(), character(), character(), character(), character(), stringsAsFactors=FALSE)
		colnames(errortable) <- c("test_id", "var", 'multiple', 'country', 'language', 'error')
	}else{
		errortable <- dbReadTable(con, 'error')
	}

	
	

	return(errortable)
}

addOrUpdateErrorTable <- function(errortable, toinsert){
	#assumes toinsert is already a full line
	row.names(errortable) <- NULL
	slice <- subset(errortable, test_id == toinsert[1] & var==toinsert[2] & multiple==toinsert[3] & country == toinsert[4] & language == toinsert[5])
	if(nrow(slice) > 0 ){
		index <- which(errortable$test_id == toinsert[1] & errortable$var==toinsert[2] & errortable$multiple==toinsert[3] &errortable$country == toinsert[4] & errortable$language == toinsert[5])
		errortable[index, ] <- toinsert
	}else{
		errortable[nrow(errortable) +1 ,] <- toinsert		
	}
	
	if(isshadow | issample){
		drv <- dbDriver("SQLite") 
		con <- dbConnect(drv, "testingdb")
	}else{ 
		con <- dbConnect(MySQL(), dbname="fr_test")
	}
	on.exit(dbDisconnect(con))
	if(dbExistsTable(con, 'error')){
		dbRemoveTable(con, 'error')
	}
	dbWriteTable(con, "error", errortable)

	
	
	print("error!")
	print(toinsert[6])
	return(errortable)
}

addOrUpdateScreenshots <- function(screentable, thisid, thistest){

	
	if(isshadow | issample){
		drv <- dbDriver("SQLite") 
		con <- dbConnect(drv, "testingdb")
	}else{ 
		con <- dbConnect(MySQL(), dbname="fr_test")
	}
	on.exit(dbDisconnect(con))
	if(!dbExistsTable(con, 'screenshots')){
		dbWriteTable(con, 'screenshots', screentable, row.names=FALSE)
	}else{
		oldTable <- dbReadTable(con, 'screenshots')
		removethese <- which(oldTable$test_id == thisid & oldTable$testname == thistest)
		if(length(removethese) > 1){
			#removethese is undefined if you need to remove nothing. 
			#passing -undefined gives us an empty oldTable
			oldTable <- oldTable[-removethese,]	
		}

		colnames(screentable) <- colnames(oldTable)
		newTable <- rbind(oldTable, screentable)
		dbRemoveTable(con, 'screenshots')
		dbWriteTable(con, 'screenshots', newTable, row.names=FALSE)
	}
	
	
}


prepareLanding <- function(LBV, landing, clicks){
	imps <- landingToImpForm(landing)
	clicks$banner <- clicks$landing
	LBV$banner <- LBV$landing
	LBV$landing <- NULL
	return(list(LBV=LBV, imps=imps, clicks=clicks))
}
	

doReport <- function(imps, clicks, metatable, LBV, testname, testid, settings, country='YY', language='yy', write=FALSE, type='error'){
	variable <- toString(unique(LBV$variable))

	

	if(type %in% c("banner", "combo")) {
		settings$threshold <- settings$banner_threshold
		settings$total_threshold <- settings$banner_total_threshold
		settings$perminthreshold <- settings$banner_perminthreshold
	}
	if(type=="landing") {
		settings$threshold <- settings$landing_threshold
		settings$total_threshold <- settings$landing_total_threshold
		settings$perminthreshold <- settings$landing_perminthreshold
	}

	instructions_and_data <- cleandata(imps, clicks, testid, LBV, settings, type)
	reports <- list()

	if(instructions_and_data$skip){
		#if skip, then skip
		report <- instructions_and_data
		errorline <- c(testid, variable, "",country, language, report$why)
		report$why <- errorline
		reports[[1]] <- report
	}else{
		#if not skip:
		#if multiple , then do multiples
		#otherwise, do one
		imps <- instructions_and_data$data$imps
		clicks <- instructions_and_data$data$clicks
		donations <- instructions_and_data$data$donations
		numtypes <- instructions_and_data$numtypes

		multiple <- 0
		#
		if(numtypes > 2){
			winner <- instructions_and_data$winner
			mtable <- metatable
			elines <- c()
			for (loser in instructions_and_data$losers){
				multiple <- multiple + 1
				values <- c(winner, loser)
				thisBV <- LBV[LBV$value %in% values,]
				thisreport <- oneReport(testid, testname, mtable, imps, clicks, donations, thisBV, settings, var=variable,country=country, multiple=toString(multiple),language=language, full=write, type=type)
				thisreport[["BV"]] <- thisBV

				if(thisreport$skip){
					errorline <- c(testid, var,multiple ,country, language, thisreport$why)
				}

				reports[[length(reports) + 1]] <- thisreport
				mtable <- thisreport$metatable
			}
		}else {
			report <- oneReport(testid, testname, metatable, imps, clicks, donations, LBV, settings, var=variable,country=country, multiple=toString(multiple), language=language, full=write, type=type)
			report[["BV"]] <- LBV
			reports[[1]] <- report
		}#numtypes should never < 2 -- we'd have caught it earlier and made a skip
	}
	

	#FIX FIX FIX <- why does it need both clicks AND donations? Is there an easier way to deal with this?
	
	return(reports)
}

dobannernameException <- function(testid, impbanner, clickbanner, imps, clicks){
	bannerReplace <- function(from, to, df){
		df$banner <- as.character(df$banner)
		sub <- df[which(df$banner == from),]
		if(nrow(sub) == 0) return(df)
			
		df[which(df$banner == from),]$banner <- to
		df$banner <- factor(df$banner)
		return(df)
	}
	
	bannerRemove <-function(remove, df){
		df2 <- df[-which(df$banner %in% remove),]
		if(nrow(df2) > 0){
			df2$banner <- factor(df2$banner)
			return(df2)
		}
		return(df)
	}
	
	#if(testid == 1367833800){
	#	remove <- c("B11_Foundation_PageTop_Fader_B", "B11_Foundation_PageTop_Fader", "B11_Foundation_PageTop_Fader_C", "B11_Foundation_PageTop_Fader_Facts_Nobullets", "B11_Foundation_PageTop_Fader_Sandbox", "B11_Foundation_PageTop_Fader_Tall", "B11_Foundation_PageTop_Fader2", "B11_Foundation_PageTop_ThermoFader_US", "B11_Foundation_PageTop_TripleFader", "http://en.wikipedia.org/wiki/Main_Page?banner=B11_Foundation_PageTop_Fader_C")
	#	imps <- bannerRemove(remove, imps)
	#}
	if(testid == 1367833921){
		if('B11_1120_If_PA10' %in% imps$banner | 'B11_1120_IF_PA' %in% imps$banner ){
			imps <- bannerReplace("B11_1120_If_PA10", 'B11_1120_If_PA10_US', imps)
			imps <- bannerReplace("B11_1120_IF_PA", 'B11_1120_IF_PA_US', imps)
		}
		if('B11_1120_If_PA10' %in% clicks$banner | 'B11_1120_IF_PA' %in% clicks$banner ){
			clicks <- bannerReplace('B11_1120_IF_PA', 'B11_1120_IF_PA_US', clicks)
			clicks <- bannerReplace('B11_1120_If_PA10', 'B11_1120_If_PA10_US', clicks)
		}
	}
	if(testid == 1369208347){
		imps <- bannerReplace('WMFJA051go', 'WMFJA060', imps)
		imps <- bannerReplace('20101227_JA_65_US?', '20101227_JA_65_US', imps)
	}
	if(testid == 1369127471){
		remove <- c("", "cc31", "JA1", "WMFJA031" , "WMFJA085", "WMFJA1" ,"WMFJA1US")
		clicks <- bannerRemove(remove, clicks)
	}
	if(testid %in% c(1369230920, 1369231016, 1369231118, 1369231201)){
		imps <- bannerReplace('WMFJAControl','WMFJAControlUS')
	}	

	return(list(imp=imps, click=clicks))
}

isbannernameException <- function(testid, impbanner, clickbanner){
	#just lots of if statements

	if(testid %in% c(1367833921, 1369231016, 1369231118, 1369231201, 1369208347, 1369127471, 1369230920)) {return(TRUE)}
	#if(testid == 1369208347) return(TRUE)
	#if(testid == 1369127471) return(TRUE)
	#if(testid == 1369230920) return(TRUE)
	return(FALSE)
	

}

isValidComboTest <- function(LBV){
	#each landing page has a different banner
	#(we'll use the impression stats for banner but also add the landing screenshot)
	isvalid <- FALSE
	#if no banner goes to > 1 landing
	check <- TRUE
	for(ubanner in unique(LBV$banner)){
		lines <- subset(LBV, banner==ubanner)
		if(length(unique(lines$landing)) != 1){
			check <- FALSE
		}
	}
	if(check){
		isvalid <- TRUE
	}
	return(isvalid)
}

comboToImpForm <- function(banners, LBV){
	#assuming that it's the one type of valid combo test
	#aka each banner only goes to 1 landing page
	#(but a landing page can have multiple banners)
	for(i in 1:nrow(LBV)){
		line <- LBV[i,]
		banners[banners$banner == line$banner]$var <- line$var
		#landing[landing$banner == line$banner & landing$landing == line$landing]$var <- line$var
	}
	return(banners)
}


landingToImpForm <- function(landing){
	
	ndata <- landing	
	ndata$timestamp <- minuteGrouper(ndata$timestamp, 1)
	ndata$banner <- NULL
	ndata$banner <- ndata$landing
	ndata$imps <- 1
	ndata$language <- as.character(ndata$language)
	data <- aggregate(imps~ banner + test_id + test_name + country + language + timestamp, data=ndata,sum)
	return(data)
}


minuteGrouper <- function(times, groupby){
		t<-as.POSIXct(trunc(as.double(times)/(60*groupby))*groupby*60, origin = "1970-01-01", tz = "UTC")
		return(t)
}











#Given the testing matrix, return the ids of all the test id's to check.
allIDs <- function(TLBVVCL){
	toreturn <- vector()
	for(test in unique(TLBVVCL$test_id)){
		toreturn <- c(toreturn, test)
	}
	return(toreturn)
}

whichCountries <- function(df){
	return(unique(df$country))
}

whichLanguages <- function(df){
	return(unique(df$language))
}

whichVariables <- function(LBVVCL){
	return(unique(LBVVCL$variable))
}

splitOnCountry <- function(LBVCL){
	return(sum(LBVCL$split.on.country == TRUE)> 0)
}

splitOnLanguage <- function(LBVCL){
	return(sum(LBVCL$split.on.language == TRUE)> 0)
}

isJustBannerTest <- function(LBV){
	if(! "landing" %in% colnames(LBV)){
		return(TRUE)
	}	
	if(all(is.na(LBV$landing))){
		return(TRUE)
	}
	return(FALSE)
}

isJustLandingTest <- function(LBV){
	if(all(is.na(LBV$banner))){
		return(TRUE)
	}
	#if(length(unique(LBV$banner)) <= 1 ){
	#	return(TRUE)
	#}
	return(FALSE)
}



saveReport <- function(report, testid, testname, screenshots, errortable, settings){
	
	roundby <- settings$digitsround
	BV <- report$BV
	value <- BV$value
	banners <- BV$banner
	landings <- BV$landing
	multiple <- report$multiple
	if(nrow(screenshots) == 0){
		errortable <- addOrUpdateErrorTable(errortable, c(testid, toString(BV$var[1]), "", "","", "no screenshots"))
		return(list(success=FALSE, errortable=errortable))
	}
	

	


	#for each banner
	#if that banner has a landing page next to it in BV (aka if combo test)
	#find the image source for that landing page
	#and add it to the row of the screenshot table
	if(report$type == 'combo' | 'landing' %in% names(BV)){
		for(i in 1:length(banners)){
			BVlines <- subset(BV, banner==banners[i])
	    	for(k in 1:length(BVlines)){
	    		line <- BVlines[k,]
	    		if(!is.na(line$landing)){
	    			landingname <- line$landing
	    			screenshotline <- subset(screenshots, banner.or.landing == landingname)
	    			landingshot <- screenshotline$screenshot
	    			screenshots[screenshots$banner.or.landing == as.character(banners[i]),]$extra.screenshot.1 <- landingshot
	    		}
	    	}
		}
	}
	

	for(i in 1:length(banners)){
	    screenshots[screenshots == as.character(banners[i])] <- as.character(value[i])
	}

	
	screenshots <- subset(screenshots, banner.or.landing %in% value)
	colnames(screenshots)[2] <- "value"
	screenshots$testname <- testname

	addOrUpdateScreenshots(screenshots, testid, testname)
	
	varlookup <- BV[c('value', 'description')]
	varlookup$description <- gsub(".", " ", varlookup$description, fixed=TRUE)
	vpath <- file.path(report$path, 'val_lookup.csv')
	write.csv(varlookup, vpath, row.names=FALSE)

	spath <- file.path(report$path, 'screenshots.csv')
	write.csv(screenshots, spath, row.names=FALSE)
	
	#write the relevant line in metatable to a file
	#mindex <- which(report$metatable$var == unique(BV$variable.for.url) & (report$metatable$test_id == testid) & (report$metatable$multiple == multiple))
	mindex <- which(report$metatable$var == unique(BV$variable) & (report$metatable$test_id == testid) & (report$metatable$multiple == multiple) & (report$metatable$language == report$language))
	mpath <- file.path(report$path, 'meta.csv')
	meta1 <- report$metatable[mindex,] 
	write.csv(meta1, mpath, row.names=FALSE)

	if('winner' %in% names(report)){
			write(report$winner, file.path(report$path, 'winner.txt'))
	}

	#writing an html file with links to all the tests
	colnames(report$A)[5] <- "donations/1000 impressions"
	colnames(report$A)[6] <- "$/1000 impressions"
	colnames(report$A)[8] <- "amount20/1000bi"
	
	#Note to self - this probably works instead
	#report$A[6] <- paste0("$", prettyNum(as.numeric(report$A[6]), big.mark=",", scientific=FALSE) )})
	
	report$A[2] <- lapply(report$A[2], function(x){ x<-paste0(    prettyNum(as.numeric(x),big.mark=",",scientific=FALSE))})
	report$A[3] <- lapply(report$A[3], function(x){ x<-paste0(   prettyNum(as.numeric(x),big.mark=",",scientific=FALSE))})
	report$A[4] <- lapply(report$A[4], function(x){ x<-paste0(   prettyNum(as.numeric(x),big.mark=",",scientific=FALSE))})
	report$A[6] <- lapply(report$A[6], function(x){ x<-paste0("$",    prettyNum(as.numeric(x),big.mark=",",scientific=FALSE))})
	report$A[7] <- lapply(report$A[7], function(x){ x<-paste0("$", prettyNum(round(as.numeric(x), digits=2), big.mark=",", scientific=FALSE) )})
	report$A[8] <- lapply(report$A[8], function(x){ x<-paste0("$", prettyNum(as.numeric(x), big.mark=",", scientific=FALSE) )})
	report$A[9] <- lapply(report$A[9], function(x){ x<-paste0("$", prettyNum(round(as.numeric(x), digits=2), big.mark=",", scientific=FALSE) )})
	report$A[10] <- lapply(report$A[10], function(x){ x<-paste0("$", prettyNum(round(as.numeric(x), digits=2), big.mark=",", scientific=FALSE) )})
	report$A[11] <- lapply(report$A[11], function(x){ x<-paste0("$", prettyNum(round(as.numeric(x), digits=2), big.mark=",", scientific=FALSE) )})
	report$A[12] <- lapply(report$A[12], function(x){ x<-paste0("$", round(as.numeric(x), digits=2) )})
	report$A[13] <- lapply(report$A[13], function(x){ x<-paste0(round(as.numeric(x), digits=3), "%")})
	report$A[14] <- lapply(report$A[14], function(x){ x<-paste0("$", round(as.numeric(x), digits=2) )})
	report$A[15] <- lapply(report$A[15], function(x){ x<-paste0("$", round(as.numeric(x), digits=2) )})
	x <- xtable(report$A)
	reportpath <- file.path(report$path, 'reportA.html')

	
	ecom <- report$ecom
	for(col in 2:length(ecom)){
		ecom[col] <- sapply(ecom[col], function(x){return(round(as.numeric(x), digits=3))})
	}
	write.table(ecom, file=file.path(report$path, "ecom.tsv"), row.names=FALSE, quote=FALSE, sep="\t")

	print(x, type="html", file=reportpath, append=FALSE, include.rownames=FALSE, html.table.attributes="class='table table-hover table-bordered'")
	#write.csv(report$A, file=file.path(report$path,'reportA.csv'), row.names=FALSE, quote=FALSE)
	
	dollarformat <- function(old){
		new <- paste0("$", round(old, digits=2))
		return(new)	
	}

	percentformat <- function(old){
		new <- paste0(round(old, digits=2), "%")
		return(new)
	}

	colnames(report$B)[2] <- "donations/impression"
	colnames(report$B)[3] <- "Donation increase / 1000bi"
	colnames(report$B)[4] <- "$/impression"
	colnames(report$B)[5] <- "Dollar increase / 1000bi"
	colnames(report$B)[6] <- "% impressions"
	#a20diff
	colnames(report$B)[8] <- "p"
	colnames(report$B)[9] <- "power"
	colnames(report$B)[10] <- "lower 95% confidence (donation)"
	colnames(report$B)[11] <- "upper 95% confidence (donations)"
	colnames(report$B)[12] <- "lower 95% confidence ($)"
	colnames(report$B)[13] <- "upper 95% confidence ($)"

	report$B[1,2] <- percentformat(report$B[1,2])
	report$B[1,3] <- round(report$B[1,3], digits=roundby)
	report$B[1,4] <- percentformat(report$B[1,4])
	report$B[1,5] <- dollarformat(report$B[1,5])
	report$B[1,6] <- percentformat(report$B[1,6])
	report$B[1,7] <- dollarformat(report$B[1,7])
	report$B[1,9] <- round(report$B[1,9], digits=roundby)
	report$B[1,10] <- percentformat(report$B[1,10] * 100)
	report$B[1,11] <- percentformat(report$B[1,11] * 100)
	report$B[1,12] <- percentformat(report$B[1,12] * 100)
	report$B[1,13] <- percentformat(report$B[1,13] * 100)
	x <- xtable(report$B)
	reportpath <- file.path(report$path, 'reportB.html')
	print(x, type="html", file=reportpath, append=FALSE, include.rownames=FALSE, html.table.attributes="class='table table-hover table-bordered'")
	
	jpeg(file.path(report$path, "pamplona.jpeg"), width=1200, height=800)
	print(report$graphtwo)
	dev.off()
	
	#}
	report$E[4] <- lapply(report$E[4], function(x){ x<-paste0(round(100*x, digits=2), "%")})
	report$E[5] <- lapply(report$E[5], function(x){ x<-paste0("$", round(x, digits=2))})
	report$E[6] <- lapply(report$E[6], function(x){ x<-paste0("$", round(x, digits=2))})
	x <- xtable(prettyNum(report$E,big.mark=",", scientific=FALSE))
	#NOTE - dont' write reportC.html anymore 
	#NOTE - we are now, just for internal uses
	reportpath <- file.path(report$path, 'reportE.html')
	print( x, type="html", file=reportpath, append=FALSE, include.rownames=FALSE, html.table.attributes="class='table table-hover table-bordered'")
	
	l <- length(report$D)
	for(i in 2:l){
		report$D[i] <- lapply(report$D[i], function(x){ x<-paste0("$", prettyNum(round(as.numeric(x), digits=2), big.mark=",", scientific=FALSE) )})
	}
	x <- xtable(report$D)
	reportpath <- file.path(report$path, 'reportD.html')
	print( x, type="html", file=reportpath, append=FALSE, include.rownames=FALSE, html.table.attributes="class='table table-hover table-bordered'")

	
	#i <- 0
	#for(val in report$F){
	#	i <- i + 1
	#	reportpath <- file.path(report$path, paste0('reportF',i,'.html'))
		#get rid of factors
	#	tmp <- sapply(val, is.factor); val[tmp] <- lapply(val[tmp], as.character)
		#round digits
	#	val[2] <- lapply(val[2], function(x){round(as.numeric(x), digits=2)})
		#add %
	#	val[2] <- lapply(val[2], function(x){paste0(x, "%")})
	#	x <- xtable(val)
	#	print( x, type="html", file=reportpath, append=FALSE, include.rownames=FALSE, html.table.attributes="class='table table-hover table-bordered'")
	#}
	#rm(i)

	#i <- 0
	#for(val in report$G){
	#	i <- i + 1
	#	reportpath <- file.path(report$path, paste0('reportG',i,'.html'))
		#get rid of factors
	#	tmp <- sapply(val, is.factor); val[tmp] <- lapply(val[tmp], as.character)
		#round digits
	#	val[2] <- lapply(val[2], function(x){round(as.numeric(x), digits=2)})
		#add %
	#	val[2] <- lapply(val[2], function(x){paste0(x, "%")})
	#	x <- xtable(val)
	#	print( x, type="html", file=reportpath, append=FALSE, include.rownames=FALSE, html.table.attributes="class='table table-hover table-bordered'")
	#}
	#rm(i)
	



	jpeg(file.path(report$path, "bannerviews.jpeg"), width=1200, height=800)
	print(report$graphone)
	dev.off()

	


	#diagnostic
	eg <- report$extraGraphs
	for(name in names(eg)){
		for(i in 1:length(eg[[name]])){
			if(name == "blank"){
				filename <- paste("diagnostic", i, sep="_")
			}else{
				filename <- paste("diagnostic", name, i, sep="_")
			}
			jpeg(file.path(report$path, paste0(filename, ".jpeg")), width=1200, height=800)	
			print(report$extraGraphs[[name]][i])
			dev.off()
		}
	}
	
	#if(!report$multiple){
		#extradata <- data.frame(text=c("Percentage difference between impressions", "Expected difference if they were served randomly and evenly"), num=c(report$extradata$diff,report$extradata$expected ), stringsAsFactors=FALSE)
		#extradata[nrow(extradata)+1,]<-c('The biggest country made up this % of total impressions', round( report$extradata$impshare, digits=5))	

		#x <- xtable(extradata, digits=5)
		#reportpath <- file.path(report$path, 'diagnostic_data.html')
		#print(x, type="html", file=reportpath, append=FALSE, include.colnames=FALSE, include.rownames=FALSE, html.table.attributes="class='table table-hover table-bordered'")
	#}
	

	html <- file.path(report$path, 'show.html')
	call <- paste('./executable/helper/htmlerizer.py -p', report$path, '-t', testid, ">", html )
	system(call)
	dir.create(file.path('report', 'allreports'), showWarnings = FALSE)
	html2 <- file.path('./report/allreports', paste0(testname, '.html'))
	#call <- paste('./executable/helper/htmlerizer.py -r -p', report$path, '-t', testid, ">", html2 )
	call <- paste('./executable/helper/htmlerizer.py -r -p', report$path, '-t', testid, ">", html2, '-n', testname)
	system(call)
	call <- paste('touch', report$path)
	system(call) #for "last modified" on the mac
	return(list(success=TRUE, errortable=errortable))
}

forCountryLanguage <- function(c, b, l, yesCountry=FALSE, yesLanguage=FALSE, metatable, errortable, LBVCL, theseshots, testid, testname, write=FALSE){

	if(yesCountry & yesLanguage){
		for(nation in whichCountries(b)){
			for(lang in whichLanguages(b)){
				thisname <- paste0(testname, nation, lang)
				tables <- readwritereport(subset(c, country==nation & language == lang), subset(b, country==nation & language == lang), subset(l, country==nation & language == lang), metatable, errortable, LBVCL, theseshots, testid, thisname, write, nation, lang)				
				metatable <- tables$metatable
				errortable <- tables$errortable
			}
		}
	} else if(yesCountry){
		for(nation in whichCountries(b)){
			thisname <- paste0(testname, nation)
			tables <- readwritereport(subset(c, country == nation), subset(b, country == nation), subset(l, country == nation), metatable, errortable, LBVCL, theseshots, testid, thisname, write, nation)
			metatable <- tables$metatable
			errortable <- tables$errortable	
		}
	} else if(yesLanguage){
		for(lang in whichLanguages(b)){
			thisname <- paste0(testname, lang)
			tables <- readwritereport(subset(c, language == lang), subset(b, language == lang), subset(l, language == lang), metatable, errortable, LBVCL, theseshots, testid, thisname, write, language=lang)			
			metatable <- tables$metatable
			errortable <- tables$errortable
		}
	}else{
		tables <- readwritereport(c,b,l, metatable, errortable, LBVCL, theseshots, testid, testname, write)
	}
	return(tables)
}


readwritereport <- function(clicks, banners, landing, metatable, errortable, LBVCL, theseshots, testid, testname, write, country='YY', language='yy'){
	settings <- list(landing_threshold=5, 	   #stop graphing when landing imps drop below X
					banner_threshold=500,	   #stop graphing when banners/min drop below X
					donate_threshold=5,		   #stop the graph when there are less than X donations per minute
					#allowedtodrop=20,		   #how many irregular (not in TLBVVCL) banners are allowed before the test is dropped
					allowedtodrop=99999999,
					banner_total_threshold=10000,
					landing_total_threshold=500, #if the total impressions are less than X, drop this test.
					donationfloor=60,		   #how many total donations per value does the test need?
					pmin=30,				   #the higher this number, the tighter the "% range" on the graph will be
					numdots=50,				   #how many dots per graph
					mask_fraction=1/15,        #used to see if a country should be put in the other category or not
					etc_country="other",	   #name for "other" country category
					unknown_country="unknown", #name for unknown countries
					cols = c('purple4', "orangered", "lightseagreen", "steelblue1", "slategrey"),
												#colors
					landing_perminthreshold=20, #test needs at least 1 minute with at least X impressions
					banner_perminthreshold=500,
					alpha = .05,
					beta = .2,
					xamounts =c(3,5,10,50),    #which values we should use for reportD
					col_amounts=c(1,3,5,10,15,20,25,30,50,100),
											   # which columns of amountsource to show
					col_other = 50,			   #'other' is > and < this
					paytypes=c("amazon", "cc", "paypal"),   # These payment types will be in ecom 		
					digitsround = 3 			# how many digits to round
					)


	if(nrow(clicks) == 0){
		report <- list(skip=TRUE, why=c(testid, toString(LBVCL$var[1]), "",country, language, 'no clicks'))
		reports <- list()
		reports[[1]] <- report

	}else{
		#assuming you've already taken care of language and country	
		if(isJustBannerTest(LBVCL)){
			type <- 'banner'
			imps <- banners
			LBVCL$landing <- NULL
		}
		else if(isJustLandingTest(LBVCL)){
			lic <- prepareLanding(LBVCL, landing, clicks)
			LBVCL <- lic$LBV
			imps <- lic$imps
			clicks <- lic$clicks
			type <- 'landing'			
		}
		else if(isValidComboTest(LBVCL)){
			#is combo test
			type <- 'combo'
			imps <- banners
		}else{
			type <- 'error'
		}

		if(type %in% c('error')){
			report <- c(list(skip=TRUE, why=c(testid, toString(LBVCL$var[1]), "",country, language, 'this should never happen. Neither just a landing nor banner test')))
			reports <- list()
			reports[[1]] <- report
		}else{
			reports <- doReport(imps, clicks, metatable, LBVCL, testname, testid, settings, country, language, write, type=type)			
		}
	}

	for(report in reports){
		if(!report$skip) {
			metatable <- report$metatable
			if(write){
				e <- saveReport(report, testid, testname, theseshots, errortable, settings)
				errortable <- e$errortable
			}
		}
		else if(report$skip){
			if(! ('writeTable' %in% names(report)) || report$writeTable){
				errortable <- addOrUpdateErrorTable(errortable, report$why)	
			}else{
				print("FYI:")
				print(report$why)
			}
			
		}
	}
	
	
	return(list(metatable=metatable, errortable=errortable))
}

onetestid <- function(t, metatable, errortable, write, con, bigmem, sample){
	print(t)
	if(bigmem | sample){
		c <- con$c
		b <- con$b
		l <- con$l

		c <- subset(c, test_id == t)
		b <- subset(b, test_id == t)
		l <- subset(l, test_id == t)
	}else{
		
		c <- dbGetQuery(con, paste0("SELECT * from clicks where test_id = '", t, "'"))
		b <- dbGetQuery(con, paste0("SELECT * from banners where test_id = '", t,"'"))
		l <- dbGetQuery(con, paste0("SELECT * from landings where test_id = '", t, "'"))
	}
	#some edge-case cleanup
	if(nrow(b) > 0){
		b[b == 'none'] <- NA	
		b[b == 'NULL'] <- NA
	}
	if(nrow(c) > 0){
		c[c == 'none'] <- NA	
		c[c == 'NULL'] <- NA
	}
	if(nrow(l) > 0){
		l[l == 'none'] <- NA	
		l[l == 'NULL'] <- NA
	}
	
	if(!(bigmem | sample)){
		dbDisconnect(con)
		
	}
	

	c$amount <- as.numeric(c$amount)
	c$amountsource <- as.numeric(c$amountsource)


	c$unixtime <- as.integer(c$unixtime)
	b$unixtime <- as.integer(b$unixtime)
	l$unixtime <- as.integer(l$unixtime)

	c$timestamp <- as.POSIXct(c$unixtime, origin="1970-01-01", tz="UTC")
	b$timestamp <- as.POSIXct(b$unixtime, origin="1970-01-01", tz="UTC")
	l$timestamp <- as.POSIXct(l$unixtime, origin="1970-01-01", tz="UTC")

	LBVVCL <- subset(TLBVVCL, test_id == t)
	if(nrow(LBVVCL) == 0){
		warning(paste("TEST", t, "not found."))
		return(list(metatable=metatable, errortable=errortable))
	}
	duplicates <- which(duplicated(LBVVCL))
	if(length(duplicates) > 0){
		LBVVCL <- LBVVCL[-duplicates,]
	}

	theseshots <- subset(screenshots, test_id == t)
	for(var in whichVariables(LBVVCL)){
		LBVCL <- subset(LBVVCL, variable == var)
		#urlvar <- unique(LBVCL$variable.for.url)[1]
		urlvar <- unique(LBVCL$variable)[1]
		thisc <- subset(c, test_id == t)
		thisb <- subset(b, test_id == t)
		if(nrow(l) > 0){
			thisl <- subset(l, test_id == t)	
		}else{
			thisl <- l
		}
		
		if(nrow(thisc) < 1 || nrow(thisb) < 1){
			errortable <- addOrUpdateErrorTable(errortable, c(t, var, "","YY", 'yy', 'no clicks (or possibly banners)'))
			next
		}
		#testname <- unique(thisb$test_name[1])
		#if(length(testname) > 30){
			testname <- t
			if(variable_in_testname){
				testname <- paste0(testname, urlvar)	
			}
			
			
		#}
		tables <- forCountryLanguage(thisc, thisb, thisl, splitOnCountry(LBVCL), splitOnLanguage(LBVCL), metatable, errortable, LBVCL, theseshots, t, testname, write)		
		metatable <- tables$metatable
		errortable <- tables$errortable
	}
	tables <- list(metatable=metatable, errortable=errortable)
	return(tables)
}

allIDs <-function(){return(unique(TLBVVCL$test_id))}

allreport <- function(testid=NA, tids=NA, write=FALSE, continue=FALSE, showerror=FALSE, bigmem=FALSE, sample=FALSE){
	if(bigmem){
		
		b <- read.delim("./data/banners.tsv", quote="", na.strings = "NULL", header=FALSE, stringsAsFactors=FALSE)
		c <- read.delim("./data/donors.tsv", quote="", na.strings = "NULL", header=FALSE, stringsAsFactors=FALSE)
		#l <- read.delim("./data/landing.tsv", quote="", na.strings = "NULL", header=F)	
		l <- b
		#^ dummy, will be discarded

		colnames(b) <- c('test_id', 'test_name', 'banner', 'unixtime', 'country', 'language', 'campaign', 'imps')
		colnames(c) <- c("contribution_id", 'test_id', 'test_name', 'banner', 'unixtime', 'timestamp', 'country', 'language', 'campaign', 'amount', 'paymenttype', 'amountsource', 'currency', 'landing')
		#colnames(l) <- c('test_id', 'test_name', 'banner', 'landing', 'unixtime', 'country', 'language', 'campaign')
		colnames(l) <- c('test_id', 'test_name', 'banner', 'unixtime', 'country', 'language', 'campaign', 'imps')
		#^ dummy, will be discarded
		con = list(c=c, b=b, l=l)
	}else if(sample){
		b <- read.delim("./sample/banners.tsv", quote="", na.strings = "NULL", header=FALSE, stringsAsFactors=FALSE)
		c <- read.delim("./sample/donors.tsv", quote="", na.strings = "NULL", header=FALSE, stringsAsFactors=FALSE)
		l <- b
		#^ dummy, will be discarded

		colnames(b) <- c('test_id', 'test_name', 'banner', 'unixtime', 'country', 'language', 'campaign', 'imps')
		colnames(c) <- c("contribution_id", 'test_id', 'test_name', 'banner', 'unixtime', 'timestamp', 'country', 'language', 'campaign', 'amount', 'paymenttype', 'amountsource', 'currency', 'landing')
		colnames(l) <- c('test_id', 'test_name', 'banner', 'unixtime', 'country', 'language', 'campaign', 'imps')
		#^ dummy, will be discarded
		con = list(c=c, b=b, l=l)
	}

	

	metatable <- genMetaTable()
	errortable <- genErrorTable()

	
	
	if(!is.na(testid)){
		if(continue){
			starthere <- which(tids == testid)
			tids <- tids[starthere:length(tids)]
		} else{
			tids <- c(testid)
		}
	}else{
		if(is.na(tids)){
			tids <- allIDs()
		}
	}

	
	
	for(t in tids){
		
		if(!(bigmem | sample)){
			
			if(isshadow | issample){
				drv <- dbDriver("SQLite") 
				con <- dbConnect(drv, "testingdb")
			}else{ 
				con <- dbConnect(MySQL(), dbname="fr_test")
			}
			on.exit(dbDisconnect(con))
		}
		if(showerror){
			tables <- onetestid(t, metatable, errortable, write, con, bigmem, sample)
			errortable <- tables$errortable
			metatable <- tables$metatable

		}else{
			result <- tryCatch({
				tables <- onetestid(t, metatable, errortable, write, con, bigmem, sample)
				#The call to a lower function!
				metatable<- tables$metatable
				errortable <- tables$errortable
			}, error = function(err){
				metatable<- tables$metatable
				errortable <- tables$errortable
				errortable <- addOrUpdateErrorTable(errortable, c(t, "unknown", "unknown", "unknown", "unknown", err[1]) )
				print('error')
			})
		}
		
	}
	
	return(list(metatable= metatable, errortable=errortable))
}

pfinder <- function(row){
	v1i <- as.numeric(row[2])
	v2i <- as.numeric(row[3])
	v1d <- as.numeric(row[4])
	v2d <- as.numeric(row[5])
	obs <- cbind(c(v1d, v1i), c(v2d, v2i))
	colnames(obs) <- c("A", "B")
	rownames(obs) <- c("Donations", "Impressions")
	test <- suppressWarnings(chisq.test(obs))
	return(as.numeric(test[3]))
}

z_value <- function(threshold, onesided=FALSE){
	denom <- 2
	if(onesided){
		denom <- 1
	}	
	return(qnorm(c(1-threshold/denom), lower.tail=TRUE))
}

fastABBA <- function(data, alpha, beta, roundby=3 ){
	alpha <- 1 - alpha
	beta <- 1 - beta
	#NEEEDED <- combine alpha and beta for an effective alpha.
	#replace 1.96 with the real zscore.
	

	#Data should be in the form: cbind(c(controlSuccess, controlTrials), c(varSuccess, varTrials))
	controlTrials <- data[2,1]
	varTrials <- data[2,2]
	controlSuccess <- data[1,1]
	varSuccess <- data[1,2]

	controlint <- binom.confint(controlSuccess, controlTrials, conf.level=alpha, methods="agresti-coull")
	controlmean <- controlint$mean
	controllower <- controlint$lower
	controlupper <- controlint$upper
	controln <- controlint$n

	#95% bound is 1.96 standard devations.
	controlsd <- (controlupper - controllower)/(2*1.96)

	####### Same deal, with variable instead of control this time
	varconfint <- binom.confint(varSuccess, varTrials, conf.level=alpha, methods="agresti-coull") 
	varmean <- varconfint$mean
	varlower <- varconfint$lower
	varupper <- varconfint$upper
	varn <- varconfint$n

	varsd <- (varupper - varlower)/(2*1.96)

	improvement <- function(controlsd, controlmean, varsd, varmean){
		newsd = sqrt((varsd * varsd) + (controlsd * controlsd))
		newmean = varmean - controlmean
		dist = qnorm(c(.025,.975) , mean=newmean, sd=newsd) #p = .05, two-tailed
		l = dist[1]
		u = dist[2]

		lowerboundrelativesuccess = l/controlmean
		upperboundrelativesuccess = u/controlmean
		return(list(upperbound=upperboundrelativesuccess, lowerbound=lowerboundrelativesuccess, mean=newmean, sd=newsd))
	}
	
	uplow <- improvement(controlsd, controlmean, varsd, varmean)
	lowerboundrelativesuccess <- uplow$lowerbound
	upperboundrelativesuccess <- uplow$upperbound
	newmean <- uplow$mean
	newsd <- uplow$sd
	#Not sure what this is. Copied blindly from ABBA documentation.
	
	impmean <- newmean / controlmean
	impsd <- newsd / controlmean

	power <- power.prop.test(p1=varSuccess/varTrials, p2=controlSuccess/controlTrials, n=(controlTrials+varTrials))$power
	#roundby = 4
	results <- c(paste("CONTROL: Success Rate:", round(controllower *100, digits=roundby), "% to", round(controlupper*100, digits=roundby), "% . Mean: ", round(controlmean*100, digits=roundby), "%") ,
	paste( "VARIABLE: Success Rate:", round(varlower*100, digits=roundby), "% to", round(varupper*100, digits=roundby), "%. Mean:", round(varmean*100, digits=roundby), "%" ) ,
	paste("VARIABLE: Relative Improvement: ", round(lowerboundrelativesuccess*100, digits=roundby), "% to ", round(upperboundrelativesuccess*100, digits=roundby), "%" ),
	paste("P:" , suppressWarnings(chisq.test(data))$p.value), paste("POWER: ", power)
	 )
 

	out <- list(implower=lowerboundrelativesuccess, impupper=upperboundrelativesuccess, impmean=impmean, impsd=impsd, p=suppressWarnings(chisq.test(data))$p.value, controllower=controllower, controlupper=controlupper, controlmean=controlmean, controlsd=controlsd, varlower=varlower, varupper=varupper, varmean=varmean, varsd=varsd, power=power)
	#Using chi-square test rather than whatever test ABBA uses for P. 
	return(list(data=out, text=results))
}



improvement <- function(controlsd, controlmean, varsd, varmean, alpha){
	
	lowbound <-  (alpha)/2
	highbound <- 1-alpha + lowbound

	newsd <- sqrt((varsd * varsd) + (controlsd * controlsd))
	newmean <- varmean - controlmean
	dist = qnorm(c(lowbound, highbound) , mean=newmean, sd=newsd) #p = .05, two-tailed
	l = dist[1]
	u = dist[2]

	lowerboundrelativesuccess = l/controlmean
	upperboundrelativesuccess = u/controlmean
	return(list(upperbound=upperboundrelativesuccess, lowerbound=lowerboundrelativesuccess, mean=newmean, sd=newsd))
}


ABBA2 <- function(data, roundby=3, alpha=.05, beta=.2){
	confidence <- 1 - alpha
	power <- 1 - beta
	#NEEEDED <- combine alpha and beta for an effective alpha.
	#replace 1.96 with the real zscore.
	

	#Data should be in the form: cbind(c(controlSuccess, controlTrials), c(varSuccess, varTrials))
	controlTrials <- data[2,1]
	varTrials <- data[2,2]
	controlSuccess <- data[1,1]
	varSuccess <- data[1,2]

	controlint <- binom.confint(controlSuccess, controlTrials, conf.level=confidence, methods="agresti-coull")
	controlmean <- controlint$mean
	controllower <- controlint$lower
	controlupper <- controlint$upper
	controln <- controlint$n

	z <- z_value(alpha)
	#95% bound is 1.96 standard devations.
	controlsd <- (controlupper - controllower)/(2*z)

	####### Same deal, with variable instead of control this time
	varconfint <- binom.confint(varSuccess, varTrials, conf.level=confidence, methods="agresti-coull") 
	varmean <- varconfint$mean
	varlower <- varconfint$lower
	varupper <- varconfint$upper
	varn <- varconfint$n

	varsd <- (varupper - varlower)/(2*z)

	
	
	uplow <- improvement(controlsd, controlmean, varsd, varmean, alpha)
	lowerboundrelativesuccess <- uplow$lowerbound
	upperboundrelativesuccess <- uplow$upperbound
	newmean <- uplow$mean
	newsd <- uplow$sd
	#Not sure what this is. Copied blindly from ABBA documentation.
	
	impmean <- newmean / controlmean
	impsd <- newsd / controlmean

	power <- power.prop.test(p1=varSuccess/varTrials, p2=controlSuccess/controlTrials, n=(controlTrials+varTrials), sig.level=alpha)$power
	#roundby = 4
	results <- c(paste("CONTROL: Success Rate:", round(controllower *100, digits=roundby), "% to", round(controlupper*100, digits=roundby), "% . Mean: ", round(controlmean*100, digits=roundby), "%") ,
	paste( "VARIABLE: Success Rate:", round(varlower*100, digits=roundby), "% to", round(varupper*100, digits=roundby), "%. Mean:", round(varmean*100, digits=roundby), "%" ) ,
	paste("VARIABLE: Relative Improvement: ", round(lowerboundrelativesuccess*100, digits=roundby), "% to ", round(upperboundrelativesuccess*100, digits=roundby), "%" ),
	paste("P:" , suppressWarnings(chisq.test(data))$p.value), paste("POWER: ", power)
	 )
 

	out <- list(implower=lowerboundrelativesuccess, impupper=upperboundrelativesuccess, impmean=impmean, impsd=impsd, p=suppressWarnings(chisq.test(data))$p.value, controllower=controllower, controlupper=controlupper, controlmean=controlmean, controlsd=controlsd, varlower=varlower, varupper=varupper, varmean=varmean, varsd=varsd, power=power)
	#Using chi-square test rather than whatever test ABBA uses for P. 
	return(list(data=out, text=results))
}

	 
datamaker <- function(donor, banner){

    #maxtime <- max(donor$minute)
    #banner1 <- subset(banner, minute <= maxtime)
    #^ This allows us to merge all. But now there's the problem where we have donations in times where we hae no banner impressions. 
    
    #In which case, truncate donors until there are banner impressions again.
    #mintime <- min(banner1$minute)
    #maxtime <- max(banner1$minute)
    #donor1 <- subset(donor, minute <= maxtime & minute >= mintime)
    
	donor1 <- donor
	banner1 <- banner
	
    donor3 <- aggregate(amount ~ minute * variable, donor1, length)
    banner3 <- aggregate(imps ~ minute * variable, banner1, sum)
    
    colnames(donor3) = c("minute", "v", "donations")
    colnames(banner3) = c("minute", "v", "imps")
    
    donor4 <- cast(melt(donor3, id=c('minute', "v")) , minute ~ v + variable)
    refinebanner2 <- cast(melt(banner3, id=c('minute', "v")) , minute ~ v + variable)
	
	
    mergeall <- merge(donor4, refinebanner2, all=TRUE)
    mergeall[is.na(mergeall)] <- 0	
    
   
	
  	controlname <- levels(factor(donor$variable))[1]
    variablename <- levels(factor(donor$variable))[2]
    
	#Now let's just clean up mergeall a bit
	
	
    ci <- paste(controlname,"_imps" ,sep="")
    vi <- paste(variablename,"_imps" ,sep="")
    cd <- paste(controlname,"_donations" ,sep="")
    vd <- paste(variablename,"_donations" ,sep="")
    
	
	cdpos <- which(colnames(mergeall) == cd)[1]
	cipos <- which(colnames(mergeall) == ci)[1]
	vdpos <- which(colnames(mergeall) == vd)[1]
	vipos <- which(colnames(mergeall) == vi)[1]
	
	colnames(mergeall)[cdpos] <- 'Control_donations'
	colnames(mergeall)[vdpos] <- 'Variable_donations'
	colnames(mergeall)[cipos] <- 'Control_imps'
	colnames(mergeall)[vipos] <- 'Variable_imps'

	mergeall <- mergeall[c('minute', 'Control_imps', 'Variable_imps', "Control_donations", "Variable_donations")]
	mergeallCUM <- mergeall	
	
	cdpos <- which(colnames(mergeallCUM) == cd)[1]
	cipos <- which(colnames(mergeallCUM) == ci)[1]
	vdpos <- which(colnames(mergeallCUM) == vd)[1]
	vipos <- which(colnames(mergeallCUM) == vi)[1]

    mergeallCUM$Control_imps <- cumsum(mergeallCUM$Control_imps)
    mergeallCUM$Variable_imps <- cumsum(mergeallCUM$Variable_imps)
    mergeallCUM$Variable_donations <- cumsum(mergeallCUM$Variable_donations)
    mergeallCUM$Control_donations <- cumsum(mergeallCUM$Control_donations)
    mergeallCUM <- mergeallCUM[c('minute', 'Control_imps', 'Variable_imps', "Control_donations", "Variable_donations")]
    lastrow <- mergeallCUM[nrow(mergeallCUM),]
    
    if( #if control does better than variable, switch control and variable. 
        (lastrow$Control_donations / lastrow$Control_imps) > (lastrow$Variable_donations / lastrow$Variable_imps)  ){
        mergeallCUM <- mergeallCUM[c('minute', 'Variable_imps', 'Control_imps', "Variable_donations", "Control_donations")]
        colnames(mergeallCUM) <- c('minute', 'Control_imps', 'Variable_imps', "Control_donations", "Variable_donations")
		
		mergeall <- mergeall[c('minute', 'Variable_imps', 'Control_imps', "Variable_donations", "Control_donations")]
		colnames(mergeall) <- c('minute', 'Control_imps', 'Variable_imps', "Control_donations", "Variable_donations")
		
        controlname <- levels(factor(donor$variable))[2]
        variablename <- levels(factor(donor$variable))[1]
    }
    
    return(list(data=mergeall, cumdata=mergeallCUM, control=controlname, variable=variablename))
}

equal_banner_cumulizer <- function(data, settings){
	#takes in minute-by-minute formatted data, and returns it formatted as dataCUM-style data.
	#BUT! This data assumes that banner impressions are exactly the same for each banner. 
	#We do this by having control_imps and variable_imps always equal the same for each minute,

	alpha <- settings$alpha
	beta <- settings$beta

	mergeallCUM <- data
	totalImps  <- cumsum(mergeallCUM$Control_imps) + cumsum(mergeallCUM$Variable_imps)
	avgImps <- totalImps / 2
	mergeallCUM$Control_imps <- avgImps
    mergeallCUM$Variable_imps <- avgImps

    mergeallCUM$Variable_donations <- cumsum(mergeallCUM$Variable_donations)
    mergeallCUM$Control_donations <- cumsum(mergeallCUM$Control_donations)
    mergeallCUM <- mergeallCUM[c('minute', 'Control_imps', 'Variable_imps', "Control_donations", "Variable_donations")]

	if(! isEnriched(mergeallCUM)){ mergeallCUM <-  enrichCData(mergeallCUM, alpha, beta)}

    return(mergeallCUM)
}

setNindata <- function(cumdata, alpha=.05, beta=.2){
	power = 1 - beta
    rf <- function(row){
        p1 = as.numeric(row[4]) / as.numeric(row[2])
        p2 = as.numeric(row[5]) / as.numeric(row[3])
        toreturn <- tryCatch(
            power.prop.test(p1=p1, p2=p2, power=power, sig.level=alpha)$n,
            error=function(e) {return(-1)},
            finally={}
        )
        return(toreturn)
    }
    return(apply(cumdata,1,rf))
}


isEnriched <- function(cumdata){
	return(all(c("impmean", "implower", "impupper", "n", "p") %in% names(cumdata)))
}


rangecalc <- function (data,alpha, beta){
	rf <- function(row){
		c_t <- as.numeric(row[2]) #control_trials
		v_t <- as.numeric(row[3]) #variable_trials
		c_s  <- as.numeric(row[4]) #control_success
		v_s  <- as.numeric(row[5])

		tmp <- cbind(c(c_s, c_t), c(v_s, v_t))
		if(c_s > c_t | v_s>v_t){
			return(c(0,0,0,0))
		}
		tmp <- ABBA2(tmp, alpha, beta)$data
		return(c(tmp$impmean, tmp$implower, tmp$impupper, tmp$power))
	}

	tmpdata <- apply(data, 1, rf)
	tmpdata <- t(tmpdata)
	data["implower"] <- tmpdata[,2]
	data["impmean"] <- tmpdata[,1] 
	data["impupper"] <- tmpdata[,3]
	data["power"] <- tmpdata[,4]	
		
	return(data)
}



enrichCData <- function(cumdata, alpha, beta){
	cumdata <- rangecalc(cumdata, alpha, beta)
	cumdata['n'] <- ceiling(setNindata(cumdata, alpha, beta))
	cumdata['p'] <- apply(cumdata, 1, pfinder)
	
	return(cumdata)
}


newgrapher <- function(cumdata, settings, timespan=NA, finalimp="none", ylimit=c(-.5,1.1), name="",controlname="B", variablename="A", extrasub=FALSE, xaxisistime=FALSE){
	#takes in cumulative data. 
	#finalimp needs to be in "1.XX" form
	#pmin aka plimit is the number of rows that p < .05 that you skip before changing the yscale for percentages. A bigger number means a tighter range. Unless the number is > the number of rows that p < .05, in which case it is ignored. 
	alpha <- settings$alpha
	beta <- settings$beta
	cols <- settings$cols
	if(! isEnriched(cumdata)) {cumdata <- enrichCData(cumdata, alpha, beta)}
	    
	if(!is.na(timespan)){
		start <- head(cumdata,1)$minute
		end <- start + timespan
		cumdata <- subset(cumdata, minute < end)
	}

	finalrow <- cumdata[nrow(cumdata),]
	finalmean <- finalrow$impmean
	
	past15 <- subset(cumdata,Control_donations > 15 & Variable_donations > 15)
	fifteentime <- head(past15,1)
	if(xaxisistime){
		fifteentime$minute
	}else{
		fifteentime <- fifteentime$Control_imps + fifteentime$Variable_imps	
	}
	

	
	sizefactor <- 10 #<- the order of magnitude we want to see
	uppermax = ceiling(max(past15$impupper)*100)/100
	uppermin = floor(min(past15$implower)*100)/100

	scalefactor <- round((uppermax + abs(uppermin)) * sizefactor * 10/5)* 5 /10
	#scalefactor2 <- round(abs(uppermin) * sizefactor * 10/5)* 5 /10
	#scalefactor <- max(scalefactor1, scalefactor2)
	
	myyscale.component <- function(...) 
	{ 
	  ans <- yscale.components.default(...) 
	  ans$right <- ans$left 
	  foo <- ans$right$labels$at 
	  ans$right$labels$labels <- paste(as.character(scalefactor * sizefactor * foo),"%",sep="")
	  ans 
	} 
	
	if(!is.na(ylimit) & (ylimit=="none" | ylimit=="default" )){
		ylimit = c(-.5,1.1 )
	}
	
	
	title <- paste(name, "over time.")
	sub <- paste("95% range at end: ", round(finalrow$implower * 100, 1), "% - ", round(finalrow$impupper * 100, 1), "%. Mean: ", round(finalmean * 100, 1), "%. \n ", sep="")
	sub <- paste(sub , "Total banner impressions: ", (finalrow$Control_imps + finalrow$Variable_imps), "\n", sep="")
	#sub <- paste(sub, "power at end: ", signif(finalrow$power,2))
	if(extrasub != FALSE){
		sub <- paste0(sub, "\n", extrasub, "\n")
	}
	#if(finalrow$implower > 0){
	#	title <- paste0(title, variablename)
	#}else if (finalrow$impupper < 0){
	#	title <- paste0(title, controlname)
	#}else{
		title <- paste(title, variablename, "is winning")
	#}
	
	linenames <- c("Upper bound of winning margin","P-value over time", "lower bound of winning margin", "Winning margin at end of sample")
	if(finalimp != "none"){
		linenames <- c(linenames, "'True' winning margin from full data set")		
		sub <- paste(sub, "'True' margin: ", round(finalimp * 100, 1), "%", sep="")
	}
	
	
	if(xaxisistime){
		graphthis <- xyplot( impupper*(sizefactor / scalefactor) + p + implower*(sizefactor / scalefactor) ~ minute, 
	        data=cumdata, 
			auto.key=list(text=linenames,
			space = "bottom", col=cols, points=FALSE), 
			xlab=list(cex=2,label='Time'), 
			ylab=list(cex=1.5,label=paste('p-value (', cols[2], ")", sep=""), vjust=1),
			ylab.right = list(cex=1.5,label="'Winning' banner's relative success", vjust=-2),
			main=list(cex=2,label=title), 
			xlab.top=list(cex=2,label=sub),
			ylim=ylimit, 
			lwd=1.5,
			col=cols,
			type="l",
		    scales=list( 
		        x=list(alternating=FALSE), 
		        y=list(relation="free", rot=0),
		        cex=1.5), 
			yscale.component=myyscale.component, 
			par.settings=list(layout.widths=list(right.padding=6)),    
		)

		}else{
			graphthis <- xyplot( impupper*(sizefactor / scalefactor) + p + implower*(sizefactor / scalefactor) ~ (Control_imps + Variable_imps), 
		        data=cumdata, 
				auto.key=list(text=linenames,
				space = "bottom", col=cols, points=FALSE), 
				xlab=list(cex=2,label='Total Banner Impressions'), 
				ylab=list(cex=1.5,label=paste('p-value (', cols[2], ")", sep=""), vjust=1),
				ylab.right = list(cex=1.5,label="'Winning' banner's relative success", vjust=-2),
				main=list(cex=2,label=title), 
				xlab.top=list(cex=2,label=sub),
				ylim=ylimit, 
				lwd=1.5,
				col=cols,
				type="l",
			    scales=list( 
			        x=list(alternating=FALSE), 
			        y=list(relation="free", rot=0),
			        cex=1.5), 
				yscale.component=myyscale.component, 
				par.settings=list(layout.widths=list(right.padding=6)),    
			)
		}
	

	graphthis <- graphthis  + layer(
			panel.abline(
				h=finalmean*(sizefactor/scalefactor), 
				col=color, lty="dotted", lwd=3),
			data=list(scalefactor=scalefactor, sizefactor=sizefactor, finalmean=finalmean, color=cols[4])
	)
	
	#if(ptime >=0){
	#	graphthis <- graphthis + layer(panel.abline(lty="dotted", col = color,  v=vee), data=list(vee=ptime, color=cols[2]))
	#}
	
	if(finalimp != "none"){
		realfinal <- finalimp *(sizefactor/scalefactor)
		graphthis <- graphthis + layer(panel.abline(lwd=3,lty="dotted", col = color,  h=realfinal), data=list(realfinal=realfinal, color= cols[5]))
	}
	graphthis <- graphthis + layer(panel.abline(lwd=3,lty="solid", col = color,  h=0), data=list(color=cols[5]))
	graphthis <- graphthis + layer(panel.abline(lwd=3,lty="solid", col = color,  v=0), data=list(color=cols[5]))
	graphthis <- graphthis + layer(panel.abline(lwd=3,lty="dotted", col = color,  h=.05), data=list(color=cols[2]))
	graphthis <- graphthis + layer(panel.abline(lwd=3,lty="solid", col = color,  v=imps), data=list(color=cols[4],imps=fifteentime))
	return(graphthis) 
}



#Begin cleandata subfunctions;
prepare <- function(imps, clicks, BV, testid){
	striplanguage <- function(df){
		df$language <- substr(df$language, 1, 2)
		return(df)
	}
	
	imps <- subset(imps, test_id == testid)
	clicks <-  subset(clicks, test_id == testid)
	
	if(nrow(imps) == 0){
		return(list(skip=TRUE, why=paste("No impressions", testid), writeTable=FALSE))
	}
	if(nrow(clicks) == 0){
		return(list(skip=TRUE, why=paste("No clicks", testid), writeTable=FALSE))
	}
	
	if(isbannernameException(testid, imps, clicks)){
		impbanner <- sort(as.vector(unique(imps$banner)))
		clickbanner <- sort(as.vector(unique(clicks$banner)))
		
		ic <- dobannernameException(testid, impbanner, clickbanner, imps, clicks)
		imps <- ic$imp
		clicks <- ic$click
	}
	
	imps <- striplanguage(imps)
	clicks <- striplanguage(clicks)
	for(b in unique(BV$banner)){
		if(is.na(b)){
			next
		} # V case insensitive banner names
		if(sum(toupper(b) == toupper(subset(clicks, amount > 0)$banner)) <1){
			#Zero donations for this banner.
			#print(testid)
			return(list(skip=TRUE, why=paste0("no donations for: ", b), writeTable=FALSE ))
		
		}
	}

	imps$banner <- factor(imps$banner)
	clicks$banner <- factor(clicks$banner)

	imps <- imps[order(imps$timestamp), ]
	clicks <- clicks[order(clicks$timestamp),]

	imps$id <- 1:nrow(imps)
	clicks$id <- 1:nrow(clicks)
	imps$val <- NA
	clicks$val <- NA
	BV$banner <- factor(BV$banner)
	
	return(list(imps=imps, clicks=clicks, BV=BV, skip=FALSE))
}

destroySmallDefects <- function(testid, icb, settings){
	#if there isn't at least 1 minute with at least <perminthreshold> impressions, then drop this test.
	#if the total impressions are less than <totalthreshold>, drop this test.
	#if the total donations are less than <donationfloor>, drop this test
	imps <- icb$imps
	clicks <- icb$clicks
	BV <- icb$BV
	
	perminthreshold <- settings$perminthreshold
	totalthreshold <- settings$total_threshold
	allowedtodrop <- settings$allowedtodrop
	threshold <- settings$threshold
	donationfloor <- settings$donationfloor	

	BVbanner <- sort(as.vector(unique(BV$banner)))
	impbanner <- sort(as.vector(unique(imps$banner)))
	clickbanner <- sort(as.vector(unique(clicks$banner)))
	
	bannerReplace <- function(from, to, df){
		df$banner <- as.character(df$banner)
		sub <- df[which(df$banner == from),]
		if(nrow(sub) == 0) return(df)
			
		df[which(df$banner == from),]$banner <- to
		df$banner <- factor(df$banner)
		return(df)
	}
	
	infiniteProtect <- 20
	checkReplaceOrSkipBanner <- function(Banner, df){
		num <- sum(df$banner == Banner) 
		#NOTE! The allowedtodrop number has been raised to A GAJILLION. So they'll always be dropped.
		if(!Banner %in% BVbanner){
			if(tolower(Banner) %in% tolower(BVbanner)){
				#figure out which
				thisone <- BVbanner[which(tolower(Banner) == tolower(BVbanner))]
				df <- bannerReplace(Banner, thisone, df)
			}else if(!is.na(Banner) & num <= allowedtodrop){
				dropthese = which(df$banner == Banner)
				df <- df[ -dropthese,]
				df <- droplevels(df)
				df$id <- 1:nrow(df)
			}else{
				return(list(skip=TRUE, why="num banners/landing don't match BVV", writeTable=TRUE ))
			}
		}
		return(df)
	}
	for( x in impbanner){
		if(! x %in% BVbanner){
			imps <- checkReplaceOrSkipBanner(x, imps)
			if("skip" %in% names(imps)) return(imps)
			impbanner <- sort(as.vector(unique(imps$banner)))
		}
	}
	for( x in clickbanner){
		if(! x %in% BVbanner){
			clicks <- checkReplaceOrSkipBanner(x, clicks)
			if("skip" %in% names(clicks)) return(clicks)
			clickbanner <- sort(as.vector(unique(clicks$banner)))	
		}
	}

	if(nrow(subset(imps, imps > perminthreshold)) < 1 || (sum(imps$imps) < totalthreshold)){
		return(list(skip=TRUE, why="few total impressions", writeTable=FALSE))
	}
	donations <- subset(clicks, amount > 0)
	if(nrow(donations) < donationfloor){
		return(list(skip=TRUE, why=paste("total donations less than", donationfloor), writeTable=FALSE))
	}
	return(list(skip=FALSE, imps=imps, clicks=clicks, BV=BV))
}

standardizeToBV <- function(icb, country, language){
	imps <- icb$imps
	clicks <- icb$clicks
	BV <- icb$BV
	
	BVbanner <- sort(as.vector(tolower(unique(BV$banner))))
	impbanner <- sort(as.vector(tolower(unique(imps$banner))))
	clickbanner <- sort(as.vector(tolower(unique(clicks$banner))))
	
	infiniteProtect <- 15
	#This WILL cause an infinite loop if you're not careful
	#IF some banners are is not in BV		
	while(	!all( BVbanner==clickbanner ) | !all(BVbanner == impbanner)){
		#drop those banner
		infiniteProtect <- infiniteProtect - 1
		#print(infiniteProtect)
		if(infiniteProtect < 0){
			return(list(skip=TRUE, why=paste("infinite loop", testid), writeTable=TRUE ))
		}
	
		#CLICK
		firstwrong <- which(BVbanner != clickbanner)[1]
		firstwrong <- clickbanner[firstwrong]
		if(is.na(firstwrong)){
			return(list(skip=TRUE, why="banners don't match BVV", writeTable=TRUE))
		}else{
			#drop 
			dropthese <- which(clicks$banner == firstwrong)
			clicks <- clicks[ -dropthese,]
			clicks <- droplevels(clicks)
			clickbanner <- sort(as.vector(unique(clicks$banner)))
			clicks$id <- 1:nrow(clicks)					
		}

		#IMP
		firstwrong <- which(BVbanner != impbanner)[1]
		firstwrong <- impbanner[firstwrong]
	
		if(!is.na(firstwrong) ){
			dropthese <- which(imps$banner == firstwrong)
			imps <- imps[ -dropthese,]
			imps <- droplevels(imps)
			impbanner <-  sort(as.vector(unique(imps$banner)))
			imps$id <- 1:nrow(imps)		
		}
		
	}
	

	for(i in 1:nrow(BV)){
		b <- toString(BV[i,]$banner)
		value <- toString(BV[i,]$value)
		idstoreplace <- subset(imps, banner == b)$id
		imps[idstoreplace,]$val <- value
		idstoreplace <- subset(clicks, banner == b)$id
		clicks[idstoreplace,]$val <- value
	}

	return(list(skip=FALSE, imps=imps, clicks=clicks, BV=BV))
}

mask_some_countries <- function(icb, settings){
	#import relevant settings
	fraction <- settings$mask_fraction
	other <- settings$etc_country
	unknown <- settings$unknown_country
	#import relevant data sets
	imps <- icb$imps
	clicks <- icb$clicks
	BV <- icb$BV
	#booleans:
	clicks_country_is_unknown <- is.na(unique(clicks$country)[1])
	imps_country_is_unknown <- is.na(unique(imps$country)[1])
	
	

	if(clicks_country_is_unknown){
		if(imps_country_is_unknown){
			imps$country <- unknown
			clicks$country <- unknown
		}else if(length(unique(imps$country))==1){
			#if there's exactly 1 country in imps
			clicks$country <- unique(imps$country)[1]
		}else{
			clicks$country <- unknown
		}
	}
	imps_by_country <- aggregate(imps ~ country, imps, sum)
	clicks_by_country <- aggregate(amount ~ country, clicks, length)
	names(clicks_by_country) <- c('country', 'clicks')
	
	country_list <- union(imps$country, clicks$country)
	

	total_imps <- sum(imps$imps)
	total_clicks <- nrow(clicks)

	imps_by_country <- imps_by_country[order(-imps_by_country$imps),]
	clicks_by_country <- clicks_by_country[order(-clicks_by_country$clicks),]
	#Now we have sorted the countries in imps and clicks. 
	#we need a rule: each country needs to have at least 10% of the clicks and 10% of the imps to be considered major. Otherwise, it's "etc" or "other"
	
	i_countries <- subset(imps_by_country, imps > fraction * total_imps)$country
	c_countries <- subset(clicks_by_country, clicks > fraction * total_clicks)$country
	if(clicks_country_is_unknown & imps_country_is_unknown){
		show_countries <- c(unknown)
	}else if(clicks_country_is_unknown){
		show_countries <- c(i_countries, unknown)
	}else if(imps_country_is_unknown){
		show_countries <- c(c_countries, unknown)
	}else{
		show_countries <- intersect(i_countries, c_countries)	
	}
	
	hide_countries <- setdiff(country_list, show_countries)

	for(thiscountry in hide_countries){
		theseimps <- imps[which(imps$country == thiscountry),]
		if(nrow(theseimps) > 0){
			imps[which(imps$country == thiscountry),]$country <- other
		}
		theseclicks <- clicks[which(clicks$country == thiscountry),]
		if(nrow(theseclicks) > 0){
			clicks[which(clicks$country == thiscountry),]$country <- other	
		}
	}

	#make sure that the other bucket is big enough:

	return(list(skip=FALSE, imps=imps, clicks=clicks, BV=BV))
}
#End cleandata subfunctions


drop_tiny_other <- function(imps_or_clicks, settings){
	fraction <- settings$mask_fraction
	other <- settings$etc_country
	#given imps, clicks, or donations, you might drop the "other" country if it's size is too small.
	data <- imps_or_clicks
	if("imps" %in% names(data)){
		imps <- data
		total <- sum(data$imps)
		if(sum(imps[which(imps$country == "other"),]$imps) < fraction*total){
			imps <- imps[which(imps$country != "other"),]
		}
		return(imps)
	}else if('amount' %in% names(data)){
		#not sure if this is clicks or donations. Treat them similarly.
		#therefore - cd
		cd <- data
		total <- nrow(cd)
		if(nrow(cd[which(cd$country == other), ]) < fraction * total){
			cd <- cd[which(cd$country != other),]
		}
		return(cd)
	}
	#else{
	return(data)
	
	#this should never happen
}



onelineResult <- function(name, clicks, donations, banners, settings){
	totalamount <- sum(donations$amount)
	totaldonations <- nrow(donations)
	totalclicks <- nrow(clicks)
	totalimpressions <- sum(banners$imps)
	donationsPer1000BI <- 1000* totaldonations/totalimpressions
	dollarsPer1000BI <-  round(1000* totalamount / totalimpressions, digits=2)
	a <- donations$amount
	a20 <- ifelse(a > 20, 20, a)
	amount20 <- (sum(a20) / totalimpressions) * 1000
	rm(a)
	avgDonation <- totalamount / totaldonations
	median <- median(donations$amount)
	max <- max(donations$amount)
	avg20 <- (amount20 / totaldonations ) * (totalimpressions / 1000) 
	amount20 <- round(amount20, digits=2)
	conversionrate <- totaldonations / totalclicks
	find_mode <- function(x){
		ux <- unique(x)
	 	ux <- ux[which.max(tabulate(match(x, ux)))]	
	}
	mode_a <- find_mode(donations$amount)
	mode_as <- find_mode(donations$amountsource)

	paytypes <- settings$paytypes
	rrpaytypes <- paste0("rr", paytypes)
	conversion = list()
	for(i in 1:length(paytypes)){
		numclicks <- nrow(subset(clicks, paymenttype==paytypes[i] | paymenttype==rrpaytypes[i]))
		numdonations <- nrow(subset(donations, paymenttype==paytypes[i] | paymenttype==rrpaytypes[i]))
		rate <-round(numdonations/numclicks, digits=4)
		conversion[[paytypes[i]]] <- rate
	}

	#conversionF <- paymentInsert(donations, clicks)
	#conversionF <- conversionF[order(conversionF$donations, decreasing=TRUE),]
	#conversionF <- conversionF[1:settings$numpayments,]
	#rotated <- data.frame(t(conversionF[c("name", "conversion")]))
	#l2 <- list()
	#for(i in 1:length(rotated)){
	#	payment_name <- paste0(as.character(rotated[1,i]), "pct")
	#	conversion_value <- round(as.numeric(as.character(rotated[2,i])), digits=3)
	#	l2[[payment_name]] <- conversion_value
	#}

	line <- data.frame(name=name,donations=totaldonations, clicks=totalclicks, impressions=totalimpressions, donationsPer1000BI=donationsPer1000BI, dollarsPer1000BI=dollarsPer1000BI, amount=totalamount, amount20=amount20, avgDonation=avgDonation,  avg20=avg20, median=median, max=max, conversionrate=conversionrate, mode=mode_a, mode_s=mode_as)
	line <- merge(line, conversion)
	return(line)
}

paymentRow <- function(type, donations, clicks){
	name <- type
	donations <- subset(donations, paymenttype==type)
	clicks <- subset(clicks, paymenttype==type)
	numdonations <- nrow(donations)
	numclicks <- nrow(clicks)
	conversion <- numdonations / numclicks
	amt <- sum(donations$amount)
	avg <- amt / numdonations

	line <- data.frame(name=name, donations=numdonations, clicks=numclicks, conversion=conversion, avg=avg, amount=amt)
	return(line)
}

topFrame_bottom <- function(topFrame){
	#find the delta for each column in the topFrame.
	topFrame[1] <- lapply(topFrame[1], as.character)
	row <- c("Absolute change:")
	for(i in 2:length(topFrame)){
		delta <- topFrame[1,i] - topFrame[2,i]
		row <- c(row, as.numeric(delta))
	}
	topFrame <- rbind(topFrame, row)
	return(topFrame)
}


amountXtable <- function(name, banners, donations, settings){
	Xamounts <- settings$xamounts
	colnames <- c('name')
	#table <- data.frame('banner'=character(), stringsAsFactors=FALSE)
	#bannernames <- unique(donations$banner)
	for(x in Xamounts){
	#	table[paste0("amount",x)] <- numeric()
	#	table[paste0('avg', x)] <- numeric()
		colnames <- cbind(colnames,paste0("amount",x,"/1000bi"), paste0('avg', x) )
	}
	
	row <- c(name)
	for(X in Xamounts){
		totaldonations <- nrow(donations)
		totalimpressions <- sum(banners$imps)
		a <- donations$amount			
		aX <- ifelse(a > X, X, a)
		amountX <- (sum(aX) / totalimpressions) * 1000
		avgX <- sum(aX) / totaldonations
		amountX <- round(amountX, digits=2)
		avgX <- round(avgX, digits=2)
		row <- cbind(row, amountX)
		row <- cbind(row, avgX)
	}
	table <- data.frame(row, row.names=NULL, stringsAsFactors=FALSE)
	colnames(table) <- colnames
	return(table)
}


amount_dollars_shift <- function(donations, settings, agg=NA, absolute=FALSE){
	
	showamounts <- settings$col_amounts
	showother <- settings$col_other

	
	suppressWarnings(if(is.na(agg)){
		agg_country <- amount_sum_dist_crunch(donations, settings)	
		agg <- agg_country$agg
	})

	tables <- list()
	values <- unique(agg$val)
	values <- sort(values)
	for(v in values){
		table <- data.frame(amountsource=character(), change=numeric(), stringsAsFactors=FALSE, row.names=NULL)
		for(amntsrc in unique(agg$amountsource)){
			look <- subset(agg, amountsource == amntsrc)
			thisval <- subset(look, val == v)$amount
			thatval <- subset(look, val != v)$amount
			
			thisval <- if(!suppressWarnings(any(thisval))) 0 else thisval
			thatval <- if(!suppressWarnings(any(thatval))) 0 else thatval

			if(absolute){
				delta <- thisval - thatval
			}else{
				delta <- ((thisval / thatval) - 1) * 100		
			}
			
			row <- cbind(amntsrc, delta)
			colnames(row) <- c("amountsource", "change")
			table <- rbind(table, row)
		}
		colnames(table) <- c("amountsource", paste0( v, " improvement (dollars)"))
		tables[[v]] <- table
	}
	return(tables)

}

amountshift <- function(donations, settings, agg=NA, absolute=FALSE){
	showamounts <- settings$col_amounts
	showother <- settings$col_other

	
	suppressWarnings(if(is.na(agg)){
		agg <- amount_dist_crunch(donations, settings)	
	})

	tables <- list()
	values <- unique(agg$val)
	values <- sort(values)
	for(v in values){
		table <- data.frame(freq=character(), change=numeric(), stringsAsFactors=FALSE, row.names=NULL)
		for(amntsrc in unique(agg$amountsource)){
			look <- subset(agg, amountsource == amntsrc)
			thisval <- subset(look, val == v)$freq
			thatval <- subset(look, val != v)$freq
			thisval <- if(!any(thisval)) 0 else thisval
			thatval <- if(!any(thatval)) 0 else thatval
			if(absolute){
				delta <- thisval - thatval
			}else{
				delta <- ((thisval / thatval) - 1) * 100		
			}
			row <- cbind(amntsrc, delta)
			colnames(row) <- c("amountsource", "change")
			table <- rbind(table, row)
		}
		colnames(table) <- c("amountsource", paste0( v, "'s improvement (donations)"))
		tables[[v]] <- table
	}
	return(tables)

	
}


AvBline <- function(twolines, donations, dollardata, settings){
	alpha <- settings$alpha
	beta <- settings$beta
	winner <- twolines$winner
	loser <- twolines$loser
	roundby <- settings$digitsround

	winnerAmnts <- as.numeric(subset(donations, val==as.character(winner$name))$amountsource)
	loserAmnts <- as.numeric(subset(donations, val!=as.character(winner$name))$amountsource)
	#wilcoxp <- wilcox.test(winnerAmnts, loserAmnts)$p.value
	total_impressions <- 100 * (twolines$winner$impressions - twolines$loser$impressions) / twolines$loser$impressions

	percentify <- function(A){
		return((A - 1) * 100)
	}
	pAmountPerBI <- percentify(winner$dollarsPer1000BI/ loser$dollarsPer1000BI)
	pdonationsPerBI <- percentify(winner$donationsPer1000BI / loser$donationsPer1000BI)
	#tDollars <- winner$amount - loser$amount
	#tDonations <- winner$donations - loser$donations
	#replace with:
	# increased dollar per 1000 bi
	# increased donation per 1000 bi
	iDollarP1000bi <- winner$dollarsPer1000BI - loser$dollarsPer1000BI
	iDonationsP1000bi <- winner$donationsPer1000BI - loser$donationsPer1000BI
	#pImps <- percentify(winner$impressions / loser$impressions)
	#tImps <- winner$impressions - loser$impressions
	a20diff <- winner$amount20 - loser$amount20
	
	#toAbba = cbind(c(controlSuccess, controlTrials), c(varSuccess, varTrials))
	binomdata <- cbind( c(loser$donations, loser$impressions), c(winner$donations, winner$impressions))
	if(binomdata[1,1] > binomdata[2,1] | binomdata[1,2] > binomdata[2,2]){
		return(list(skip=TRUE, why="More donations than impressions. IMPOSSIBLE"))
	}
	bdata <- ABBA2(binomdata, alpha, beta, roundby=5)$data
	p <- bdata$p
	if(p > .01){
		p <- round(p, digits=2)
	}
	#out = list(implower=lowerboundrelativesuccess, impupper=upperboundrelativesuccess, impmean=impmean, impsd=impsd, p=chisq.test(data)$p.value, controllower=controllower, controlupper=controlupper, controlmean=controlmean, controlsd=controlsd, varlower=varlower, varupper=varupper, varmean=varmean, varsd=varsd)
	
	dollarlower <- signif(dollardata$dollarlowerpct, roundby)
	dollarupper <- signif(dollardata$dollarupperpct, roundby)
	line <- data.frame('winner'= as.character(winner$name), 
		pDonationsPerBI=pdonationsPerBI, iDonations1000=iDonationsP1000bi,
		pDollarsPerBI=pAmountPerBI, iDollars1000=iDollarP1000bi,
		total_impressions=total_impressions,
		#'pBannerImpressions'=pImps, 'deltaBannerImpressions'=tImps,
		 a20diff= a20diff, p=p, power=bdata$power, lower9580=bdata$implower, upper9580=bdata$impupper, 
		 dollarlower=dollarlower, dollarupper=dollarupper,
		 #wilcoxp=wilcoxp, 
		 stringsAsFactors=FALSE)
	return(list(line=line, skip=FALSE))
}

graphreports <- function(cleaneddata, clicks, imps, settings, testname="test", type='banner', multiple=multiple){
	controlname <- cleaneddata$control
	variablename <- cleaneddata$variable
	data <- cleaneddata$data
	dataCUM <- cleaneddata$cumdata
	path <- findmakepath("report", testname, multiple=multiple)
	alpha <- settings$alpha
	beta <- settings$beta
	
	country_clicks <- drop_tiny_other(clicks, settings)
	country_imps <- drop_tiny_other(imps, settings)

	break_out_by_country <- length(setdiff(union(unique(country_clicks$country), unique(country_imps$country)), settings$unknown_country)) > 1
	#should we bother breaking out by country, or will there be only 1 country displayed?

	show_all_settings <- settings
	show_all_settings$threshold <- 0
	show_all_settings$donate_threshold <- 0
	pmin <- settings$pmin

	timespan <- graph_timespan(cleaneddata$imps, settings)
	one <- banners_over_time(cleaneddata$imps, settings, timespan, type=type)
	
	if(! isEnriched(dataCUM)){ dataCUM <-  enrichCData(dataCUM, alpha, beta)}

	two <- newgrapher(dataCUM, settings, ylimit="none", name=testname, controlname=controlname, variablename=variablename)
	A <- one
	B <- clicks_over_time(cleaneddata$clicks, settings, timespan=timespan, type='clicks')
	C <- clicks_over_time(cleaneddata$clicks, settings, timespan=timespan, type='donations')
	F <- imps_per_country(country_imps, type=type)
	G <- banners_over_time(cleaneddata$imps, show_all_settings, timespan=NA, type=type, per_country=FALSE)
	H <- clicks_over_time(country_clicks, show_all_settings, timespan=NA, type='donations', per_country=FALSE)
	
	I <- NULL
	J <- NULL
	result <- tryCatch({
				i3 <- amount_dist(cleaneddata$clicks, settings)
				I <- list(i3$base)
				for(i in i3$improvements){
					I <- c(I, list(i))
				}
				j3 <- amount_sum_dist(cleaneddata$clicks, settings)
				J <- list(j3$base)
				for(j in j3$improvements){
					J <- c(J, list(j))
				}
				#return(c(I, J))
			}, error = function(err){
				return(FALSE)
			})
	
	
	#pamplona over time
	K <- newgrapher(dataCUM, settings,  xaxisistime=TRUE,  timespan=timespan, ylimit="none", name=testname, controlname=controlname, variablename=variablename)
	equalbannerCUM <- equal_banner_cumulizer(data, settings)
	EqualGraph <- newgrapher(equalbannerCUM, settings, extrasub="Assuming completely equal banner impressions", ylimit="none", name=testname, controlname=controlname, variablename=variablename)
	
	extraGraphs <- list(EqualGraph, A, B, C)
	
	if(break_out_by_country){
		D <- banners_over_time(country_imps, settings, timespan, type=type, per_country=TRUE)
		E <- clicks_over_time(country_clicks, settings, timespan=timespan, type='donations', per_country=TRUE)	
		extraGraphs <- c(extraGraphs, list(D, E))
	}
	extraGraphs <- c(extraGraphs, list(F, G, H, K))
	extraGraphs <- list(blank=extraGraphs, amount=c(I,J))

	#impdiff_expected <- bannerCheck(dataCUM)
	#extradata <- list(diff = impdiff_expected$diff, expected = impdiff_expected$expected, impshare = biggest_BI_share(imps))

	extradata <- c()
	return(list(path=path, one=one, two=two, extra=extraGraphs, extradata = extradata))
}

biggest_BI_share <- function(imps){
	#the biggest country made up X% of total banner impressions"
	agg <- aggregate(imps ~ country, imps, sum)
	agg <- agg[order(agg$imps),]
	percent <- agg[nrow(agg),]$imps / sum(agg$imps) * 100
	return(percent)
}

graph_timespan <- function(banners, settings){
	threshold <- settings$threshold

	start <- head(banners,1)$timestamp
	if(threshold >0){
		end <- tail(subset(banners, imps >= threshold),1)$timestamp	
	}else{
		end <- tail(banners,1)$timestamp
	}
	
	
	start <- as.POSIXct(start, tz="UTC", origin="1970-01-01")
	end <- as.POSIXct(end, tz="UTC", origin="1970-01-01")
	
	banners <- subset(banners, timestamp>= start & timestamp <=end)
	timespan <- difftime(end, start, tz="UTC", units='mins')
	return(timespan)
}

banners_over_time <- function(banners, settings, timespan=NA, type='banner', per_country=FALSE){
	threshold <- settings$threshold
	numdots <- settings$numdots
	sub <- ""
	if(is.na(timespan)){
		timespan <- graph_timespan(banners, settings)
		sub <- paste0("We are looking at the entire time period of the test - make sure there aren't any surprising spikes in ", type, "s at the end. ")
	}
	
	minperdot <- ceiling(as.double(timespan) / numdots)

	
	ndata <- banners	
	ndata$newtime <- minuteGrouper(ndata$timestamp, minperdot)
	if(per_country){
		ndata <- ndata[c('newtime', 'imps', 'val', 'country')]	
		nndata <- cast(melt(ndata, id = c("newtime", "val","country")), newtime * val * country ~ variable, fun.aggregate = sum)
	}else{
		ndata <- ndata[c('newtime', 'imps', 'val')]	
		nndata <- cast(melt(ndata, id = c("newtime", "val")), newtime * val~ variable, fun.aggregate = sum)
	}
	
	newdata <- nndata[order(nndata$newtime),] 
	start <- newdata[1,]$newtime
	end <- start + timespan
	nndata <- nndata[nndata$newtime <= end,]

	#cut off extraneous data

	ylim = c(0, NA)
	
	ps = simpleTheme(col=c("blue","red",'green', 'purple', 'brown'),pch=20, cex=1.3, lwd=2)
	ylab = "Impressions"
	key = list(space="bottom", cex=1.1, points=FALSE, rectangles=TRUE)
	xlab = paste("Time (UTC), one dot per", minperdot, "minutes")
	sub = paste(sub, "If these lines don't match, we know there's a problem.")
	main = paste0(type, " impressions over time")
	if(threshold == 0 | is.na(threshold)){
		main = paste("COMPLETE TEST (aka with true end):", main)
	}


	if(!per_country){
		graph <- xyplot(imps ~ newtime, nndata,
			 type="o", 
			 ylim=ylim,
			 groups=val,
			 par.settings = ps,
			 ylab=ylab,
			 auto.key=key,
			 xlab=xlab,
			 xlab.top=sub,
			 main=main
			 )	
		}else{
			graph <- xyplot(imps ~ newtime | country, nndata,
			 type="o", 
			 ylim=ylim,
			 groups=val,
			 par.settings = ps,
			 ylab=ylab, 
			 auto.key=key,
			 xlab=xlab,
			 xlab.top=sub,
			 main=paste(main, "per country"),
			 )	
		}
	
	return(graph)
}


clicks_over_time <- function(clicks, settings, timespan=NA, type="clicks", per_country=FALSE){
	numdots <- settings$numdots
	threshold <- settings$donate_threshold
	if(type=="clicks"){threshold <- settings$landing_threshold}

	if(type=="clicks"){
		clicks$imps <- 1
	}
	if(type=="donations"){
		clicks$imps <- 0
		clicks[which(clicks$amount > 0),]$imps <- 1
	}
	sub <- ""
	if(is.na(timespan)){
		sub <- paste0("We are looking at the entire time period of the test - make sure there aren't any surprising spikes in ", type, "s at the end")

		timefind <- clicks
		#group by 1 minute
		timefind$timestamp <- minuteGrouper(clicks$timestamp, 1)
		
		timefind <- aggregate(imps ~ timestamp * val, timefind, sum)

		start <- head(timefind,1)$timestamp
		if(threshold > 0){
			#end the first time that the clicks (or donations) are less then X per minute
			end <- tail(subset(timefind, imps >= threshold),1)$timestamp	
		}else{
			end <- tail(clicks,1)$timestamp
		}
		
		
		start <- as.POSIXct(start, tz="UTC", origin="1970-01-01")
		end <- as.POSIXct(end, tz="UTC", origin="1970-01-01")
		
		clicks <- subset(clicks, timestamp>= start & timestamp <=end)
		timespan <- difftime(end, start, tz="UTC", units='mins')
	}
	#Threshold - if clicks/minute are lower than threshold, then stop the "viewing window" here.
	#Numdots - number of dots in the graph.
	
	minperdot <- ceiling(as.double(timespan) / numdots)
	
	
	ndata <- clicks	
	ndata$newtime <- minuteGrouper(ndata$timestamp, minperdot)
	if(per_country){
		ndata <- ndata[c('newtime', 'imps', 'val', 'country')]
		nndata <- cast(melt(ndata, id = c("newtime", "val", 'country')), newtime * val * country~ variable, fun.aggregate = sum)
	}else{
		ndata <- ndata[c('newtime', 'imps', 'val')]
		nndata <- cast(melt(ndata, id = c("newtime", "val")), newtime * val~ variable, fun.aggregate = sum)
	}
	
	newdata <- nndata[order(nndata$newtime),] 
	start <- newdata[1,]$newtime
	end <- start + timespan
	nndata <- nndata[nndata$newtime <= end,]
	#cut off extraneous data.

	ylim = c(0, NA)
	ps = simpleTheme(col=c("steelblue","tomato1",'springgreen', 'violet', 'brown4'),pch=20, cex=1.3, lwd=2)
	ylab = "Clicks"
	key = list(space="bottom", cex=1.1, points=FALSE, rectangles=TRUE)
	xlab = paste("Time (UTC), one dot per", minperdot, "minutes")
	sub = paste(sub, "Though one color should consistently do better than the other, they should rise and fall together.")
	main = paste(type, "over time")
	if(threshold <= 0 | is.na(threshold)){
		main = paste("COMPLETE TEST (aka with true end):", main)
	}

	if(!per_country){
		graph <- xyplot(imps ~ newtime, nndata,
		 type="o", 
		 ylim=ylim,
		 groups=val,
		 par.settings = ps,
		 ylab=ylab,
		 auto.key=key,
		 xlab=xlab,
		 main=main,
		 )
	}else{
		graph <- xyplot(imps ~ newtime | country, nndata,
		 type="o", 
		 ylim=ylim,
		 groups=val,
		 par.settings = ps,
		 ylab=ylab,
		 auto.key=key,
		 xlab=xlab,
		 main=paste(main, "per country"),
		 )	
	}
	
	return(graph)
}


paymentInsert <- function(donations, clicks){
	paymentTypes <- unique(clicks$paymenttype)
	for(i in 1:length(paymentTypes)){
		paymentLine <- paymentRow(paymentTypes[i], donations, clicks)
		if(i == 1){
			paymentFrame <- paymentLine
		}else{
			paymentFrame <- rbind(paymentLine, paymentFrame)
		}	
	}
	return(paymentFrame)
}


amount_dist_crunch <- function(clicks, settings){
	showamounts <- settings$col_amounts
	showother <- settings$col_other
	biggest_country <- tail(aggregate(amountsource ~ country, clicks, length),1)$country
	clicks <- subset(clicks, country == biggest_country)
	c2 <- clicks[which(clicks$amount > 0),]
	#c2 is only donations
	
	agg <- aggregate(contribution_id ~ amountsource * val * country, c2, length); 
	agg$freq <- agg$contribution_id; 
	agg$contribution_id <- NULL; 

	bigname <- paste0("other>",showother)
	smallname <- paste0("other<",showother)
	otheragg <- subset(agg, !(amountsource %in% showamounts))
	bigotheragg <- subset(otheragg, amountsource >= showother)
	smallotheragg <- subset(otheragg, amountsource < showother)
	if(nrow(bigotheragg) == 0){
		bigotheramount <- data.frame(amountsource=character(), val=character(), freq=numeric())
	}else{
		bigotheramount <- aggregate(freq~val, bigotheragg, sum)		
		bigotheramount$amountsource <- bigname
	}
	
	if(nrow(smallotheragg) == 0){
		smallotheramount <- data.frame(amountsource=character(), val=character(), freq=numeric())
	}else{
		smallotheramount <- aggregate(freq~val, smallotheragg, sum)
		smallotheramount$amountsource <- smallname
	}
	
	cleanagg <- subset(agg, amountsource %in% showamounts)
	agg3 <- aggregate(freq ~ amountsource * val, cleanagg, sum)
	
	agg3 <- agg3[order(as.numeric(agg3$amountsource), decreasing=FALSE),]
	agg3$amountsource <- as.factor(agg3$amountsource)
	order_ <- as.numeric(agg3$amountsource)
	order_ <- c(order_, smallname, smallname, bigname, bigname)
	agg3 <- rbind(agg3, smallotheramount)
	agg3 <- rbind(agg3, bigotheramount)
	toreturn <- list(agg=agg3, country=biggest_country)
	return(toreturn)
}

amount_dist <- function(clicks, settings){
	agg_country <- amount_dist_crunch(clicks, settings)
	agg3 <- agg_country$agg
	country <- agg_country$country
	cols <- settings$cols
	
	agg <- amountshift(clicks, settings, agg=agg3, absolute=FALSE)

	improvements <- improvement_barcharts(agg, settings, country=country)
	agg <- amountshift(clicks, settings, agg=agg3, absolute=TRUE)
	improvements2 <- improvement_barcharts(agg, settings, ispercent=FALSE, country=country)
	improvements <- c(improvements, improvements2)

	base <- barchart(freq ~ amountsource, data=agg3, horizontal=FALSE, 
		col=cols, main=paste("Donations per amountsource for", country), origin=0,  groups=val, beside=TRUE,
		auto.key=list(space="bottom", cex=2, points=FALSE, rectangles=FALSE, col=cols))
	toreturn <- list(base=base, improvements=improvements)
	return(toreturn)
}

amount_sum_dist_crunch <- function(clicks, settings){
	showamounts <- settings$col_amounts
	showother <- settings$col_other
	biggest_country <- tail(aggregate(amountsource ~ country, clicks, length),1)$country
	clicks <- subset(clicks, country == biggest_country)
	c2 <- clicks[which(clicks$amount > 0),]

	agg <- aggregate(amount ~ amountsource * val * country, c2, sum)

	bigname <- paste0("other>",showother)
	smallname <- paste0("other<",showother)
	otheragg <- subset(agg, !(amountsource %in% showamounts))
	bigotheragg <- subset(otheragg, amountsource >= showother)
	smallotheragg <- subset(otheragg, amountsource < showother)
	

	if(nrow(bigotheragg) == 0){
		bigotheramount <- data.frame(amountsource=character(), val=character(), amount=numeric())
	}else{
		bigotheramount <- aggregate(amount~val, bigotheragg, sum)		
		bigotheramount$amountsource <- bigname
	}
	
	if(nrow(smallotheragg) == 0){
		smallotheramount <- data.frame(amountsource=character(), val=character(), amount=numeric())
	}else{
		smallotheramount <- aggregate(amount~val, smallotheragg, sum)
		smallotheramount$amountsource <- smallname
	}
	
	cleanagg <- subset(agg, amountsource %in% showamounts)
	agg3 <- aggregate(amount ~ amountsource * val, cleanagg, sum)

	agg3 <- agg3[order(as.numeric(agg3$amountsource), decreasing=FALSE),]
	agg3$amountsource <- as.factor(agg3$amountsource)
	order_ <- as.numeric(agg3$amountsource)
	order_ <- c(order_, smallname, smallname, bigname, bigname)
	agg3 <- rbind(agg3, smallotheramount)
	agg3 <- rbind(agg3, bigotheramount)
	toreturn <- list(agg=agg3, country=biggest_country)
	return(toreturn)
}

amount_sum_dist <- function(clicks, settings){
	cols <- settings$cols
	agg_country <- amount_sum_dist_crunch(clicks, settings)
	agg3 <- agg_country$agg
	country <- agg_country$country
	
	agg <- amount_dollars_shift(clicks, settings, agg=agg3)
	improvements <- improvement_barcharts(agg, settings, country=country)

	agg <- amount_dollars_shift(clicks, settings, agg=agg3, absolute=TRUE)
	improvements2 <- improvement_barcharts(agg, settings, ispercent=FALSE, country=country)
	improvements <- c(improvements, improvements2)
	base <- barchart(amount ~ amountsource, data=agg3, horizontal=FALSE, 
		col=cols, main=paste("$ per amountsource for", country), origin=0,  groups=val, beside=TRUE,
		auto.key=list(space="bottom", cex=2, points=FALSE, rectangles=FALSE, col=cols))

	toreturn <- list(base=base, improvements=improvements)
	return(toreturn)
}

improvement_barcharts <- function(agg, settings, ispercent=TRUE, country=NA){
	cols <- settings$cols
	improvements <- list()

	if(ispercent){
		ylabel <- "change %"	
	}else{
		ylabel <- "change (absolute)"
	}

	if(is.na(country)){ country <- ""}
	
	i <- 0
	for(valtable in agg){
		i <- i + 1
		title <- colnames(valtable)[2]
		colnames(valtable)[2] <- "change"
		valtable$change <- lapply(valtable$change, as.character)
		valtable$change <- lapply(valtable$change, as.numeric)
		tmp <- barchart(change ~ amountsource, data=valtable, 
			horizontal=FALSE, main=paste(title, "in", country), col=cols[i],
			ylab = ylabel,
			auto.key=list(space="bottom", cex=2, points=FALSE, rectangles=FALSE, col=cols),
			panel=function(x, y,...){
            panel.barchart(x,y,origin = 0,...);
            panel.abline(h=0,...);
            },
            )
		improvements[[title]] <- tmp
		
	}
	return(improvements)
}


imps_per_country <- function(unpolished_imps, type="banner"){
	agg <- aggregate(imps ~ val * country, unpolished_imps, sum)
	graph <- barchart(imps ~ country,
        groups=val,
		data=agg,
		par.settings = simpleTheme(col=c("blue","red",'green', 'purple', 'brown'),pch=20, cex=1.3, lwd=2),
		auto.key=list(space="bottom", cex=1.1, points=FALSE, rectangles=TRUE),
		ylim=c(0, max(agg$imps)*1.1), 
		ylab=paste(type, "impressions"),
		main=paste(type, "impressions for each variation and country"),
		xlab.top="Each couple should be equal"
		)
	return(graph)
}

bannerCheck <- function(cdata){	
	lastrow <- cdata[nrow(cdata),]
	Aimps <- lastrow$Variable_imps
	Bimps <- lastrow$Control_imps
	diff <- round( ( (max(Bimps / Aimps, Aimps/Bimps) -1) * 100), 2)
	int <- binom.confint((Aimps + Bimps)/2, (Aimps + Bimps), .95,method="agresti-coul")
	expectedvariation <- round(((int$upper / int$lower)-1)*100,2)
	
	return(list("diff" = diff, "expected" = expectedvariation))
}


findmtableindex <- function(mt, testid, nation, lang, variable, multiple){
	if(nrow(mt) == 0){
		return(1)
	}
	index1 <- which(mt$test_id == testid & (mt$language %in% c("",0) | is.na(mt$language)) & (mt$country %in% c("", 0) | is.na(mt$country) )& (mt$var %in% c("", 0) | is.na(mt$var)) & (mt$multiple %in% c("", 0, "0") | is.na(mt$multiple)) )
	index2 <- which(mt$test_id == testid & mt$language == lang & mt$country== nation & mt$var == variable & mt$multiple == multiple)

	#index1 finds lines in mtable where something loosely matches - it has a 0, or "", in some fields.
	#index2 finds lines in mtable that match exactly: language, country, variable, multiple, etc.
	#if we can't find a line using index2, we use the looser index1

	#SYNTAX FIX
	if(length(index2) > 0){
		return(index2[1])
	}else if(length(index1 > 0)){
		return(index1[1])
	}
	return(nrow(mt) +1 )	
}

findmakepath <- function(subfolder="", testname, multiple="0"){
	testname <- toString(testname)
	if(!multiple %in% c("0", "", "unknown")){
		testname <- paste0(testname, "_m", multiple)
	}

	if(subfolder != ""){
		path <- file.path(getwd(), subfolder)
		dir.create(path, showWarnings = FALSE)
		path <- file.path(getwd(), subfolder, testname)			
		}else{
		path <- file.path(getwd(), testname)			
	}
	dir.create(path, showWarnings = FALSE)
	return(path)
}	



cleandata <- function(imps, clicks, testid, BV, settings, type="banner"){
	#A. Get the data ready
	#Part 1: Subset and clean the testdata
	icb <- prepare(imps, clicks, BV, testid)
	if(icb$skip){
		return(icb)
	}
	
	icb <- destroySmallDefects(testid, icb, settings)
	if(icb$skip){
		return(icb)
	}
	
	icb <- standardizeToBV(icb, country, language)
	if(icb$skip){
		return(icb)
	}
	
	icb <- mask_some_countries(icb, settings)
	if(icb$skip){
		return(icb)
	}
	imps <- icb$imps
	clicks <- icb$clicks
	BV <- icb$BV
	donations <- subset(clicks, amount > 0)

	data <- list(imps=imps, clicks=clicks, donations=donations)
	
	
	#How banner values are there?:
	numtypes <- length(unique(donations$val))
	toreturn <- list(numtypes=numtypes, skip=FALSE)
	
	if(numtypes < 2){
		#Easy to deal with - just skip
		return(list(skip=TRUE, why='Just one banner'))
	}
	if(numtypes == 2){
		#return the data we munged so far so that they can use it
		toreturn$data <- data
	}
	if(numtypes > 2){
		#They'll split this into AvB, AvC, etc. So just let them know where we stand
		allvals <- unique(icb$imps$val)
		winner <- predictWinningVal(icb)
		losers <- allvals[allvals != winner]
		toreturn$data <- data
		toreturn$winner <- winner
		toreturn$losers <- losers
	}
	return(toreturn)
}

combineData <- function(imps, donations, clicks, BV, settings){
	alpha <- settings$alpha
	beta <- settings$beta
	#subset only the values we care about
	values_we_want <- unique(BV$value)
	imps <- imps[imps$val %in% values_we_want,]
	donations <- donations[donations$val %in% values_we_want,]
	clicks <- clicks[clicks$val %in% values_we_want,]
	
	groupby <- 1
	donations$minute <- minuteGrouper(donations$timestamp, groupby)
	clicks$minute <- minuteGrouper(clicks$timestamp, groupby)
	
	jdV <- donations[c("amount", 'minute', "val")]
	#JustBannerVariable
	jbV <- imps[c("imps", 'timestamp', "val")]
	jbV <- jbV[order(jbV$timestamp),]

	colnames(jdV) <- c("amount", "minute", "variable")
	colnames(jbV) <- c("imps", 'minute', "variable")
	
	tmp <- datamaker(jdV, jbV)
	cumdata <- tmp$cumdata
	if(! isEnriched(cumdata)) {cumdata <- enrichCData(cumdata, alpha, beta)}
	tmp$cumdata <- cumdata
	data <- tmp

	data$skip <- FALSE
	data$imps <- imps
	data$donations <- donations
	data$clicks <- clicks
	data$isclearwinner <- tail(data$cumdata,1)$implower > 0
	return(data)
}

bootstrapper_confint <- function(sample, settings, size=1000){
	alpha <- settings$alpha
	#confidence <- 1 - alpha

	lowbound <-  (alpha)/2
	highbound <- 1-alpha + lowbound

	stats <- c()
	for(i in 1:size){
		subsample <- sample(sample, length(sample), replace=T)
		stats <- c(stats, mean(subsample))
	}

	lower <- quantile(stats, lowbound) #lowbound is typically .025
	upper <- quantile(stats, highbound) # highbound is typically .975

	toreturn <- list(lower=lower, upper=upper)
}

continuous_conf_finder <- function(imps, donations, value){
	imps <- subset(imps, val==value)$imps
	numimps <- sum(imps)
	donations <- subset(donations, val==value)$amount
	numdonate <- length(donations)
	numskip <- numimps - numdonate
	total <- c(donations, rep(0, numskip))
	conf <- t.test(total)$conf.int
	mean <- mean(total)
	conf <- c(conf, mean)
	return(conf)
}

dollarCrunch <- function(imps, donations, control, variable, settings){
	alpha <- settings$alpha
	z <- z_value(alpha)

	#Control
	control_conf <- continuous_conf_finder(imps, donations, control)
	controllower <- control_conf[1]
	controlupper <- control_conf[2]
	controlmean  <- control_conf[3]
	controlsd <- (controlupper - controllower)/(2*z)

	variable_conf <- continuous_conf_finder(imps, donations, variable)
	varlower <- variable_conf[1]
	varupper <- variable_conf[2]
	varmean  <- variable_conf[3] 
	varsd <- (varupper - varlower)/(2*z)

	uplow <- improvement(controlsd, controlmean, varsd, varmean, alpha)
	lowerboundrelativesuccess <- uplow$lowerbound
	upperboundrelativesuccess <- uplow$upperbound
	newmean <- uplow$mean
	newsd <- uplow$sd
	#Not sure what this is. Copied blindly from ABBA documentation.
	impmean <- newmean / controlmean
	impsd <- newsd / controlmean
	
	dollarimprovement <- impmean * controlmean
	dollarlower <- lowerboundrelativesuccess * controlmean
	dollarupper <- upperboundrelativesuccess * controlmean

	toreturn <- list(
	dollarimprovement=dollarimprovement,
	dollarlower=dollarlower,
	dollarupper=dollarupper,
	dollarimprovementpct=impmean,
	dollarlowerpct=lowerboundrelativesuccess,
	dollarupperpct=upperboundrelativesuccess
	)
	return(toreturn)
}


predictWinningVal <- function(icb){
	imps <- icb$imps
	clicks <- icb$clicks
	BV <- icb$BV

	clicksAggregated <- aggregate(amount ~ val, data = icb$clicks, length)
	impsAggregated <- aggregate(imps ~ val, data = icb$imps, sum)
	winPercent <- 0
	winner <- ""
	for (rownum in 1:length(impsAggregated)){
		row <- impsAggregated[rownum,]
		val <- row$val
		numimps <- row$imps

		clicksrow <- clicksAggregated[clicksAggregated$val == val,]
		numclicks <- clicksrow$amount

		percent <- numclicks / numimps
		if(percent > winPercent){
			winPercent <- percent
			winner <- val
		}
	}

	return(winner)
}



oneReport <- function(testid, testname, metatable, imps, clicks, donations, BV, settings, var="var", multiple="0",country='YY', language="yy", full=TRUE, type="banner"){
	

	savePolishedData <- function(data){
		
		 
		if(isshadow | issample){
			drv <- dbDriver("SQLite") 
			con <- dbConnect(drv, "testingdb")
		}else{ 
			con <- dbConnect(MySQL(), dbname="fr_test")
		}
		on.exit(dbDisconnect(con))
		tn <- testname
		if(!multiple %in% c("0", "", "unknown")){
			tn <- paste0(tn, "_m", multiple)
		}

		cdata <- as.data.frame(data$cumdata)
		row.names(cdata) <- NULL
		cdata$test_name <- as.character(tn)
		cdata$test_id <- as.integer(testid)
		cdata$var <- as.character(var)
		cdata$lang <- as.character(language)
		cdata$country <- as.character(country)

		
		
		dbWriteTable(con, "tmp", cdata)
		if(!dbExistsTable(con, "polishCUM")){
			dbWriteTable(con, "polishCUM", cdata)
		}
		else{
			dq <- dbGetQuery(con, paste0("delete from polishCUM where test_name == '", testname,"'"))
			gq <- dbGetQuery(con, paste0("SELECT * from polishCUM where test_name == '", testname,"'"))
			if(nrow(gq) < 1){
				dbSendQuery(con, "INSERT INTO polishCUM SELECT * from tmp;")
			}

		}
		dbRemoveTable(con, "tmp")
		
		
	}

	topline <- function(banners, clicks, donations, dollardata, settings, iswinner=TRUE){
	
		winLoseResult <- function(which){
			return(onelineResult(which, subset(clicks, val==which), subset(donations, val==which), subset(banners, val==which), settings))
		}
		
		whichX <- function(which){
			return(amountXtable(which, subset(banners, val==which), subset(donations, val==which), settings))
		}
		variations <- unique(banners$val)
		for(v in 1:length(variations)){
			if(v==1){
				topFrame <- winLoseResult(variations[v])
				amountXframe <- whichX(variations[v])
			}else{
				topFrame <- rbind(winLoseResult(variations[v]), topFrame)
				amountXframe <- rbind(whichX(variations[v]), amountXframe)
			}
		}
		AB <- topFrame
		
		aX <- amountXframe
		

			
		paymentFrame <- paymentInsert(donations, clicks)
		paymentFrame <- paymentFrame[order(paymentFrame$donations, na.last=FALSE),]
		
		#conversionByName <- list()
		#for(v in variations){
		#	conversionF <- paymentInsert(subset(donations, val=v), subset(clicks, val=v))
		#	conversionF <- conversionF[order(conversionF$donations, decreasing=TRUE),]
		#	conversionF <- conversionF[1:settings$numpayments,]$conversion
		#	conversionByName[[v]] <- conversionF
		#}

		


		#shifttables <- amountshift(donations, settings)
		#shifttables_dollars <- amount_dollars_shift(donations, settings)

			
		findwinner <- function(A, B){
			Adbi <- A$donationsPer1000BI
			Bdbi <- B$donationsPer1000BI
			
			if(Adbi > Bdbi){
				return(list(winner=A, loser=B))
			}
			return(list(winner=B, loser=A))
		}

		AvB <- AvBline(findwinner(AB[1,], AB[2,]), donations, dollardata, settings)
		if(AvB$skip){
			return(AvB)
		}

		#conversionF <- paymentInsert(donations, clicks)
		#conversionF <- conversionF[order(conversionF$donations, decreasing=TRUE),]
		#names <- conversionF[1:settings$numpayments,]$names
		#names <- paste0(names, "pct")
		#HERE
		types <- settings$paytypes
		typespct <- paste0(types, "%")
		ecom <- merge(AB, aX)
		ecom <- ecom[c('name', 'donations', 'clicks', 'impressions', types , "donationsPer1000BI", "dollarsPer1000BI", 'amount', "amount20",  'avg20', 'avgDonation', 'median', 'max', 'mode_s')]
		colnames(ecom) <- c('name', 'dons', 'clicks', 'imps', typespct, 'don/Kimps', '$/Kimps', 'amount', 'amount20/Kimps', 'avg20', 'mean', 'median', 'max', 'mode')
		ecom['don/Kimps'] <- round(as.numeric(ecom[,'don/Kimps']), digits=4)
		
		for(type in types){
			AB[type] <- NULL
		}

		AB <- topFrame_bottom(AB)
		toreturn <- list(A=AB, B=AvB$line, E=paymentFrame, D=aX, ecom=ecom, skip=FALSE)
			#F=shifttables, G=shifttables_dollars, 
			
		return(toreturn)	
	
	}
	
	updatemetatable <- function(metatable, cleaneddata, dollardata, language, var, multiple, country, type, settings, testname){
		roundby <- settings$digitsround

		controlname <- cleaneddata$control
		variablename <- cleaneddata$variable
		data <- cleaneddata$data
		dataCUM <- cleaneddata$cumdata
		iswinner <- cleaneddata$isclearwinner
		start <- as.numeric(data[1,]$minute)
		#Topline summary
		lastrow <- tail(dataCUM, 1)
		winner <- variablename
		loser <- controlname
		p <- pfinder(lastrow)
		alpha <- settings$alpha
		beta <- settings$beta
		
	
		lastrow <- rangecalc(lastrow, alpha, beta)
		#This is how we prevent duplication
		index <- findmtableindex(metatable, testid, country, language, var, multiple)
		insertinto <- metatable[index,]
		if(index > nrow(metatable)){
			insertinto$test_id <- testid
		}

		insertinto$p <- signif(p, 2)
		insertinto$country <- country
		insertinto$language <- language
		insertinto$var <- var
		insertinto$multiple <- multiple
		insertinto$winner <- toString(variablename)
		insertinto$loser <- toString(controlname)
		insertinto$lowerbound <- signif(lastrow$implower * 100, roundby)
		insertinto$upperbound <- signif(lastrow$impupper * 100, roundby)
		insertinto$bestguess <- signif(lastrow$impmean * 100, roundby)
		insertinto$totalimpressions <- (lastrow$Control_imps + lastrow$Variable_imps)
		insertinto$totaldonations <- (lastrow$Control_donations + lastrow$Variable_donations)
		insertinto$time <- start
		insertinto$type <- type
		insertinto$testname <- testname
		insertinto$dollarimprovement <- signif(dollardata$dollarimprovement, roundby)
		insertinto$dollarlower <- signif(dollardata$dollarlower, roundby)
		insertinto$dollarupper <- signif(dollardata$dollarupper, roundby)
		insertinto$dollarimprovementpct <- signif(dollardata$dollarimprovementpct * 100, roundby)
		insertinto$dollarlowerpct <- signif(dollardata$dollarlowerpct * 100, roundby)
		insertinto$dollarupperpct <- signif(dollardata$dollarupperpct * 100, roundby)

		#insertinto$testname <- testname
		#if(!iswinner || lastrow$implower < 0 ){
		#	insertinto$winner <- paste0("(NO CLEAR WINNER): ", insertinto$winner)
		#}

		metatable[index,] <- insertinto
		row.names(metatable) <- NULL 

		
		if(isshadow | issample){
			drv <- dbDriver("SQLite") 
			con <- dbConnect(drv, "testingdb")
		}else{ 
			con <- dbConnect(MySQL(), dbname="fr_test")
		}
		on.exit(dbDisconnect(con))
		#The way we guard against inserting the same row over and over into the table is by clearing the old table completely and adding the new table into it
		#The reason that^ works is that we already have tests to prevent insertion-duplication for dataframes. See ~25 lines above
		if(dbExistsTable(con, 'meta')){
			dbRemoveTable(con, 'meta')
		}
		dbWriteTable(con, "meta", metatable, row.names=FALSE)
		
		
		


		return(metatable)
	}
	
	values_we_want <- unique(BV$value)
	donations <- donations[donations$val %in% values_we_want,]
	if(length(which(aggregate(contribution_id ~ val, donations, length)$contribution_id < 50)) > 1){
		return(list(skip=TRUE, why=paste("total donations for one value less than", donationfloor), writeTable=FALSE))
	}

	
	data <- combineData(imps, donations, clicks, BV, settings)
	saveThis <- data
	dollardata <- dollarCrunch(data$imps, data$donations, data$control, data$variable, settings)
	toplineData <- topline(data$imps, data$clicks, data$donations, dollardata, settings, iswinner=data$isclearwinner)

	

	if(toplineData$skip){
		start <- as.numeric(data$data[1,]$minute)
		data <- toplineData
		#print(paste("Skipping, because", data$why))
		index <- findmtableindex(metatable, testid, country, language, var, multiple)
		metatable[index,] <- 0
		metatable[index,'test_id']<-testid
		metatable[index,"var"] <- var
		metatable[index, "multiple"] <- multiple
		metatable[index,"country"] <- country
		metatable[index,"language"] <- language
		metatable[index,"winner"]<- ""
		metatable[index,"loser"] <- data$why
		metatable[index,'time'] <- start
		metatable[index,'type'] <- type
		errorline <- c(testid, var, multiple, country, language, data$why, start, type)
		
		return(list(metatable=metatable, skip=TRUE, why=errorline))
	}
	
	if(full){
		graphs <- graphreports(data, data$clicks, data$imps, settings, testname=testname, type=type, multiple=multiple)
	}
	else{
		graphs <- list(one=NA, two=NA, extra=NA)
	}
	
	if(data$isclearwinner & toplineData$B$winner != data$variable){
		why = "can't agree on a winner"
		errorline <- c(testid, var, multiple, country, language, why)
		#print(paste("ERROR", why))
		#print(testid)
		return(list(skip=TRUE, why=errorline))
	}
	
	mtable <- updatemetatable(metatable, data, dollardata, language, var, multiple, country, type, settings, testname)
	
	toreturn <- list(
		#F=toplineData$F, G=toplineData$G, 
		path=graphs$path, graphone=graphs$one, graphtwo=graphs$two, metatable=mtable, binomData=data, skip=FALSE, winner=data$variable, extraGraphs=graphs$extra, extradata= graphs$extradata, multiple=multiple, country=country, language=language, type=type)
	toreturn <- append(toreturn, toplineData)
	#savePolishedData(saveThis)
	return (toreturn)
}



###############
###############
###############
###############
#### SETUP ####
###############
###############
###############
###############


if(issample){
	oneForm <- read.delim("./sample/easyform.tsv", quote="", na.strings = "", row.names=NULL, strip.white=TRUE)		
}else{
	oneForm <- read.delim("./data/easyform.tsv", quote="", na.strings = "", row.names=NULL, strip.white=TRUE)		
}

if(isold){
	TLBVVCL <- read.delim("./data/TLBVVCL.tsv", quote="", na.strings = "", strip.white=TRUE)
	TLBVVCL[c("split.on.country", "split.on.language")][is.na(TLBVVCL[c("split.on.country", "split.on.language")])] <- FALSE
	screenshots <- read.delim("./data/screenshots.tsv", quote="", na.strings = "", stringsAsFactors=FALSE)
	screenshots <- data.frame(apply(screenshots, c(1,2), function(x){gsub("[[:space:]]+", "", x)}), stringsAsFactors=FALSE)
	TLBVVCL <- data.frame(apply(TLBVVCL, c(1,2), function(x){gsub("[[:space:]]+", ".", x)}))
	TLBVVCL <- data.frame(apply(TLBVVCL, c(1,2), function(x){gsub(".TRUE", TRUE, x)}))
	TLBVVCL$link <- NULL
}else{
	oneForm <- oneForm[rowSums(is.na(oneForm)) != ncol(oneForm),] #snippet from http://stackoverflow.com/questions/6437164/removing-empty-rows-of-a-data-file-in-r
	TBVD <- oneForm[c("test_id", 'Banner','Variable', 'Description', 'Description')]
	TBVD['split.on.country'] <- FALSE
	TBVD['split.on.language'] <- FALSE
	colnames(TBVD) <- c('test_id', 'banner', 'variable', 'description', 'value', 'split.on.language', 'split.on.country')
	TBVD[c("split.on.country", "split.on.language")][is.na(TBVD[c("split.on.country", "split.on.language")])] <- FALSE
	TBVD <- data.frame(apply(TBVD, c(1,2), function(x){gsub("[[:space:]]+", ".", x)}))
	TBVD <- data.frame(apply(TBVD, c(1,2), function(x){gsub(".TRUE", TRUE, x)}))

	TLBVVCL <- TBVD

	screenshots <- oneForm[c('test_id', 'Banner', 'Screenshot', 'Extra.Screenshot')]
	colnames(screenshots) <- c("test_id", 'banner.or.landing', 'screenshot', 'extra_screenshot_1')
	screenshots$campaign <- NA
	screenshots$extra_screenshot_2 <- NA
	screenshots <- screenshots[c('test_id', "banner.or.landing", "campaign", "screenshot", "extra_screenshot_1", "extra_screenshot_2")]
	screenshots <- data.frame(apply(screenshots, c(1,2), function(x){gsub("[[:space:]]+", "", x)}), stringsAsFactors=FALSE)
}
#delete blank lines




##call = "cd executable && ./importDB.sh"
##system(call)

#opt = suppressWarnings(getopt(c(
#  'sample', 's', 0, "logical",
#  'help'   , 'h', 0, "logical",
#  'shadow'  , 'S', 0, "logical",
#  'write'   , 'w', 0, "logical",
#  'old'     , 'o', 0, "logical"
#)));


#if ( is.null(opt$sample    ) ) 	{ opt$sample    = FALSE		}
#if ( is.null(opt$help      ) ) 	{ opt$help      = FALSE		}
#if ( is.null(opt$shadow   ) ) 	{ opt$shadow     = FALSE	}
#if ( is.null(opt$write ) ) 		{ opt$write = TRUE			}
#if ( is.null(opt$old ) )		{ opt$old = FALSE			}


args <- commandArgs(TRUE)
tid <- args[1]
hackish_flag <- args[2]
if(!is.na(tid)){
	print(paste('crunching test', tid))
	tid <- as.character(tid)
	towrite <- TRUE
	if(!is.na(hackish_flag) & as.character(hackish_flag) == "NOWRITE"){
		towrite <- FALSE
		print("Skipping graphs")
	}
	rTemp <- allreport(testid=tid, write=towrite, showerror=TRUE)	
}else{
	#rTemp <- allreport(write=TRUE)
	print("script loaded")
}


###
### IF YOU'VE DOWNLOADED THIS FROM GITHUB
### Run this to use the sample data

#rTemp <- allreport(write=TRUE, sample=TRUE, showerror=TRUE)

