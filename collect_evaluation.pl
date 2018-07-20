#!/usr/bin/env perl
# Parses prototext output from Milan's evaluator. Stores the key-value pairs in a hash.
# Copyright © 2017 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;
use dzsys; # Dan's library for file system operations



my $metric = 'total-LAS-F1';
my $bestresults = 0; # display best result of each team regardless whether it is the final run of the primary system
my $allresults = 0; # display multiple results per team
my $copy_filtered_eruns; # target path, e.g. /net/work/people/zeman/unidep/conll2017-test-runs/filtered-eruns
my $copy_conllu_files; # target path, e.g. /net/work/people/zeman/unidep/conll2017-test-runs/filtered-conllu
my $format; # default: plain text table, no headings. Options: markdown|latex
GetOptions
(
    'metric=s' => \$metric,
    'bestresults' => \$bestresults,
    'allresults' => \$allresults,
    'copy=s' => \$copy_filtered_eruns,
    'cocopy=s' => \$copy_conllu_files,
    'format=s' => \$format # format=markdown, format=latex
);
# Metrics:
# total-LAS-F1, -MLAS-, -BLEX-, -CLAS-, -UAS-, -UPOS-, -XPOS-, -UFeats-, -AllTags-, -Lemmas-, -Words-, -Tokens-, -Sentences-
# bigtreebanks-*, pudtreebanks-*, smalltreebanks-*, surtreebanks-* (ditto)
# individual treebanks, e.g., pl_lfg-LAS-F1
# pertreebank-* (ditto)
# ranktreebanks, ranktreebanks-CLAS, ranktreebanks-both



# The output of the test runs is mounted in the master VM at this point:
my $testpath_tira = '/media/conll18-ud-test-2018-05-06';
my $testpath_ufal1 = '/net/work/people/zeman/unidep/conll/system-runs-2018/conll18-ud-test-2018-05-06-downloaded-2018-07-04-02-42';
my $testpath_ufal2 = '/net/work/people/zeman/unidep/conll2017-test-runs-v2/conll18-ud-test-2018-05-06';
my $testpath_ufal3 = '/net/work/people/zeman/unidep/conll2017-test-runs-v3/conll18-ud-test-2018-05-06';
my $testpath_dan  = 'C:/Users/Dan/Documents/Lingvistika/Projekty/universal-dependencies/conll2017-test-runs/filtered-eruns';
# Treebanks fall into several categories:
my @bigtbk = qw(af_afribooms grc_perseus grc_proiel ar_padt eu_bdt bg_btb ca_ancora hr_set cs_cac cs_fictree cs_pdt
                da_ddt nl_alpino nl_lassysmall en_ewt en_gum en_lines et_edt fi_ftb fi_tdt fr_gsd fr_sequoia fr_spoken
                gl_ctg de_gsd got_proiel el_gdt he_htb hi_hdtb hu_szeged zh_gsd id_gsd it_isdt it_postwita ja_gsd
                ko_gsd ko_kaist la_ittb la_proiel lv_lvtb no_bokmaal no_nynorsk
                fro_srcmf cu_proiel fa_seraji pl_lfg pl_sz pt_bosque ro_rrt ru_syntagrus sr_set sk_snk sl_ssj es_ancora
                sv_lines sv_talbanken tr_imst uk_iu ur_udtb ug_udt vi_vtb);
my @smltbk = qw(gl_treegal ga_idt la_perseus sme_giella no_nynorsklia ru_taiga sl_sst);
my @pudtbk = qw(cs_pud en_pud fi_pud ja_modern sv_pud);
my @surtbk = qw(bxr_bdt hsb_ufal hy_armtdp kk_ktb kmr_mg
                br_keb fo_oft pcm_nsc th_pud);
my @alltbk = (@bigtbk, @smltbk, @pudtbk, @surtbk);
# Sanity check: There are 82 treebanks in total.
my $ntreebanks = 82;
die("Expected $ntreebanks treebanks, found ".scalar(@alltbk)) if (scalar(@alltbk) != $ntreebanks);
# Deadline is a timestamp in the same format as identifiers of runs (rrrr-mm-dd-hh-mm-ss).
# Typically it is not the deadline from the rules because we allow a few more hours for runs to complete.
# However, once we publish the official results, we do not want to pick up any further arrivals except
# for unofficial results. Evaluation runs must have their names (start times) earlier than this deadline
# in order to be considered official. (The timestamps on Tira are based on the Central-European time.)
my $deadline = '2018-07-02-23-50-45';
# If takeruns is present, it is the sequence of system runs (not evaluation runs) that should be combined.
# Otherwise, we should take the last complete run (all files have nonzero scores) of the primary system.
# If no run is complete and no combination is defined, should we take the best-scoring run of the primary system?
# In any case, the primary system must be defined. We shall not just take the best-scoring one.
my %teams =
(
    ###!!! WARNING! Stanford-18 primary software is software2 but Stanford-182 primary is software1!
    'Stanford-18' => {'city' => 'Stanford', 'printname' => 'Stanford', 'primary' => 'any'},
    'Stanford-182' => {'city' => 'Stanford'},
    'iParse' => {'city' => 'Pittsburgh'},
    'IBM-NY' => {'city' => 'Yorktown Heights', 'printname' => 'IBM NY'},
#    'IBM-NY' => {'city' => 'Yorktown Heights', 'printname' => 'IBM NY', 'takeruns' => ['2018-07-01-23-33-16', '2018-07-01-20-34-40', '2018-07-01-16-22-35', '2018-07-01-10-31-23', '2018-07-01-04-45-06', '2018-07-01-02-41-12', '2018-07-01-01-03-32', '2018-06-30-20-44-42', '2018-06-30-16-19-27', '2018-06-30-13-33-36', '2018-06-30-07-56-07', '2018-06-30-07-02-14', '2018-06-30-06-06-24', '2018-06-30-02-31-38', '2018-06-29-23-59-43', '2018-06-29-21-37-52', '2018-06-29-20-54-06', '2018-06-29-18-20-53', '2018-06-29-15-31-35', '2018-06-29-09-22-39', '2018-06-29-03-29-15', '2018-06-28-22-26-54', '2018-06-28-19-50-00', '2018-06-28-07-21-53', '2018-06-27-07-33-36', '2018-06-25-23-24-40',
#        # plus the following runs from IBM-NY2:
#        '2018-07-01-16-24-25', '2018-07-01-09-31-25', '2018-06-30-22-08-23', '2018-06-30-12-17-43', '2018-06-30-04-27-46', '2018-06-29-19-57-11', '2018-06-29-15-14-05', '2018-06-29-10-58-01', '2018-06-29-03-47-28', '2018-06-29-00-37-14', '2018-06-27-13-28-54', '2018-06-27-06-48-33', '2018-06-27-05-25-50', '2018-06-26-23-27-33', '2018-06-25-23-28-22',
#        # plus the following runs from IBM-NY3:
#        '2018-07-01-22-08-57', '2018-07-01-14-31-30', '2018-07-01-10-19-10', '2018-06-30-20-08-11', '2018-06-30-06-32-41', '2018-06-29-23-34-41', '2018-06-29-20-46-58', '2018-06-29-19-41-53', '2018-06-29-07-03-19', '2018-06-29-02-51-42', '2018-06-28-14-02-57', '2018-06-28-09-52-29', '2018-06-28-08-51-30']},
    'ParisNLP-18' => {'city' => 'Paris', 'printname' => 'ParisNLP'},
    'CEA-LIST' => {'city' => 'Paris', 'printname' => 'CEA LIST'},
    'LATTICE-18' => {'city' => 'Paris', 'printname' => 'LATTICE'},
    'conll18-baseline' => {'city' => 'Praha', 'printname' => 'BASELINE UDPipe 1.2'},
    'UDPipe-Future' => {'city' => 'Praha', 'printname' => 'UDPipe Future'},
    'CUNI-x-ling' => {'city' => 'Praha', 'printname' => 'CUNI x-ling'},
    'ICS-PAS' => {'city' => 'Warszawa', 'printname' => 'ICS PAS'},
    'Uppsala-18' => {'city' => 'Uppsala', 'printname' => 'Uppsala'},
    'TurkuNLP-18' => {'city' => 'Turku', 'printname' => 'TurkuNLP'},
#    'TurkuNLP-18' => {'city' => 'Turku', 'printname' => 'TurkuNLP', 'primary' => 'software1', 'takeruns' => ['2018-07-01-20-49-29', '2018-07-01-12-19-31', '2018-06-28-19-30-38', '2018-06-28-09-42-55', '2018-06-26-00-03-07']}, # evaluator runs: 2018-07-01-21-02-28, 2018-07-01-12-37-54, 2018-06-29-00-07-40, 2018-06-28-18-59-56, 2018-06-28-00-46-12
    'NLP-Cube' => {'city' => 'București'},
    'SagTeam' => {'city' => 'Moskva', 'withdraw' => 1},
    'ArmParser' => {'city' => 'Yerevan'},
    'BOUN' => {'city' => 'İstanbul'},
    'KParse' => {'city' => 'İstanbul', 'primary' => 'software1', 'takeruns' => ['2018-07-01-15-05-56', '2018-07-01-09-16-07', '2018-06-29-00-50-02']}, # evaluator runs: 2018-07-01-14-44-14, 2018-07-01-06-15-52, 2018-07-01-18-39-38
    'SParse' => {'city' => 'İstanbul'},
    'ONLP-lab' => {'city' => "Ra'anana", 'printname' => 'ONLP lab'},
    'HUJI' => {'city' => 'Yerushalayim'},
    'SLT-Interactions' => {'city' => 'Bengaluru'},
    'HIT-SCIR-18' => {'city' => 'Harbin', 'printname' => 'HIT-SCIR'},
    'AntNLP' => {'city' => 'Shanghai'},
    'Fudan' => {'city' => 'Shanghai', 'primary' => 'software5'},
    'LeisureX' => {'city' => 'Shanghai'},
    'Phoenix' => {'city' => 'Shanghai'},
    'UniMelb' => {'city' => 'Melbourne', 'primary' => 'software1', 'takeruns' => ['2018-06-28-17-22-34']} # evaluator run 2018-06-29-01-28-54
);
# Some teams have multiple virtual machines.
my %secondary =
(
    'IBM-NY2' => 'IBM-NY',
    'IBM-NY3' => 'IBM-NY',
    'Stanford-182' => 'Stanford-18'
);



