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
my $copy_filtered_eruns = 0;
my $copy_conllu_files = 0;
my $latex = 0;
GetOptions
(
    'metric=s' => \$metric,
    'bestresults' => \$bestresults,
    'allresults' => \$allresults,
    'copy' => \$copy_filtered_eruns,
    'cocopy' => \$copy_conllu_files,
    'latex' => \$latex
);



my @bigtbk = qw(ar bg ca cs cs_cac cs_cltt cu da de el en en_lines en_partut es es_ancora et eu fa fi fi_ftb fr fr_sequoia gl got grc grc_proiel
                he hi hr hu id it ja ko la_ittb la_proiel lv nl nl_lassysmall no_bokmaal no_nynorsk pl pt pt_br ro ru ru_syntagrus sk sl
                sv sv_lines tr ur vi zh);
my @smltbk = qw(fr_partut ga gl_treegal kk la sl_sst ug uk);
my @pudtbk = qw(ar_pud cs_pud de_pud en_pud es_pud fi_pud fr_pud hi_pud it_pud ja_pud pt_pud ru_pud sv_pud tr_pud);
my @surtbk = qw(bxr hsb kmr sme);
my @alltbk = (@bigtbk, @smltbk, @pudtbk, @surtbk);
# Sanity check: There are 81 treebanks in total.
die('Expected 81 treebanks, found '.scalar(@alltbk)) if (scalar(@alltbk) != 81);
# If takeruns is present, it is the sequence of system runs (not evaluation runs) that should be combined.
# Otherwise, we should take the last complete run (all files have nonzero scores) of the primary system.
# If no run is complete and no combination is defined, should we take the best-scoring run of the primary system?
# In any case, the primary system must be defined. We shall not just take the best-scoring one.
my %teams =
(
    'Stanford-18' => {'city' => 'Stanford'},
    'IBM-NY' => {'city' => 'Yorktown Heights'},
    'ParisNLP-18' => {'city' => 'Paris'},
    'CEA-LIST' => {'city' => 'Paris'},
    'LATTICE-18' => {'city' => 'Paris'},
    'conll18-baseline' => {'city' => 'Praha'},
    'UDPipe-Future' => {'city' => 'Praha'},
    'CUNI-x-ling' => {'city' => 'Praha'},
    'ICS-PAS' => {'city' => 'Warszawa'},
    'Uppsala-18' => {'city' => 'Uppsala'},
    'TurkuNLP-18' => {'city' => 'Turku'},
    'NLP-Cube' => {'city' => 'București'},
    'SagTeam' => {'city' => 'Moskva'},
    'ArmParser' => {'city' => 'Yerevan'},
    'BOUN' => {'city' => 'İstanbul'},
    'KParse' => {'city' => 'İstanbul', 'primary' => 'software1', 'takeruns' => ['2018-07-01-15-05-56', '2018-07-01-09-16-07', '2018-06-29-00-50-02']}, # evaluator runs: 2018-07-01-14-44-14, 2018-07-01-06-15-52, 2018-07-01-18-39-38
    'SParse' => {'city' => 'İstanbul'},
    'ONLP-lab' => {'city' => "Ra'anana"},
    'HUJI' => {'city' => 'Yerushalayim'},
    'HIT-SCIR-18' => {'city' => 'Harbin'},
    'Fudan' => {'city' => 'Shanghai'},
    'LeisureX' => {'city' => 'Shanghai'},
    'Phoenix' => {'city' => 'Shanghai'},
    'UniMelb' => {'city' => 'Melbourne'}
);
# Some teams have multiple virtual machines.
my %secondary =
(
    'fbaml2' => 'fbaml',
    'CLCL2'  => 'CLCL'
);



