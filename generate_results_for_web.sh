# Once the official results have been published, we probably do not want to
# regenerate them. If we only want to regenerate the unofficial runs, that is,
# --bestresults and --allresults, we run this as $0 unoff.
if [[ "$1" != "unoff" ]] ; then
  collect_evaluation.pl --metric pertreebank-LAS-F1 > results-las.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-MLAS-F1 > results-mlas.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-BLEX-F1 > results-blex.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-CLAS-F1 > results-clas.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-UAS-F1 > results-uas.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-UPOS-F1 > results-upos.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-XPOS-F1 > results-xpos.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-UFeats-F1 > results-ufeats.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-AllTags-F1 > results-alltags.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-Lemmas-F1 > results-lemmas.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-Sentences-F1 > results-sentences.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-Words-F1 > results-words.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-Tokens-F1 > results-tokens.md 2>/dev/null
  collect_evaluation.pl --metric ranktreebanks-LAS-F1 --format markdown > results-treebanks-las.md 2>/dev/null
  collect_evaluation.pl --metric ranktreebanks-MLAS-F1 --format markdown > results-treebanks-mlas.md 2>/dev/null
  collect_evaluation.pl --metric ranktreebanks-BLEX-F1 --format markdown > results-treebanks-blex.md 2>/dev/null
  collect_evaluation.pl --metric ranktreebanks-Words-F1 --format markdown > results-treebanks-words.md 2>/dev/null
  collect_evaluation.pl --metric ranktreebanks-Sentences-F1 --format markdown > results-treebanks-sentences.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-LAS-F1  --systems 2017 --bestresults > results-las-2017.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-MLAS-F1 --systems 2017 --bestresults > results-mlas-2017.md 2>/dev/null
  collect_evaluation.pl --metric pertreebank-BLEX-F1 --systems 2017 --bestresults > results-blex-2017.md 2>/dev/null
fi
cat <<EOF > results-best-all.md
---
layout: page
title: CoNLL 2018 Shared Task
---

# Results: Unofficial runs included (LAS)

<strong style='color:red'>DISCLAIMER:</strong> This is not the official ranking of systems participating in the shared task.

<strong style='color:red'>WARNING:</strong> These results are subject to change (new runs may be added).

This page tries to complement the overall picture by considering software that was not marked as primary system of the
respective team, or runs of the primary system that were not marked as the final submission (and the software setting may
have changed between the runs). It also includes runs that were performed after the [official results](results.html) were
announced and the test data (including gold-standard annotation) were unblinded; furthermore, some of the runs were
performed outside TIRA, and the corresponding “software” on TIRA only copied the pre-computed output to the destination
folder.

(The teams were able to analyze their official test runs only after everything was unblinded. In some cases, they found out
that there was a bug that caused the system to select a wrong model. The out-of-TIRA runs circumvent the necessity to train
the system on the same machine on which the testing takes place.)
The secondary systems and the corrected runs of primary systems may be described in the respective system-description papers.

A “-P” after software name indicates a primary system. “[OK]” means that the run has non-zero scores for all 81 test files;
otherwise, a number identifies how many files had non-zero scores (runs with zero such files are not included).
The last column identifies the system run and the
corresponding evaluation run (in some cases files from several runs were combined). Runs marked “Fin:” were registered as the
official final submission of the team, i.e. the score (but not the ranking) on a line that contains both “-P” and “Fin:”
should be identical to the official result of the team. Runs marked “OOT:” were reported by their authors as “out-of-TIRA”,
i.e. parsing occurred elsewhere and results were copied to TIRA.
EOF
collect_evaluation.pl --metric total-LAS-F1 --bestresults --format markdown >> results-best-all.md 2>/dev/null
collect_evaluation.pl --metric total-MLAS-F1 --bestresults --format markdown >> results-best-all.md 2>/dev/null
collect_evaluation.pl --metric total-BLEX-F1 --bestresults --format markdown >> results-best-all.md 2>/dev/null
collect_evaluation.pl --metric total-LAS-F1 --allresults --format markdown >> results-best-all.md 2>/dev/null
collect_evaluation.pl --metric total-MLAS-F1 --allresults --format markdown >> results-best-all.md 2>/dev/null
collect_evaluation.pl --metric total-BLEX-F1 --allresults --format markdown >> results-best-all.md 2>/dev/null
cat <<EOF > results-2017-systems.md
---
layout: page
title: CoNLL 2018 Shared Task
---