# The output of the test runs is mounted in the master VM at this point:
my $testpath = detect_input_path();
print STDERR ("Path with runs = $testpath\n");
die("The path does not exist") if (! -d $testpath);
my @results = read_runs($testpath);
# Throw away all evaluation runs that started after we published the official results.
unless ($allresults || $bestresults)
{
    my $n_results_total = scalar(@results);
    @results = grep {$_->{erun} lt $deadline} (@results);
    my $n_results_official = scalar(@results);
    my $n_results_removed = $n_results_total - $n_results_official;
    if ($n_results_removed > 0)
    {
        print STDERR ("WARNING: Ignoring $n_results_removed evaluation runs that were started after we published the official results ($deadline).\n");
    }
}
# Create a map from system run ids to corresponding evaluation runs.
my %srun2erun;
foreach my $result (@results)
{
    my $srun = $result->{srun};
    # There may be multiple evaluation runs of the same system runs. Take the first, discard the others.
    unless (exists($srun2erun{$srun}))
    {
        $srun2erun{$srun} = $result;
    }
}
# Combine runs where applicable.
foreach my $team (sort(keys(%teams))) # sorting just because of debugging messages
{
    if (!exists($teams{$team}{takeruns}))
    {
        take_all_runs_of_one_system($team, @results);
    }
    else
    {
        my $n = scalar(@{$teams{$team}{takeruns}});
        print STDERR ("For team $team there is hard-coded $teams{$team}{primary} as primary, $n runs listed to look for.\n\n");
    }
    if (exists($teams{$team}{takeruns}) && scalar(@{$teams{$team}{takeruns}}) > 1)
    {
        my $combination = combine_runs($teams{$team}{takeruns}, \%srun2erun, \@alltbk);
        push(@results, $combination);
    }
}
# If we know what is the primary system of a team, remove results of other systems.
# If we know what is the single final run of a team, remove results of other runs.
unless ($allresults || $bestresults)
{
    @results = remove_secondary_runs(@results);
}
if ($copy_filtered_eruns)
{
    copy_erun_files($testpath, $copy_filtered_eruns, @results);
}
if ($copy_conllu_files)
{
    copy_srun_files($testpath, $copy_conllu_files, @results);
}
add_team_printnames(\@results);
# Adding averages should happen after combining runs because at present the combining code looks at all LAS-F1 entries that are not 'total-LAS-F1'
# (in the future they should rather look into the @alltbk list).
# Compute additional averages if they are required.
if ($metric =~ m/^(pertreebank|alltreebanks|bigtreebanks|smalltreebanks|pudtreebanks|surtreebanks)-(.+-F1)$/)
{
    my $selection = $1;
    my $coremetric = $2;
    # In the paper, some scores are displayed in one table together with others, so we must average other metrics as well.
    # LAS => LAS & MLAS & BLEX
    # Words => Tokens & Words & Sentences
    # UPOS => UPOS & UFeats & Lemmas
    my @metrics = ($coremetric);
    if ($coremetric eq 'LAS-F1')
    {
        @metrics = ('LAS-F1', 'MLAS-F1', 'BLEX-F1');
    }
    elsif ($coremetric eq 'Words-F1')
    {
        @metrics = ('Tokens-F1', 'Words-F1', 'Sentences-F1');
    }
    elsif ($coremetric eq 'UPOS-F1')
    {
        @metrics = ('UPOS-F1', 'UFeats-F1', 'Lemmas-F1');
    }
    foreach my $metric (@metrics)
    {
        if ($selection =~ m/^(pertreebank|alltreebanks)$/)
        {
            # Sanity check: If we compute average LAS over all treebanks we should replicate the pre-existing total-LAS-F1 score.
            add_average("alltreebanks-$metric", $metric, \@alltbk, \@results);
        }
        if ($selection =~ m/^(pertreebank|bigtreebanks)$/)
        {
            add_average("bigtreebanks-$metric", $metric, \@bigtbk, \@results);
        }
        if ($selection =~ m/^(pertreebank|smalltreebanks)$/)
        {
            add_average("smalltreebanks-$metric", $metric, \@smltbk, \@results);
        }
        if ($selection =~ m/^(pertreebank|pudtreebanks)$/)
        {
            add_average("pudtreebanks-$metric", $metric, \@pudtbk, \@results);
        }
        if ($selection =~ m/^(pertreebank|surtreebanks)$/)
        {
            add_average("surtreebanks-$metric", $metric, \@surtbk, \@results);
        }
    }
}
# Print the results.
# Print them in MarkDown if the long, per-treebank breakdown is requested.
if ($metric =~ m/^pertreebank-(BLEX-F1|MLAS-F1|CLAS-F1|LAS-F1|UAS-F1|UPOS-F1|XPOS-F1|U?Feats-F1|AllTags-F1|Lemmas-F1|Sentences-F1|Words-F1|Tokens-F1)$/)
{
    my $coremetric = $1;
    my $bigexpl = "Macro-average $coremetric of the ".scalar(@bigtbk)." big treebanks: ".join(', ', @bigtbk).'. '.
        "These are the treebanks that have development data available, hence these results should be comparable ".
        "to the performance of the systems on the development data.";
    my $pudexpl = "Macro-average $coremetric of the ".scalar(@pudtbk)." PUD treebanks (additional parallel test sets): ".join(', ', @pudtbk).'. '.
        "These are languages for which there exists at least one big training treebank. ".
        "However, these test sets have been produced separately and their domain may differ.";
    my $smallexpl = "Macro-average $coremetric of the ".scalar(@smltbk)." small treebanks: ".join(', ', @smltbk).'. '.
        "These treebanks lack development data but still have some reasonable training data.";
    my $surexpl = "Macro-average $coremetric of the ".scalar(@surtbk)." low-resource language treebanks: ".join(', ', @surtbk).'. '.
        "These languages have tiny sample data, or no training data at all.";
    print_table_markdown("## All treebanks", "alltreebanks-$coremetric", @results);
    print_table_markdown("## Big treebanks only\n\n$bigexpl", "bigtreebanks-$coremetric", @results);
    print_table_markdown("## PUD treebanks only\n\n$pudexpl", "pudtreebanks-$coremetric", @results);
    print_table_markdown("## Small treebanks only\n\n$smallexpl", "smalltreebanks-$coremetric", @results);
    print_table_markdown("## Low-resource languages only\n\n$surexpl", "surtreebanks-$coremetric", @results);
    print("## Per treebank $coremetric\n\n\n\n");
    foreach my $treebank (sort(@alltbk))
    {
        print_table_markdown("### $treebank", "$treebank-$coremetric", @results);
    }
}
elsif ($metric =~ m/^ranktreebanks-(BLEX-F1|MLAS-F1|CLAS-F1|LAS-F1|UAS-F1|UPOS-F1|XPOS-F1|U?Feats-F1|AllTags-F1|Lemmas-F1|Sentences-F1|Words-F1|Tokens-F1)$/)
{
    my $coremetric = $1;
    my $treebanks = rank_treebanks(\@alltbk, \@results, $coremetric);
    my @keys = sort {$treebanks->{$b}{"max-$coremetric"} <=> $treebanks->{$a}{"max-$coremetric"}} (keys(%{$treebanks}));
    my $i = 0;
    my $max_teamname = get_max_length(('maxteam', map {$treebanks->{$_}{"teammax-$coremetric"}} (@keys)));
    my $maxteam_heading = 'maxteam' . (' ' x ($max_teamname-7));
    if ($format eq 'markdown')
    {
        my $printmetric = $coremetric;
        $printmetric =~ s/-F1$//;
        print("## Treebanks ranked by best $printmetric\n\n");
        print("<pre>\n");
    }
    print("                      max     $maxteam_heading   avg     stdev\n");
    foreach my $key (@keys)
    {
        $i++;
        my $tbk = $key;
        $tbk .= ' ' x (13-length($tbk));
        my $team = $treebanks->{$key}{"teammax-$coremetric"};
        $team .= ' ' x ($max_teamname-length($team));
        printf("%2d.   %s   %5.2f   %s   %5.2f   ±%5.2f\n", $i, $tbk, $treebanks->{$key}{"max-$coremetric"}, $team, $treebanks->{$key}{"avg-$coremetric"}, sqrt($treebanks->{$key}{"var-$coremetric"}));
    }
    if ($format eq 'markdown')
    {
        print("</pre>\n\n\n\n");
    }
}
elsif ($metric eq 'ranktreebanks-both' && $format eq 'latex')
{
    my $treebanks = rank_treebanks(\@alltbk, \@results, 'LAS-F1');
    my $ctreebanks = rank_treebanks(\@alltbk, \@results, 'MLAS-F1');
    my $wtreebanks = rank_treebanks(\@alltbk, \@results, 'Words-F1');
    my $streebanks = rank_treebanks(\@alltbk, \@results, 'Sentences-F1');
    my @keys = sort {$treebanks->{$b}{'max-LAS-F1'} <=> $treebanks->{$a}{'max-LAS-F1'}} (keys(%{$treebanks}));
    my @ckeys = sort {$ctreebanks->{$b}{'max-MLAS-F1'} <=> $ctreebanks->{$a}{'max-MLAS-F1'}} (keys(%{$ctreebanks}));
    my $i = 0;
    foreach my $key (@ckeys)
    {
        $i++;
        $ctreebanks->{$key}{crank} = $i;
    }
    $i = 0;
    print("                      max     maxteam    avg     stdev\n");
    print("\\begin{table}[!ht]\n");
    print("\\begin{center}\n");
    print("\\setlength\\tabcolsep{3pt} % default value: 6pt\n");
    print("\\begin{tabular}{|r l|r|r|l");
    print("|}\n");
    print("\\hline & \\bf Treebank & \\bf LAS F\$_1\$ & \\bf MLAS F\$_1\$ & \\bf Best system & \\bf Words & \\bf Sent \\\\\\hline\n");
    my $last_clas;
    foreach my $key (@keys)
    {
        $i++;
        my $tbk = $key;
        $tbk =~ s/_/\\_/g;
        $tbk .= ' ' x (13-length($tbk));
        my $clas = $ctreebanks->{$key}{'max-MLAS-F1'};
        my $more = defined($last_clas) && $clas > $last_clas;
        $last_clas = $clas;
        $clas = sprintf($more ? "\\textbf{%2d. %5.2f}" : "%2d. %5.2f", $ctreebanks->{$key}{crank}, $clas);
        my $team = $treebanks->{$key}{'teammax-LAS-F1'};
        $team .= ' / '.$ctreebanks->{$key}{'teammax-MLAS-F1'} if ($ctreebanks->{$key}{'teammax-MLAS-F1'} ne $treebanks->{$key}{'teammax-LAS-F1'});
        printf("%2d. & %s & %5.2f & %s & %s & %5.2f & %5.2f \\\\\n", $i, $tbk, $treebanks->{$key}{'max-LAS-F1'}, $clas, $team, $wtreebanks->{$key}{'max-Words-F1'}, $streebanks->{$key}{'max-Sentences-F1'});
    }
    print("\\end{tabular}\n");
    print("\\end{center}\n");
    print("\\caption{\\label{tab:ranktreebanks}Treebank ranking.}\n");
    print("\\end{table}\n");
}
else
{
    # Sanity check: If we compute average LAS over all treebanks we should replicate the pre-existing total-LAS-F1 score.
    if ($metric =~ m/^alltreebanks-(.+-F1)$/)
    {
        my $coremetric = $1;
        print("Macro-average $coremetric of all ", scalar(@alltbk), ' treebanks: ', join(', ', @alltbk), "\n");
    }
    elsif ($metric =~ m/^bigtreebanks-(.+-F1)$/)
    {
        my $coremetric = $1;
        print("Macro-average $coremetric of the ", scalar(@bigtbk), ' big treebanks: ', join(', ', @bigtbk), "\n");
    }
    elsif ($metric =~ m/^smalltreebanks-(.+-F1)$/)
    {
        my $coremetric = $1;
        print("Macro-average $coremetric of the ", scalar(@smltbk), ' small treebanks: ', join(', ', @smltbk), "\n");
    }
    elsif ($metric =~ m/^pudtreebanks-(.+-F1)$/)
    {
        my $coremetric = $1;
        print("Macro-average $coremetric of the ", scalar(@pudtbk), ' PUD treebanks (additional parallel test sets): ', join(', ', @pudtbk), "\n");
    }
    elsif ($metric =~ m/^surtreebanks-(.+-F1)$/)
    {
        my $coremetric = $1;
        print("Macro-average $coremetric of the ", scalar(@surtbk), ' surprise language treebanks: ', join(', ', @surtbk), "\n");
    }
    if ($format eq 'latex')
    {
        print_table_latex($metric, @results);
    }
    elsif ($format eq 'markdown')
    {
        my $printmetric = $metric;
        $printmetric =~ s/-F1$//;
        $printmetric =~ s/^total-//;
        my $heading = "## $printmetric Ranking";
        if ($bestresults)
        {
            $heading = "## Best run per team ($printmetric)";
        }
        elsif ($allresults)
        {
            $heading = "## All runs ($printmetric)";
        }
        print_table_markdown($heading, $metric, @results);
    }
    else
    {
        print_table($metric, @results);
    }
}



