echo Tira-ÚFAL-kcYy1z3K-TvjH,zttN.
cd /net/work/people/zeman/unidep/conll/conll2018-web
scp -P 44424 conll17-master@webis62.medien.uni-weimar.de:/home/conll17-master/conll2018/results.zip .
unzip -o results.zip
rm results.zip
git pull --no-edit
git add results*
git commit -m 'Updated results.'
git push
