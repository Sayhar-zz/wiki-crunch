options("repos"="http://cran.us.r-project.org")    ## US mirror

#package installation problems? Try: http://mazamascience.com/WorkingWithData/?p=1185

#First try without the lib= parameter, then if that doesn't work, use it
install.packages("xtable", lib="~/.R/library")
install.packages("plyr", lib="~/.R/library")
install.packages("reshape", lib="~/.R/library")
install.packages("latticeExtra", lib="~/.R/library")
install.packages("binom", lib="~/.R/library")
#install.packages("RMySQL", lib="~/.R/library")