#------------------------------------------------------------------------------
# There are several hard-coded paths so that we do not have to type the path
# every time we invoke the script. The hard-coded paths are in global
# variables. This function tests the paths for existence and returns the first
# one that exists. The global variables are set in the beginning of the script.
#------------------------------------------------------------------------------
sub detect_input_path
{
    my $testpath;
    # Are we running on Dan's laptop?
    if (-d $testpath_dan)
    {
        $testpath = $testpath_dan;
    }
    # Are we running in the master virtual machine on TIRA?
    elsif (-d $testpath_tira)
    {
        $testpath = $testpath_tira;
    }
    # OK, we must be running on ÚFAL network then. There are multiple versions of the test runs from TIRA.
    else
    {
        # Supposing all paths are reachable, prefer the one we are currently in.
        ###!!! At present there is just one folder at ÚFAL and it does not contain the string 'test-runs'.
        my $pwd = `pwd`;
        if (-d $testpath_ufal1)
        {
            $testpath = $testpath_ufal1;
        }
#        elsif (-d $testpath_ufal2 && $pwd =~ m/test-runs-v2/)
#        {
#            $testpath = $testpath_ufal2;
#        }
#        elsif (-d $testpath_ufal3 && $pwd =~ m/test-runs-v3/)
#        {
#            $testpath = $testpath_ufal3;
#        }
        else
        {
            $testpath = $testpath_ufal1;
        }
    }
    return $testpath;
}