# Results: 2017 shared task systems applied to 2018 test data

<strong style='color:red'>DISCLAIMER:</strong> This is not the official ranking of systems participating in the shared task.

The [systems from the 2017 shared task](http://universaldependencies.org/conll17/results.html) applied to the 2018 test data.
While this is an interesting comparison, note that the 2017 systems
do not comply with the 2018 rules because they were trained on a different
release of Universal Dependencies. It may affect the results in both ways:
if the annotation of the treebank was improved, the old parser is handicapped.
If the training-test split has changed and the old training data are now in test data,
the old parser is favored undeservedly.

Also, the 2018 data contain eight new languages, and a number of new treebanks for the other languages.
The rules of both tasks required that the parsers be robust enough and produce valid output for any
language and treebank code, even if they are unknown. Most parsers ignored this request and simply
crashed on unexpected language/treebank code; but even if they did not crash, their output on these
languages is probably not interesting. Therefore, we define a subset of “old treebanks”, i.e.,
those that were evaluated in both years. The tables on this page are macro-averages over the old
treebanks. There are also links to separate pages with per-treebank results.

Note that if a team has identical name in the two tasks, it does not necessarily mean that their
2018 system can be considered a new version of the one from 2017. Sometimes a team used completely
different software in the two years. On the other hand, in some cases same people from the same
institution participated under different team names (e.g., 2017 RACAI is NLP-Cube in 2018).

* [Per-treebank LAS results, 2017 systems](results-las-2017.html)
* [Per-treebank LAS results, 2018 systems](results-las.html)
* [Per-treebank MLAS results, 2017 systems](results-mlas-2017.html)
* [Per-treebank MLAS results, 2018 systems](results-mlas.html)
* [Per-treebank BLEX results, 2017 systems](results-blex-2017.html)
* [Per-treebank BLEX results, 2018 systems](results-blex.html)

## LAS ranking 2017 systems

<pre>
EOF
collect_evaluation.pl --metric oldtreebanks-LAS-F1 --systems 2017 --bestresults >> results-2017-systems.md 2>/dev/null
cat <<EOF >> results-2017-systems.md
</pre>

## LAS ranking 2018 systems

<pre>
EOF
collect_evaluation.pl --metric oldtreebanks-LAS-F1 --systems 2018 >> results-2017-systems.md 2>/dev/null
cat <<EOF >> results-2017-systems.md
</pre>

## MLAS ranking 2017 systems

<pre>
EOF
collect_evaluation.pl --metric oldtreebanks-MLAS-F1 --systems 2017 --bestresults >> results-2017-systems.md 2>/dev/null
cat <<EOF >> results-2017-systems.md
</pre>

## MLAS ranking 2018 systems

<pre>
EOF
collect_evaluation.pl --metric oldtreebanks-MLAS-F1 --systems 2018 >> results-2017-systems.md 2>/dev/null
cat <<EOF >> results-2017-systems.md
</pre>

## BLEX ranking 2017 systems

<pre>
EOF
collect_evaluation.pl --metric oldtreebanks-BLEX-F1 --systems 2017 --bestresults >> results-2017-systems.md 2>/dev/null
cat <<EOF >> results-2017-systems.md
</pre>

## BLEX ranking 2018 systems

<pre>
EOF
collect_evaluation.pl --metric oldtreebanks-BLEX-F1 --systems 2018 >> results-2017-systems.md 2>/dev/null
cat <<EOF >> results-2017-systems.md
</pre>
EOF
zip results.zip results-*.md
