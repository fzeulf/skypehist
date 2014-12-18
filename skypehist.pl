#!/usr/bin/perl
# Written by fzeulf
# description: tool for getting skype chat history 
# info:

use strict;
use warnings;
use utf8;
use Getopt::Long;
use Date::Calc qw(Add_Delta_Days Delta_Days);
use open qw(:utf8 :std);
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
my $ver = "1.2.2 (Nov 2013)";

my ($help, $list_conv, $list_users, $chat_id, $user, $stats, %stats, %stats_dname, $topic);
my $main_db = "./main.db";
my @chats;
my @msgs;
my $nocolor = 0;
my $thlddays = 30;
GetOptions ('lc|listconv' => \$list_conv, 'lu|listusers' => \$list_users, 'db=s' => \$main_db, 'id=i' => \$chat_id, 'us=s' => \$user, 'nc|nocolor' => \$nocolor, 'st|stats' => \$stats, 'tt|timethld=i' => \$thlddays, 'h|?|help' => \$help);

if ($nocolor) {
    $ENV{ANSI_COLORS_DISABLED} = 1
}

print BOLD WHITE "\nWelcome to "; print BOLD RED "SkypeHistory"; print BOLD WHITE " $ver\n";
if ($help) {
    print <<endOfTxt;
        -lc,--listconv  - Print all available group dialogs and exit.
        -lu,--listusers - Print all available users and exit.
        -id,--id    - Define chat id.
        -us,--us    - Define skype id.
        -db,--db    - Define DB file.
        -nc,--nocolor - Set nocolor output, enabled by default
        -st,--stats - Print chat statistics instead of messages.
        -tt,--timethld - Time threshold for statistics in days (30 by default).
        -h,--help   - Print this help and exit.
endOfTxt
    exit;
}

my $ch_sqlite = `which sqlite3`;
my $ch_maindb = -e "$main_db";

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$mon += 1;
$year += 1900;
my @thr_date = Add_Delta_Days($year, $mon, $mday, -$thlddays);
my $thr_date = join ('-', @thr_date);
if ($thr_date =~ m/(\d{4})-(\d{2})-(\d{1})/) {
    $thr_date = "$1-$2-0$3";
}
elsif ($thr_date =~ m/(\d{4})-(\d{1})-(\d{2})/) {
    $thr_date = "$1-0$2-$3";
}
elsif ($thr_date =~ m/(\d{4})-(\d{1})-(\d{1})/) {
    $thr_date = "$1-0$2-0$3";
}
print BOLD BLUE "========================== Status ==========================\n";
print BOLD YELLOW "Sqlite bin: "; if($ch_sqlite) {print GREEN "Found\n";} else {print RED "Not found\n";}
print BOLD YELLOW "DB: "; if($ch_maindb) {print GREEN "$main_db\n";} else {print RED "$main_db\n";}
print BOLD YELLOW "Mode: ";
if ($list_conv) {
    print GREEN "List Group dialogs\n";
}
elsif($list_users) {
    print GREEN "List users\n";
}
elsif ($stats) {
    print GREEN "Statistics from $thr_date\n";
}
elsif($chat_id) {
    print GREEN "Group chat messages\n"
}
elsif ($user) {
    print GREEN "Chat messages\n";
}
else {
    print "\n";
}
if ($chat_id) {
    print BOLD YELLOW "Chat topic: ";
    chomp ($topic = `sqlite3 "$main_db" "select distinct topic from Chats where id = $chat_id;" 2>&1`);
    print GREEN "$topic\n";
}
elsif ($user) {
    print BOLD YELLOW "Converstion with: ";
    print GREEN "$user\n";
}
print BOLD BLUE "============================================================\n";
unless ($ch_sqlite) {
    print RED "sqlite3 binary not found. Install sqlite3 console client, please.\n";
    exit;
}
unless ($ch_maindb) {
    print RED "Can't get access to $main_db\n";
    exit;
}