#------------------------------------------------------------------------------
# Reads output of evaluation runs from a specified folder.
#------------------------------------------------------------------------------
sub read_runs
{
    my $testpath = shift;
    my @teams = dzsys::get_subfolders($testpath);
    my @results;
    foreach my $team (@teams)
    {
        # Merge multiple virtual machines of one team (reads global hash %secondary).
        my $uniqueteam = $team;
        if (exists($secondary{$team}))
        {
            $uniqueteam = $secondary{$team};
        }
        next if ($teams{$uniqueteam}{withdraw});
        my $teampath = "$testpath/$team";
        my @runs = dzsys::get_subfolders($teampath);
        foreach my $run (@runs)
        {
            my $runpath = "$teampath/$run";
            if (-f "$runpath/output/evaluation.prototext")
            {
                my $hash = read_prototext("$runpath/output/evaluation.prototext");
                if ($hash->{'total-LAS-F1'} > 0)
                {
                    $hash->{team} = $uniqueteam;
                    $hash->{erun} = $run;
                    # Get the identifier of the evaluated ("input") run.
                    my $irunline;
                    open(RUN, "$runpath/run.prototext") or die("Cannot read $runpath/run.prototext: $!");
                    while(<RUN>)
                    {
                        if (m/inputRun/)
                        {
                            $irunline = $_;
                            last;
                        }
                    }
                    close(RUN);
                    if ($irunline =~ m/inputRun:\s*"([^"]*)"/) # "
                    {
                        $hash->{srun} = $1;
                        # Get the identifier of the software that generated the input run.
                        # If we work offline with the filtered erun data, assume that it is the primary software
                        # (because we do not have a copy of the srun and cannot look at the software id).
                        if (-f "$teampath/$hash->{srun}/run.prototext")
                        {
                            my $swline = `grep softwareId $teampath/$hash->{srun}/run.prototext`;
                            if ($swline =~ m/softwareId:\s*"([^"]*)"/) # "
                            {
                                $hash->{software} = $1;
                            }
                            # Read information about system run time.
                            my $rtline = `grep elapsed $teampath/$hash->{srun}/runtime.txt`;
                            if ($rtline =~ m/ ([0-9:.]+)elapsed/)
                            {
                                my @parts = split(/:/, $1);
                                unshift(@parts, 0) if (scalar(@parts) == 2);
                                if (scalar(@parts) == 3)
                                {
                                    $hash->{runtime} = $parts[0] + $parts[1]/60 + $parts[2]/3600;
                                }
                                else
                                {
                                    die("Cannot parse runtime line '$rtline'");
                                }
                            }
                        }
                        elsif (exists($teams{$uniqueteam}{primary}))
                        {
                            $hash->{software} = $teams{$uniqueteam}{primary};
                        }
                    }
                    # For every test treebank with non-zero LAS remember the path to the system-output CoNLL-U file.
                    # We may later combine files from different runs so we need to save the path per file, not per run.
                    foreach my $treebank (@alltbk)
                    {
                        my $tbklaskey = "$treebank-LAS-F1";
                        if (exists($hash->{$tbklaskey}) && $hash->{$tbklaskey} > 0)
                        {
                            $hash->{"$treebank-path"} = "$teampath/$hash->{srun}/output/$treebank.conllu";
                        }
                    }
                    push(@results, $hash);
                }
            }
        }
    }
    return @results;
}



