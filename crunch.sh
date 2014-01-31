[ -z $1 ] && echo "need a testid"
[ -z $1 ] && exit

rm -r report/$1* 2> /dev/null
Rscript easyReporter.R $1 > /dev/null || echo $1 >> crunch.errors.txt 
echo "done" 
rm -r /srv/reports/$1* 2>/dev/null 

cp -r report/$1* /srv/reports
mkdir /srv/reports/allreports 2> /dev/null
cp -r report/allreports/$1* /srv/reports/allreports/ &&
echo "select winner, loser, bestguess, lowerbound, upperbound, p from fr_test.meta where test_id = '$1'" | mysql --table

testnames=$(ls report | grep $1)
#for var in $testnames
#do
#	echo "Created folder $var"
#done
for var in $testnames; 
do
	echo "URL: https://lutetium.wikimedia.org/reports/$var/show.html"
done