# The output of the test runs is mounted in the master VM at this point:
my $testpath_tira = '/media/conll18-ud-test-2018-05-06';
my $testpath_ufal1 = '/net/work/people/zeman/unidep/conll2017-test-runs-v1/conll18-ud-test-2018-05-06';
my $testpath_ufal2 = '/net/work/people/zeman/unidep/conll2017-test-runs-v2/conll18-ud-test-2018-05-06';
my $testpath_ufal3 = '/net/work/people/zeman/unidep/conll2017-test-runs-v3/conll18-ud-test-2018-05-06';
my $testpath_dan  = 'C:/Users/Dan/Documents/Lingvistika/Projekty/universal-dependencies/conll2017-test-runs/filtered-eruns';
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
    my $pwd = `pwd`;
    if (-d $testpath_ufal1 && $pwd =~ m/test-runs-v1/)
    {
        $testpath = $testpath_ufal1;
    }
    elsif (-d $testpath_ufal2 && $pwd =~ m/test-runs-v2/)
    {
        $testpath = $testpath_ufal2;
    }
    elsif (-d $testpath_ufal3 && $pwd =~ m/test-runs-v3/)
    {
        $testpath = $testpath_ufal3;
    }
    else
    {
        $testpath = $testpath_ufal3;
    }
}
print STDERR ("Path with runs = $testpath\n");
die if (! -d $testpath);
my @results = read_runs($testpath);
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
foreach my $team (keys(%teams))
{
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
    copy_erun_files($testpath, '/net/work/people/zeman/unidep/conll2017-test-runs/filtered-eruns', @results);
}
if ($copy_conllu_files)
{
    copy_srun_files($testpath, '/net/work/people/zeman/unidep/conll2017-test-runs/filtered-conllu', @results);
}
# Adding averages should happen after combining runs because at present the combining code looks at all LAS-F1 entries that are not 'total-LAS-F1'
# (in the future they should rather look into the @alltbk list).
# Print the results.
# Print them in MarkDown if the long, per-treebank breakdown is requested.
if ($metric =~ m/^pertreebank-(CLAS-F1|LAS-F1|UAS-F1|UPOS-F1|XPOS-F1|Feats-F1|AllTags-F1|Lemmas-F1|Sentences-F1|Words-F1|Tokens-F1)$/)
{
    my $coremetric = $1;
    add_average("alltreebanks-$coremetric", $coremetric, \@alltbk, \@results);
    add_average("bigtreebanks-$coremetric", $coremetric, \@bigtbk, \@results);
    add_average("smalltreebanks-$coremetric", $coremetric, \@smltbk, \@results);
    add_average("pudtreebanks-$coremetric", $coremetric, \@pudtbk, \@results);
    add_average("surtreebanks-$coremetric", $coremetric, \@surtbk, \@results);
    my $bigexpl = "Macro-average $coremetric of the ".scalar(@bigtbk)." big treebanks: ".join(', ', @bigtbk).'. '.
        "These are the treebanks that have development data available, hence these results should be comparable ".
        "to the performance of the systems on the development data.";
    my $pudexpl = "Macro-average $coremetric of the ".scalar(@pudtbk)." PUD treebanks (additional parallel test sets): ".join(', ', @pudtbk).'. '.
        "These are languages for which there exists at least one big training treebank. ".
        "However, these test sets have been produced separately and their domain may differ.";
    my $smallexpl = "Macro-average $coremetric of the ".scalar(@smltbk)." small treebanks: ".join(', ', @smltbk).'. '.
        "These treebanks lack development data and some of them have very little training data (especially Uyghur and Kazakh).";
    my $surexpl = "Macro-average $coremetric of the ".scalar(@surtbk)." surprise language treebanks: ".join(', ', @surtbk).'.';
    print_table_markdown("## All treebanks", "alltreebanks-$coremetric", @results);
    print_table_markdown("## Big treebanks only\n\n$bigexpl", "bigtreebanks-$coremetric", @results);
    print_table_markdown("## PUD treebanks only\n\n$pudexpl", "pudtreebanks-$coremetric", @results);
    print_table_markdown("## Small treebanks only\n\n$smallexpl", "smalltreebanks-$coremetric", @results);
    print_table_markdown("## Surprise languages only\n\n$surexpl", "surtreebanks-$coremetric", @results);
    print("## Per treebank $coremetric\n\n\n\n");
    foreach my $treebank (sort(@alltbk))
    {
        print_table_markdown("### $treebank", "$treebank-$coremetric", @results);
    }
}
elsif ($metric eq 'ranktreebanks')
{
    my $treebanks = rank_treebanks(\@alltbk, \@results, 'LAS-F1');
    my @keys = sort {$treebanks->{$b}{'max-LAS-F1'} <=> $treebanks->{$a}{'max-LAS-F1'}} (keys(%{$treebanks}));
    my $i = 0;
    print("                      max     maxteam    avg     stdev\n");
    foreach my $key (@keys)
    {
        $i++;
        my $tbk = $key;
        $tbk .= ' ' x (13-length($tbk));
        my $team = $treebanks->{$key}{'teammax-LAS-F1'};
        $team .= ' ' x (8-length($team));
        printf("%2d.   %s   %5.2f   %s   %5.2f   ±%5.2f\n", $i, $tbk, $treebanks->{$key}{'max-LAS-F1'}, $team, $treebanks->{$key}{'avg-LAS-F1'}, sqrt($treebanks->{$key}{'var-LAS-F1'}));
    }
}
elsif ($metric eq 'ranktreebanks-CLAS')
{
    my $treebanks = rank_treebanks(\@alltbk, \@results, 'CLAS-F1');
    my @keys = sort {$treebanks->{$b}{'max-CLAS-F1'} <=> $treebanks->{$a}{'max-CLAS-F1'}} (keys(%{$treebanks}));
    my $i = 0;
    print("                      max     maxteam    avg     stdev\n");
    foreach my $key (@keys)
    {
        $i++;
        my $tbk = $key;
        $tbk .= ' ' x (13-length($tbk));
        my $team = $treebanks->{$key}{'teammax-CLAS-F1'};
        $team .= ' ' x (8-length($team));
        printf("%2d.   %s   %5.2f   %s   %5.2f   ±%5.2f\n", $i, $tbk, $treebanks->{$key}{'max-CLAS-F1'}, $team, $treebanks->{$key}{'avg-CLAS-F1'}, sqrt($treebanks->{$key}{'var-CLAS-F1'}));
        #printf("%2d. & %s & %5.2f & %s & %5.2f & ±%5.2f\\\\\\hline\n", $i, $tbk, $treebanks->{$key}{'max-CLAS-F1'}, $team, $treebanks->{$key}{'avg-CLAS-F1'}, sqrt($treebanks->{$key}{'var-CLAS-F1'}));
    }
}
elsif ($metric eq 'ranktreebanks-both' && $latex)
{
    my $treebanks = rank_treebanks(\@alltbk, \@results, 'LAS-F1');
    my $ctreebanks = rank_treebanks(\@alltbk, \@results, 'CLAS-F1');
    my $wtreebanks = rank_treebanks(\@alltbk, \@results, 'Words-F1');
    my $streebanks = rank_treebanks(\@alltbk, \@results, 'Sentences-F1');
    my @keys = sort {$treebanks->{$b}{'max-LAS-F1'} <=> $treebanks->{$a}{'max-LAS-F1'}} (keys(%{$treebanks}));
    my @ckeys = sort {$ctreebanks->{$b}{'max-CLAS-F1'} <=> $ctreebanks->{$a}{'max-CLAS-F1'}} (keys(%{$ctreebanks}));
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
    print("\\hline & \\bf Treebank & \\bf LAS F\$_1\$ & \\bf CLAS F\$_1\$ & \\bf Best system & \\bf Words & \\bf Sent \\\\\\hline\n");
    my $last_clas;
    foreach my $key (@keys)
    {
        $i++;
        my $tbk = $key;
        $tbk =~ s/_/\\_/g;
        $tbk .= ' ' x (13-length($tbk));
        my $clas = $ctreebanks->{$key}{'max-CLAS-F1'};
        my $more = defined($last_clas) && $clas > $last_clas;
        $last_clas = $clas;
        $clas = sprintf($more ? "\\textbf{%2d. %5.2f}" : "%2d. %5.2f", $ctreebanks->{$key}{crank}, $clas);
        my $team = $treebanks->{$key}{'teammax-LAS-F1'};
        $team .= ' / '.$ctreebanks->{$key}{'teammax-CLAS-F1'} if ($ctreebanks->{$key}{'teammax-CLAS-F1'} ne $treebanks->{$key}{'teammax-LAS-F1'});
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
    if ($metric eq 'alltreebanks-LAS-F1')
    {
        print('Macro-average LAS of all ', scalar(@alltbk), ' treebanks: ', join(', ', @alltbk), "\n");
        add_average('alltreebanks-LAS-F1', 'LAS-F1', \@alltbk, \@results);
    }
    elsif ($metric =~ m/^bigtreebanks-(LAS-F1|UAS-F1)$/)
    {
        my $coremetric = $1;
        print("Macro-average $coremetric of the ", scalar(@bigtbk), ' big treebanks: ', join(', ', @bigtbk), "\n");
        add_average("bigtreebanks-$coremetric", $coremetric, \@bigtbk, \@results);
    }
    elsif ($metric eq 'smalltreebanks-LAS-F1')
    {
        print('Macro-average LAS of the ', scalar(@smltbk), ' small treebanks: ', join(', ', @smltbk), "\n");
        add_average('smalltreebanks-LAS-F1', 'LAS-F1', \@smltbk, \@results);
    }
    elsif ($metric eq 'pudtreebanks-LAS-F1')
    {
        print('Macro-average LAS of the ', scalar(@pudtbk), ' PUD treebanks (additional parallel test sets): ', join(', ', @pudtbk), "\n");
        add_average('pudtreebanks-LAS-F1', 'LAS-F1', \@pudtbk, \@results);
    }
    elsif ($metric eq 'surtreebanks-LAS-F1')
    {
        print('Macro-average LAS of the ', scalar(@surtbk), ' surprise language treebanks: ', join(', ', @surtbk), "\n");
        add_average('surtreebanks-LAS-F1', 'LAS-F1', \@surtbk, \@results);
    }
    if ($latex)
    {
        print_table_latex($metric, @results);
    }
    else
    {
        print_table($metric, @results);
    }
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
# evaluation run.
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
    print STDERR ("\tTaking ", join('; ', map {"$_->{nsets} files from $_->{erun} ($_->{jsets})"} (@what_from_where)), "\n\n");
    # Recompute the macro average scores.
    # We cannot take the number of sets from scalar(grep {m/^(.+)-LAS-F1$/ && $1 ne 'total'} (keys(%combination)));
    # If the system failed to produce some of the outputs, we would be averaging only the good outputs!
    my $nsets = 81; ###!!! THIS MAY FAIL IF WE USE THIS SCRIPT FOR ANOTHER TASK IN THE FUTURE.
    die if ($nsets < 1);
    foreach my $key (keys(%sum))
    {
        $combination{"total-$key"} = $sum{$key}/$nsets;
    }
    return \%combination;
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
                @results = grep {$_->{team} ne $team || $_->{software} eq $primary} (@results);
                # Sanity check: there must be at least one run of the primary system.
                if (!grep {$_->{team} eq $team && $_->{software} eq $primary} (@results))
                {
                    die("Team '$team': did not find any runs of the primary system '$primary'");
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
        my $target = $source;
        $target =~ s:^$srcpath:$tgtpath:;
        # If the source files are from a secondary virtual machine of a team,
        # copy them under the primary name of the team.
        if ($target =~ m:^$tgtpath/([^/]+)/: && exists($secondary{$1}))
        {
            $target =~ s:^$tgtpath/([^/]+)/:$tgtpath/$secondary{$1}/:;
        }
        my $targetfolder = $target;
        $targetfolder =~ s:/[^/]+$::;
        system("mkdir -p $targetfolder");
        die("Cannot create $targetfolder") if (!-d "$targetfolder");
        #print STDERR ("cp $source $target\n");
        system("cp $source $target");
    }
    return @paths;
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
                    $treebanks{$treebank}{"teammax-$metric"} = $run->{team};
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
    print("<pre>\n");
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
    print("\\hline & \\bf Team & \\bf LAS F\$_1\$");
    if ($metric eq 'total-LAS-F1')
    {
        print(" & \\bf Files ");
    }
    print("\\\\\\hline\n");
    $latex = 1; ###!!! global
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
    foreach my $result (@results)
    {
        $result->{uniqueteam} = $result->{team};
        $result->{uniqueteam} = $secondary{$result->{uniqueteam}} if (exists($secondary{$result->{uniqueteam}}));
        $result->{printname} = exists($teams{$result->{uniqueteam}}{printname}) ? $teams{$result->{uniqueteam}}{printname} : $result->{uniqueteam};
    }
    @results = sort {my $r = $b->{$metric} <=> $a->{$metric}; unless ($r) {$r = $a->{printname} cmp $b->{printname}} $r} (@results);
    my %teammap;
    my $i = 0;
    my $last_value;
    my $last_rank;
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
            if ($n < 81)
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
        my $final = '     ';
        if (exists($teams{$uniqueteam}{takeruns}))
        {
            ###!!! Assume that a combined run is always final (i.e. there is at most one combined run per team).
            if(scalar(@{$teams{$uniqueteam}{takeruns}})==1 && $result->{srun} eq $teams{$uniqueteam}{takeruns}[0] ||
               scalar(@{$teams{$uniqueteam}{takeruns}})>1 && $result->{srun} =~ m/\+/)
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
        if ($latex)
        {
            $name =~ s/–/--/g;
            $name =~ s/ç/{\\c{c}}/g;
            $name =~ s/İ/{\\.{I}}/g;
            $name =~ s/Ú/{\\'{U}}/g; #'
            $name =~ s/ñ/{\\~{n}}/g;
            $name =~ s/ü/{\\"{u}}/g; #"
            $name =~ s/ș/{\\c{s}}/g;
            $name =~ s/è/{\\`{e}}/g; #`
            $name =~ s/de Compostela/d.C./;
            $name =~ s/^(BASELINE.+)\(Praha\)/$1/;
            $name = substr($name.(' 'x38), 0, 40);
            if ($metric eq 'total-LAS-F1')
            {
                printf("%4s & %s & %$numbersize.2f &%s \\\\\\hline\n", $rank, $name, $result->{$metric}, $tag);
            }
            elsif ($metric eq 'total-Words-F1')
            {
                $name =~ s/\(.+?\)//;
                $name = substr($name.(' 'x38), 0, 30);
                printf("%4s & %s & %$numbersize.2f & %$numbersize.2f & %$numbersize.2f \\\\\\hline\n", $rank, $name, $result->{'total-Tokens-F1'}, $result->{$metric}, $result->{'total-Sentences-F1'});
            }
            elsif ($metric eq 'total-UPOS-F1')
            {
                $name =~ s/\(.+?\)//;
                $name = substr($name.(' 'x38), 0, 30);
                my $lemmas = $result->{'total-Lemmas-F1'};
                my $upos = $result->{'total-UPOS-F1'};
                my $xpos = $result->{'total-XPOS-F1'};
                my $feat = $result->{'total-Feats-F1'};
                my $alltags = $result->{'total-AllTags-F1'}; # Includes XPOS, which many systems ignore. I don't know if it includes lemmas.
                printf("%4s & %s & %5.2f & %5.2f & %5.2f \\\\\\hline\n", $rank, $name, $upos, $feat, $lemmas);
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