#------------------------------------------------------------------------------
# Parses prototext output from Milan's evaluator. Stores the key-value pairs in
# a hash.
#------------------------------------------------------------------------------
sub read_prototext
{
    # Path to the prototext file:
    my $path = shift;
    open(FILE, $path) or die("Cannot read $path: $!");
    my %hash;
    my $key;
    while(<FILE>)
    {
        if (m/key:\s*"([^"]*)"/) # "
        {
            $key = $1;
        }
        elsif (m/value:\s*"([^"]*)"/) # "
        {
            my $value = $1;
            if (defined($key))
            {
                $hash{$key} = $value;
                $key = undef;
            }
        }
    }
    close(FILE);
    return \%hash;
}



#------------------------------------------------------------------------------
# Combines evaluations of multiple system runs and creates a new virtual
# evaluation run. Runs are considered in the order in which they appear on the
# input list. For every test set, the first output with non-zero -LAS-F1 score
# is taken, and the subsequent outputs (if any) are ignored.
#------------------------------------------------------------------------------
sub combine_runs
{
    my $srunids = shift; # ref to list of system run ids
    my $srun2erun = shift; # ref to hash of system-run-to-evaluation-run mapping
    my $alltbk = shift; # ref to list of all test treebanks
    if (scalar(@{$srunids}) < 2)
    {
        print STDERR ("Warning: Attempting to combine less than 2 runs. Will do nothing.\n");
        return;
    }
    # Find evaluation runs that correspond to the system runs.
    my @eruns;
    foreach my $srun (@{$srunids})
    {
        if (exists($srun2erun->{$srun}))
        {
            push(@eruns, $srun2erun->{$srun});
        }
        else
        {
            print STDERR ("Warning: No evaluation run for system run $srun.\n");
        }
    }
    if (scalar(@eruns) <= 1)
    {
        print STDERR ("Warning: Found only ", scalar(@eruns), " evaluation runs for the ", scalar(@{$srunids}), " system runs to be combined. Giving up.\n\n");
        return;
    }
    print STDERR ("Combining sruns: ", join(' + ', @{$srunids}), " ($eruns[0]{team})\n");
    print STDERR ("Combining eruns: ", join(' + ', map {$_->{erun}} (@eruns)), " ($eruns[0]{team})\n");
    # Combine the evaluations.
    ###!!! Note that we currently do not check that the combined runs belong to the same software.
    ###!!! In fact we will even combine runs from different teams (actually different VMs of one team).
    my %combination =
    (
        'team'     => $eruns[0]{team},
        'software' => $eruns[0]{software},
        'srun'     => join('+', @{$srunids}),
        'erun'     => join('+', map {$_->{erun}} (@eruns))
    );
    my %sum;
    my @what_from_where; # statistics for debugging
    foreach my $erun (@eruns)
    {
        my @keys = sort(keys(%{$erun}));
        #my @sets = map {my $x = $_; $x =~ s/-LAS-F1$//; $x} (grep {m/^(.+)-LAS-F1$/ && $1 ne 'total'} (@keys));
        my @sets = @{$alltbk};
        my %from_here = ('erun' => $erun->{erun}, 'sets' => []);
        push(@what_from_where, \%from_here);
        foreach my $set (@sets)
        {
            if ((!exists($combination{"$set-LAS-F1"}) || $combination{"$set-LAS-F1"} == 0) && exists($erun->{"$set-LAS-F1"}) && $erun->{"$set-LAS-F1"} > 0)
            {
                push(@{$from_here{sets}}, $set);
                # Copy all values pertaining to $set to the combined evaluation.
                foreach my $key (@keys)
                {
                    if ($key =~ m/^$set-(.+)$/)
                    {
                        my $m = $1;
                        #print STDERR ("COPY $key ");
                        $combination{$key} = $erun->{$key};
                        $sum{$m} += $erun->{$key};
                    }
                }
            }
        }
        $from_here{nsets} = scalar(@{$from_here{sets}});
        $from_here{jsets} = join(', ', @{$from_here{sets}});
        $combination{runtime} += $erun->{runtime};
    }
    print STDERR ("\tTaking ", join(";\n\t       ", map {"$_->{nsets} files from $_->{erun} ($_->{jsets})"} (@what_from_where)), "\n\n");
    # Recompute the macro average scores.
    # We cannot take the number of sets from scalar(grep {m/^(.+)-LAS-F1$/ && $1 ne 'total'} (keys(%combination)));
    # If the system failed to produce some of the outputs, we would be averaging only the good outputs!
    my $nsets = $ntreebanks; ###!!! GLOBAL VARIABLE; THIS MAY FAIL IF WE USE THIS SCRIPT FOR ANOTHER TASK IN THE FUTURE.
    die if ($nsets < 1);
    foreach my $key (keys(%sum))
    {
        $combination{"total-$key"} = $sum{$key}/$nsets;
    }
    return \%combination;
}



#------------------------------------------------------------------------------
# If there is no manually set list of runs to take, take all runs of one
# software. Preferably software1.
#------------------------------------------------------------------------------
sub take_all_runs_of_one_system
{
    my $team = shift;
    my @results = @_;
    # Keep only runs of the given team.
    @results = grep {$_->{team} eq $team} (@results);
    my $n_runs_team = scalar(@results);
    return if ($n_runs_team==0);
    # Order the runs chronologically, most recent run first.
    @results = sort {$b->{srun} cmp $a->{srun}} (@results);
    my $primary = 'software1';
    if (exists($teams{$team}{primary}))
    {
        $primary = $teams{$team}{primary};
    }
    # If there are no runs of the primary software but there are runs of other software,
    # select the software of the most recent run as primary.
    my @presults;
    if ($primary eq 'any')
    {
        @presults = @results;
    }
    else
    {
        @presults = grep {$_->{software} eq $primary} (@results);
    }
    my $n_runs_team_primary = scalar(@presults);
    if ($n_runs_team > 0 && $n_runs_team_primary == 0)
    {
        print STDERR ("WARNING: team $team has $n_runs_team runs total but no runs of the primary $primary!\n");
        $primary = $results[0]{software};
        print STDERR ("WARNING: changing primary to $primary.\n");
        $teams{$team}{primary} = $primary;
        @presults = grep {$_->{software} eq $primary} (@results);
        $n_runs_team_primary = scalar(@presults);
    }
    # Set the takeruns attribute of the team to the list of names of runs we just found.
    print STDERR ("For team $team setting $primary as primary, found $n_runs_team_primary runs.\n\n");
    my @sruns = map {$_->{srun}} (@presults);
    $teams{$team}{primary} = $primary;
    $teams{$team}{takeruns} = \@sruns;
}