if (!($list_conv)&&!($list_users)&&!($chat_id)&&!($user)) {
    print GREEN "You have to select what to do with base, list group conversations (-lc), list users (-lu), print messages from group (-id) or privat chat (-us)\n" and exit;
}
elsif ($list_conv) {
    @chats = `sqlite3 "$main_db" "select distinct id,topic,participants from Chats order by topic;" 2>&1`;
    chomp (@chats);
    print CYAN "ID         | ";
    print MAGENTA "            TOPIC              | ";
    print GREEN "PARTICIPANTS\n" . "-" x 60 . "\n";
    foreach my $str (@chats) {
        if ($str =~ m/(\d+)\|(.*)\|(.*)/) {
            my $print_str = sprintf ("%-10d", $1);
            print CYAN "$print_str | ";
            $print_str = sprintf ("%-30s", $2);
            print MAGENTA "$print_str | ";
            print GREEN "$3\n";
        }
    }
}
elsif ($list_users) {
    @chats = `sqlite3 "$main_db" "select skypename, displayname from Contacts order by skypename;" 2>&1`;
    chomp (@chats);
    print CYAN "SkypeID                   | ";
    print MAGENTA "Display name\n" . "-" x 60 . "\n";
    foreach my $str (@chats) {
        if ($str =~ m/(.*)\|(.*)/) {
            my $print_str = sprintf ("%-25s", $1);
            print CYAN "$print_str | ";
            print MAGENTA "$2\n";
        }
    }
}
elsif ($chat_id) {
    @msgs = `sqlite3 "$main_db" "select datetime(timestamp, 'unixepoch') as date, author, from_dispname, body_xml from Messages where convo_id = (select id from Conversations where chat_dbid = $chat_id);" 2>&1`;
    if ($stats) {
        my $msgs_ref = \@msgs;
        print_stats($msgs_ref);
    }
    else {
        my $msgs_ref = \@msgs; 
        print_chats($msgs_ref);
    }
}
elsif ($user) {
    @msgs = `sqlite3 "$main_db" "select datetime(timestamp, 'unixepoch') as date, author, from_dispname, body_xml from Messages where  dialog_partner = '$user';" 2>&1`;
    if ($stats) {
        my $msgs_ref = \@msgs;
        print_stats($msgs_ref);
    }
    else {
        my $msgs_ref = \@msgs;
        print_chats($msgs_ref);
    }
}

unless ($chats[0]) {
    $chats[0] = "";
}
unless ($msgs[0]) {
    $msgs[0] = "";
}

if (($chats[0] =~ m/Error: database is locked/)||($msgs[0] =~ m/Error: database is locked/)) {
    print RED "Error: database is locked.\nProbably skype is running. Close skype or copy db file and use it.\n";
    exit;
}

sub print_chats {
    my $msgs_ref = shift;
    my @msgs = @{$msgs_ref};
    chomp (@msgs);
    print CYAN "Date & Time         | ";
    print MAGENTA "SkypeID|Display name           | ";
    print GREEN "Text\n" . "-" x 60 . "\n";
    foreach my $str (@msgs) {
        if ($str =~ m/(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})\|([^\|]*)\|([^\|]*)\|(.*)/) {
            print CYAN "$1 | ";
            my $print_str = sprintf ("%-15s | %-15s", $2, $3);
            print MAGENTA "$print_str | ";
            print GREEN "$4\n"; 
        }
        else {
            print CYAN "$str\n";
        }
    }
}

sub print_stats {
    my $msgs_ref = shift;
    my @msgs = @{$msgs_ref};
    chomp (@msgs);
    my ($dname, @participants);
    if ($chat_id) { 
        chomp (@participants = split (/ /, `sqlite3 "$main_db" "select distinct participants from Chats where id = $chat_id" 2>&1`));
    }
    elsif ($user) {
        @participants = ($user); # that's a little bit far from ideal, but there could be some problem if skype have more then one account
    }
    chomp (my @dnames = `sqlite3 ./main.db "select skypename,displayname from Contacts;" 2>&1`);
    foreach my $participant (@participants) {
        $stats{"$participant"} = 0;
        foreach my $str (@dnames) {
            if ($str =~ m/$participant\|(.*)/) {
                $dname = $1;
                last;
            }
            else {
                $dname = "";
            }
        }
        $stats_dname{"$participant"} = $dname;
    }
    foreach my $str (@msgs) {
        if ($str =~ m/(\d{4})-(\d{2})-(\d{2})\s\d{2}:\d{2}:\d{2}\|([^\|]*)\|([^\|]*)\|(.*)/) {
            my $checked = 0;
            if (!($checked)&&(Delta_Days($thr_date[0],$thr_date[1],$thr_date[2],$1,$2,$3) < 0)) {
                next;
            }
            else {
                $checked = 1;
            }
            $stats{"$4"} += 1;
            $stats_dname{"$4"} = $5;
        }
    }
    foreach my $key (reverse sort {$stats{$a} <=> $stats{$b}} keys %stats) {
        my $print_str = sprintf ("%-15s | %-15s", $key, $stats_dname{$key});
        print CYAN "$print_str | ";
        print GREEN "$stats{$key}\n";
    }
}