#------------------------------------------------------------------------------
# If we know what is the primary system of a team, remove results of other systems.
# If we know what is the single final run of a team, remove results of other runs.
#------------------------------------------------------------------------------
sub remove_secondary_runs
{
    # This function reads the global hash %teams.
    my @results = @_;
    foreach my $team (keys(%teams))
    {
        if ($teams{$team}{withdraw})
        {
            # Remove all runs of all systems of the team.
            @results = grep {$_->{team} ne $team} (@results);
        }
        else
        {
            if (exists($teams{$team}{primary}))
            {
                my $primary = $teams{$team}{primary};
                # Remove all runs of secondary systems of this team.
                unless ($primary eq 'any')
                {
                    @results = grep {$_->{team} ne $team || $_->{software} eq $primary} (@results);
                    # Sanity check: there must be at least one run of the primary system.
                    if (!grep {$_->{team} eq $team && $_->{software} eq $primary} (@results))
                    {
                        die("Team '$team': did not find any runs of the primary system '$primary'");
                    }
                }
            }
            if (exists($teams{$team}{takeruns}))
            {
                # Remove all runs of the system except the one marked as final (it is not necessarily the last one time-wise).
                my $lookforrun = join('+', @{$teams{$team}{takeruns}});
                @results = grep {$_->{team} ne $team || $_->{srun} eq $lookforrun} (@results);
                # Sanity check: if we defined the run we want to take, we assumed it would exist.
                if (!grep {$_->{team} eq $team && $_->{srun} eq $lookforrun} (@results))
                {
                    die("Team '$team', primary system '$primary': did not find requested final run '$lookforrun'");
                }
            }
        }
    }
    return @results;
}



#------------------------------------------------------------------------------
# Copies the important files used as input for this script to a new folder.
# This way we can filter primary final runs, then copy them for processing
# offline, without having to carry all the heavy-weight CoNLL-U outputs of
# system runs.
#------------------------------------------------------------------------------
sub copy_erun_files
{
    my $srcpath = shift;
    my $tgtpath = shift;
    my @eruns = @_;
    foreach my $erun (@eruns)
    {
        # It can be a combined erun that does not exist in the source path!
        my @partruns = split(/\+/, $erun->{erun});
        foreach my $partrun (@partruns)
        {
            my $srcrunpath = "$srcpath/$erun->{team}/$partrun";
            my $tgtrunpath = "$tgtpath/$erun->{team}/$partrun";
            ###!!! The CLCL2 and fbaml2 virtual machines are secondary for the CLCL and fbaml teams. Watch for confused paths.
            if (!-d $srcrunpath)
            {
                $srcrunpath = "$srcpath/$erun->{team}2/$partrun";
                if (!-d $srcrunpath)
                {
                    die("Cannot find $srcrunpath");
                }
            }
            system("mkdir -p $tgtrunpath/output");
            die("Cannot create $tgtrunpath/output") if (!-d "$tgtrunpath/output");
            system("cp $srcrunpath/run.prototext $tgtrunpath");
            system("cp $srcrunpath/output/evaluation.prototext $tgtrunpath/output");
        }
    }
}



#------------------------------------------------------------------------------
# Copies the system-output CoNLL-U files to a new folder. Can be useful after
# filtering and combining the runs that are really evaluated.
#------------------------------------------------------------------------------
sub copy_srun_files
{
    my $srcpath = shift;
    my $tgtpath = shift;
    my @runs = @_;
    # Hash the paths in order to remove duplicates (multiple eruns per srun).
    my %paths;
    foreach my $run (@results)
    {
        foreach my $treebank (@alltbk)
        {
            if (exists($run->{"$treebank-LAS-F1"}) && $run->{"$treebank-LAS-F1"} > 0 && defined($run->{"$treebank-path"}))
            {
                $paths{$run->{"$treebank-path"}}++;
            }
        }
    }
    my @paths = sort(keys(%paths));
    foreach my $source (@paths)
    {
        # Option 1: The target folder has the same subfolder structure as on Tira, just some files are missing.
        #           This is useful if we intend to process the copy by this script again.
        # Option 2: There is just one set of CoNLL-U files per system, and we omit the folders of individual runs.
        #           This is useful if we want to publish the set of system outputs that were officially ranked.
        my $target = $source;
        $target =~ s:^$srcpath:$tgtpath:;
        # Every path involves a single CoNLL-U file.
        # If the source files are from a secondary virtual machine of a team,
        # copy them under the primary name of the team.
        if ($target =~ m:^$tgtpath/([^/]+)/: && exists($secondary{$1}))
        {
            $target =~ s:^$tgtpath/([^/]+)/:$tgtpath/$secondary{$1}/:;
        }
        if(0) # option 1
        {
            # No action required. We already have the target path, e.g.:
            # cp system-runs-2018/conll18-ud-test-2018-05-06-downloaded-2018-07-04-02-42/Fudan/2018-07-01-14-14-00/output/sv_talbanken.conllu \
            #    system-runs-2018/filtered/Fudan/2018-07-01-14-14-00/output/sv_talbanken.conllu
        }
        else # option 2
        {
            # Simplify the target path. Remove two levels specific to a run.
            $target =~ s:/\d+-\d+-\d+-\d+-\d+-\d+/output(/[a-z_]+\.conllu)$:$1:;
            # The assumption is that the runs have already been filtered and there is at most one CoNLL-U file per treebank.
            # If the target file already exists, something went wrong and we are trying to copy it from multiple runs.
            if (-e $target)
            {
                die("The target file '$target' exists. Perhaps we are trying to copy it from multiple runs?");
            }
        }
        my $targetfolder = $target;
        $targetfolder =~ s:/[^/]+$::;
        system("mkdir -p $targetfolder");
        die("Cannot create $targetfolder") if (!-d "$targetfolder");
        print STDERR ("cp $source $target\n");
        system("cp $source $target");
        # The files on Tira have unusual permissions 750. Change them to 644.
        chmod(0644, $target);
    }
    return @paths;
}



#------------------------------------------------------------------------------
# For every run in a list, adds the printable team name to the hash.
#------------------------------------------------------------------------------
sub add_team_printnames
{
    my $runs = shift;
    foreach my $result (@{$runs})
    {
        $result->{uniqueteam} = $result->{team};
        $result->{uniqueteam} = $secondary{$result->{uniqueteam}} if (exists($secondary{$result->{uniqueteam}}));
        $result->{printname} = exists($teams{$result->{uniqueteam}}{printname}) ? $teams{$result->{uniqueteam}}{printname} : $result->{uniqueteam};
    }
}



#------------------------------------------------------------------------------
# For every run in a list, computes a given average score and adds it to the
# hash of scores of the run.
#------------------------------------------------------------------------------
sub add_average
{
    # Name of the average metric to be added, e.g. "Surprise-languages-LAS-F1".
    my $tgtname = shift;
    # Name of metric to average, e.g. "LAS-F1".
    my $srcname = shift;
    # Reference to list of treebanks to include, e.g. ['bxr', 'hsb', 'kmr', 'sme'].
    my $treebanks = shift;
    # Reference to list of runs to process.
    my $runs = shift;
    my $n = scalar(@{$treebanks});
    die ("Cannot average over zero treebanks") if ($n==0);
    # Hash the selected treebank codes for quick lookup.
    my %htbks;
    foreach my $treebank (@{$treebanks})
    {
        die ("Duplicate treebank code '$treebank' would skew the average") if (exists($htbks{$treebank}));
        $htbks{$treebank}++;
    }
    foreach my $run (@{$runs})
    {
        my @selection = grep {m/^([^-]+)-(.+)$/; exists($htbks{$1}) && $2 eq $srcname} (keys(%{$run}));
        my $sum = 0;
        foreach my $key (@selection)
        {
            $sum += $run->{$key};
        }
        # Round all averages to hundredths of percent. We want results that look the same in the output to really be equal numerically.
        $run->{$tgtname} = round($sum/$n);
    }
}



#------------------------------------------------------------------------------
# Rounds a number to the second decimal digit.
#------------------------------------------------------------------------------
sub round
{
    my $x = shift;
    return sprintf("%d", ($x*100)+0.5)/100;
}



#------------------------------------------------------------------------------
# Considering a given set of runs, finds the best scores per test treebank.
#------------------------------------------------------------------------------
sub rank_treebanks
{
    my $treebanks = shift; # array reference;
    my $runs = shift; # array reference
    my $metric = shift; # e.g. 'LAS-F1'
    $metric = 'LAS-F1' if (!defined($metric));
    my %treebanks;
    # Hash the treebank codes we want to rank.
    foreach my $treebank (@{$treebanks})
    {
        $treebanks{$treebank}{code} = $treebank;
    }
    # Look for treebank-metric pairs in the run results.
    foreach my $run (@{$runs})
    {
        my @keys = keys(%{$run});
        foreach my $key (@keys)
        {
            if ($key =~ m/^([^-]+)-(.+)$/ && exists($treebanks{$1}) && $2 eq $metric)
            {
                my $treebank = $1;
                if (!defined($treebanks{$treebank}{"max-$metric"}) || $run->{$key} > $treebanks{$treebank}{"max-$metric"})
                {
                    $treebanks{$treebank}{"max-$metric"} = $run->{$key};
                    $treebanks{$treebank}{"teammax-$metric"} = $run->{printname};
                }
                $treebanks{$treebank}{"sum-$metric"} += $run->{$key};
            }
        }
    }
    # Compute average score for each treebank.
    my $nruns = scalar(@{$runs});
    foreach my $treebank (keys(%treebanks))
    {
        $treebanks{$treebank}{"avg-$metric"} = $treebanks{$treebank}{"sum-$metric"} / $nruns;
    }
    # Compute variance.
    foreach my $run (@{$runs})
    {
        my @keys = keys(%{$run});
        foreach my $key (@keys)
        {
            if ($key =~ m/^([^-]+)-(.+)$/ && exists($treebanks{$1}) && $2 eq $metric)
            {
                my $treebank = $1;
                my $sigma2 = ($run->{$key} - $treebanks{$treebank}{"avg-$metric"}) ** 2;
                $treebanks{$treebank}{"var-$metric"} += ($sigma2 / $nruns);
            }
        }
    }
    return \%treebanks;
}



#------------------------------------------------------------------------------
# A wrapper that prints a table + its heading in MarkDown.
#------------------------------------------------------------------------------
sub print_table_markdown
{
    my $heading = shift; # including the level indication, e.g. "## Big treebanks"
    my $metric = shift;
    my @results = @_;
    print("$heading\n\n");
    # Tables of best/all runs are very wide because of listing the combined runs.
    if ($bestresults || $allresults)
    {
        print("<pre style='overflow-x:visible; width:950px;'>\n");
    }
    else
    {
        print("<pre>\n");
    }
    print_table($metric, @results);
    print("</pre>\n\n\n\n");
}



#------------------------------------------------------------------------------
# A wrapper that prints a table in LaTeX.
#------------------------------------------------------------------------------
sub print_table_latex
{
    my $metric = shift;
    my @results = @_;
    print("\\begin{table}[!ht]\n");
    print("\\begin{center}\n");
    print("\\setlength\\tabcolsep{3pt} % default value: 6pt\n");
    print("\\begin{tabular}{|r l|r");
    if ($metric eq 'total-LAS-F1')
    {
        print(' c');
    }
    print("|}\n");
    my $heading_metric = $metric;
    $heading_metric =~ s/^total-//;
    $heading_metric =~ s/-F1$//; # save space (column width)
    print("\\hline & \\bf Team & \\bf $heading_metric");
    if ($metric eq 'total-LAS-F1')
    {
        print(" & \\bf Files ");
    }
    print("\\\\\\hline\n");
    $format = 'latex'; ###!!! global
    print_table($metric, @results);
    print("\\end{tabular}\n");
    print("\\end{center}\n");
    print("\\caption{\\label{tab:$metric}$metric}\n");
    print("\\end{table}\n");
}



#------------------------------------------------------------------------------
# Prints the table of results of individual systems sorted by selected metric.
#------------------------------------------------------------------------------
sub print_table
{
    ###!!! Reads the global hash %secondary (mapping between primary and secondary virtual machine of two teams).
    my $metric = shift;
    my @results = @_;
    @results = sort {my $r = $b->{$metric} <=> $a->{$metric}; unless ($r) {$r = $a->{printname} cmp $b->{printname}} $r} (@results);
    my %teammap;
    my $i = 0;
    my $last_value;
    my $last_rank;
    my $last_mlas;
    my $last_blex;
    my $last_tokens;
    my $last_sentences;
    my $last_features;
    my $last_lemmas;
    foreach my $result (@results)
    {
        my $uniqueteam = $result->{uniqueteam};
        next if (!$allresults && exists($teammap{$uniqueteam}));
        $i++;
        # Hide rank if it should be same as the previous system.
        my $rank = '';
        if (!defined($last_value) || $result->{$metric} != $last_value)
        {
            $last_value = $result->{$metric};
            $last_rank = $i;
            $rank = $i.'.';
        }
        $teammap{$uniqueteam}++;
        my $name = $result->{printname};
        $name = substr($name.' ('.$teams{$result->{team}}{city}.')'.(' 'x38), 0, 40);
        my $software = ' ' x 9;
        if (exists($result->{software}))
        {
            $software = $result->{software};
            if ($result->{software} eq $teams{$uniqueteam}{primary})
            {
                $software .= '-P';
            }
        }
        # If we are showing the total metric, also report whether all partial numbers are non-zero.
        my $tag = '';
        if ($metric eq 'total-LAS-F1')
        {
            $tag = ' [OK]';
            my @keys = grep {m/-LAS-F1$/} (keys(%{$result}));
            my $n = scalar(@keys)-1; # subtracting the macro average
            if ($n < $ntreebanks) ###!!! GLOBAL VARIABLE
            {
                $tag = " [$n]";
            }
            else
            {
                foreach my $key (@keys)
                {
                    if ($key =~ m/-LAS-F1$/)
                    {
                        if ($result->{$key}==0)
                        {
                            $tag = ' [!!]';
                            last;
                        }
                    }
                }
            }
        }
        elsif ($metric eq 'runtime')
        {
            if ($result->{srun} =~ m/\+/)
            {
                $tag = ' [combined]';
            }
        }
        # Is this run the official final submission? It is not if:
        # - it uses other than primary software
        # - it uses primary software but it was later superceded by another run
        # - it was evaluated after we published the official results (the "$deadline")
        # - it is a combined run that uses one or more runs satisfying the above conditions
        my $final = '     ';
        if (exists($teams{$uniqueteam}{takeruns}))
        {
            # Is it a combined run?
            if($result->{srun} =~ m/\+/)
            {
                my @late_runs = grep {$_ ge $deadline} (split(/\+/, $result->{erun}));
                if(scalar(@{$teams{$uniqueteam}{takeruns}})>1 && scalar(@late_runs)==0)
                {
                    $final = 'Fin: ';
                }
            }
            # Standalone run must be listed in "takeruns" if it is final.
            elsif(scalar(@{$teams{$uniqueteam}{takeruns}})==1 && $result->{srun} eq $teams{$uniqueteam}{takeruns}[0])
            {
                $final = 'Fin: ';
            }
        }
        # Mark out-of-TIRA runs in the unofficial results.
        if (exists($teams{$uniqueteam}{ootruns}) && grep {$_ eq $result->{srun}} (@{$teams{$uniqueteam}{ootruns}}))
        {
            $final = 'OOT: ';
        }
        my $runs = '';
        if ($allresults || $bestresults)
        {
            $runs = "\t$final$result->{srun} => $result->{erun}";
            # Truncate long lists of combined runs.
            $runs = substr($runs, 0, 50).'...' if (length($runs) > 50);
        }
        my $numbersize = $metric eq 'runtime' ? 6 : 5;
        if ($format eq 'latex')
        {
            $name =~ s/–/--/g;
            $name =~ s/ç/{\\c{c}}/g;
            $name =~ s/İ/{\\.{I}}/g;
            $name =~ s/Ú/{\\'{U}}/g; #'
            $name =~ s/ñ/{\\~{n}}/g;
            $name =~ s/ü/{\\"{u}}/g; #"
            $name =~ s/ș/{\\c{s}}/g; # This is not correct because it results in cedilla, i.e., ş. Alternatively, we could leave the character unescaped.
            $name =~ s/è/{\\`{e}}/g; #`
            $name =~ s/de Compostela/d.C./;
            $name =~ s/^(BASELINE.+)\(Praha\)/$1/;
            $name = substr($name.(' 'x38), 0, 40);
            if ($metric eq 'total-LAS-F1')
            {
                printf("%4s & %s & %$numbersize.2f &%s \\\\\\hline\n", $rank, $name, $result->{$metric}, $tag);
            }
            # For subsets of treebanks, we publish one table with LAS, MLAS and BLEX combined.
            elsif ($metric =~ m/^(all|big|small|pud|sur)treebanks-LAS-F1$/)
            {
                my $subset = $1;
                $name =~ s/\(.+?\)//;
                $name = substr($name.(' 'x38), 0, 30);
                my $las = $result->{$metric};
                my $mlas = $result->{"${subset}treebanks-MLAS-F1"};
                my $blex = $result->{"${subset}treebanks-BLEX-F1"};
                # The table is ordered by LAS. If MLAS or BLEX is out of order, print them in bold.
                my $ooo_mlas = defined($last_mlas) && $mlas > $last_mlas ? "\\bf " : '';
                my $ooo_blex = defined($last_blex) && $blex > $last_blex ? "\\bf " : '';
                printf("%4s & %s & %5.2f & $ooo_mlas%5.2f & $ooo_blex%5.2f \\\\\\hline\n", $rank, $name, $las, $mlas, $blex);
                $last_mlas = $mlas;
                $last_blex = $blex;
            }
            # We publish one table with Tokens, Words and Sentences combined.
            elsif ($metric eq 'total-Words-F1')
            {
                $name =~ s/\(.+?\)//;
                $name = substr($name.(' 'x38), 0, 30);
                # The table is ordered by words. If tokens or sentences are out of order, print them in bold.
                my $ooo_tokens = defined($last_tokens) && $result->{'total-Tokens-F1'} > $last_tokens ? "\\bf " : '';
                my $ooo_sentences = defined($last_sentences) && $result->{'total-Sentences-F1'} > $last_sentences ? "\\bf " : '';
                printf("%4s & %s & $ooo_tokens%$numbersize.2f & %$numbersize.2f & $ooo_sentences%$numbersize.2f \\\\\\hline\n", $rank, $name, $result->{'total-Tokens-F1'}, $result->{$metric}, $result->{'total-Sentences-F1'});
                $last_tokens = $result->{'total-Tokens-F1'};
                $last_sentences = $result->{'total-Sentences-F1'};
            }
            # We publish one table with UPOS, features and lemmas.
            elsif ($metric eq 'total-UPOS-F1')
            {
                $name =~ s/\(.+?\)//;
                $name = substr($name.(' 'x38), 0, 30);
                my $lemmas = $result->{'total-Lemmas-F1'};
                my $upos = $result->{'total-UPOS-F1'};
                my $xpos = $result->{'total-XPOS-F1'};
                my $feat = $result->{'total-UFeats-F1'};
                my $alltags = $result->{'total-AllTags-F1'}; # Includes XPOS, which many systems ignore. I don't know if it includes lemmas.
                my $ooo_features = defined($last_features) && $feat > $last_features ? "\\bf " : '';
                my $ooo_lemmas = defined($last_lemmas) && $lemmas > $last_lemmas ? "\\bf " : '';
                printf("%4s & %s & %5.2f & $ooo_features%5.2f & $ooo_lemmas%5.2f \\\\\\hline\n", $rank, $name, $upos, $feat, $lemmas);
                $last_features = $feat;
                $last_lemmas = $lemmas;
            }
            else
            {
                printf("%4s & %s & %$numbersize.2f \\\\\\hline\n", $rank, $name, $result->{$metric});
            }
        }
        else
        {
            printf("%4s %s\t%s\t%$numbersize.2f%s%s\n", $rank, $name, $software, $result->{$metric}, $tag, $runs);
        }
    }
}



#------------------------------------------------------------------------------
# Figure out the necessary width of a table column. Get the maximum length of
# a string in a sequence of strings.
#------------------------------------------------------------------------------
sub get_max_length
{
    my @strings = @_;
    my $max = 0;
    foreach my $string (@strings)
    {
        my $l = length($string);
        $max = $l if ($l > $max);
    }
    return $max;
}



#------------------------------------------------------------------------------
# Finds out the time of the last modification of a file, in seconds since the
# beginning of the system epoch (for many systems it is 1.1.1970 0:00:00 UTC).
#------------------------------------------------------------------------------
sub get_file_time
{
    my $file = shift; # path to file
    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat($file);
    # It is not clear to me whether I should use ctime (inode change time) or mtime (last modify time).
    # Convert epoch-based seconds to universally valid time values.
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday) = gmtime($mtime);
    my $timestamp = sprintf("%04d-%02d-%02d-%02d-%02d-%02d", $year, $mon+1, $mday, $hour, $min, $sec);
    return $timestamp;
}
