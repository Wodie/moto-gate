#!/usr/bin/perl

# ARS-E daemon: ARS Extendable

# Strict and warnings recommended.
use strict;
use warnings;
use Switch;
use Config::IniFiles;
use Data::Dumper qw(Dumper);

use YAML::Tiny;
use Digest::MD5 qw(md5_hex);
use JSON;
use POSIX;

# APRS-IS
use Ham::APRS::IS;

# For e-mail sending.
#use Email::Send::SMTP::Gmail;
#use Net::SMTPS;
# use Mail::Webmail::Gmail;

# Reverse Geocoding
#use LWP::UserAgent ();
#use XML::Simple;
#use Geo::Parser::Text;

# BulkSMS
use HTTP::Request::Common;
use LWP::UserAgent;

# RadioID
#use LWP::Simple qw/get/;
#use Net::OpenSSH;
#use JSON::API;

# Misc
use Term::ReadKey;
use Term::ANSIColor;

# Needed for FAP:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
# Use custom version of FAP:
use FAP;
use TRBO::NET;
use TRBO::Common;
use TRBO::DupeCache;



# About this app.
my $AppName = 'Moto-Gate';
use constant VersionInfo => 2;
use constant MinorVersionInfo => 00;
use constant RevisionInfo => 0;
my $Version = VersionInfo . '.' . MinorVersionInfo . '-' . RevisionInfo;
print "\n##################################################################\n";
print "	*** $AppName v$Version ***\n";
print "	Released: February 02, 2022. Created March 07, 2015.\n";
print "	Created by:\n";
print "	Juan Carlos Pérez De Castro (Wodie) KM4NNO / XE1F\n";
print "	Based on David Kierzkowski KD8EYF TRBO-NET code.\n";
print "	\n";
print "	www.wodielite.com\n";
print "	wodielite at mac.com\n\n";
print "	km4nno at yahoo.com\n\n";
print "	License:\n";
print "	This software is licenced under the GPL v3.\n";
print "	If you are using it, please let me know, I will be glad to know it.\n\n";
print "	This project is based on the work and information from:\n";
print "	Juan Carlos Pérez KM4NNO / XE1F\n";
print "	David Kierzkowski KD8EYF\n";
print "	APRS is a registed trademark and creation of Bob Bruninga WB4APR\n";
print "\n##################################################################\n\n";



# Prototypes
sub APRS_IS_Init();
sub status_msg($);
sub Reload_State();



# Detect Target OS.
my $OS = $^O;
print color('green'), "Current OS is $OS\n", color('reset');
print "----------------------------------------------------------------------\n";



# Load Settings ini file.
print color('green'), "Loading Settings...\n", color('reset');
my $config = Config::IniFiles->new( -file => "/home/pi/moto-gate/config.ini");
# Settings:
my $State_Dump_File = $config->val('Settings', 'state_dump');
my $RadioID_URL = $config->val('Settings', 'RadioID_URL');
my $Mode = $config->val('Settings', 'Mode');
my $HotKeys = $config->val('Settings', 'HotKeys');
my $Verbose = $config->val('Settings', 'Verbose');
print "  State Dump File = $State_Dump_File\n";
print "  RadioID URL = $RadioID_URL\n";
print "  Mode = $Mode\n";
print "  HotKeys = $HotKeys\n";
print "  Verbose = $Verbose\n";
print "----------------------------------------------------------------------\n";



# Mototrbo
print color('green'), "Loading Mototrbo settings...\n", color('reset');
my $Moto_Card_IP = $config->val('Mototrbo', 'Card_IP');
my $Admin_Radio_ID = $config->val('Mototrbo', 'Admin_Radio_ID');
my $Master_Radio_ID = $config->val('Mototrbo', 'Master_Radio_ID');
my $Master_Radio_IP = $config->val('Mototrbo', 'Master_Radio_IP');
my $CAI_Network = $config->val('Mototrbo', 'CAI_Network');
my $CAI_Group_Network = $config->val('Mototrbo', 'CAI_Group_Network');
my $ARS_Port = $config->val('Mototrbo', 'ARS_Port');
my $TMS_Port = $config->val('Mototrbo', 'TMS_Port');
my $Loc_Port = $config->val('Mototrbo', 'Loc_Port');
my $ARS_Timeout = $config->val('Mototrbo', 'ARS_Timeout');
my $ARS_Ping_Interval = $config->val('Mototrbo', 'ARS_Ping_Interval');
my $GPS_Req_Interval = $config->val('Mototrbo', 'GPS_Req_Interval');
my $TMS_Queue_Max_Age = $config->val('Mototrbo', 'TMS_Queue_Max_Age');
my $TMS_Init_Retry_Interval = $config->val('Mototrbo', 'TMS_Init_Retry_Interval');
my $Data_Talk_Group = $config->val('Mototrbo', 'Data_Talk_Group');
my $Trbo_Verbose = $config->val('Mototrbo', 'Verbose');
print "  Card IP = $Moto_Card_IP\n";
print "  Admin Radio ID = $Admin_Radio_ID\n";
print "  Master Radio ID = $Master_Radio_ID\n";
print "  Master Radio IP = $Master_Radio_IP\n";
print "  CAI_Network = $CAI_Network\n";
print "  CAI_Group_Network = $CAI_Group_Network\n";
print "  ARS_Port = $ARS_Port\n";
print "  TMS_Port = $TMS_Port\n";
print "  Loc_Port = $Loc_Port\n";
print "  ARS_Timeout = $ARS_Timeout\n";
print "  ARS_Ping_Interval = $ARS_Ping_Interval\n";
print "  GPS_Req_Interval = $GPS_Req_Interval\n";
print "  TMS_Queue_Max_Age = $TMS_Queue_Max_Age\n";
print "  TMS_Init_Retry_Interval = $TMS_Init_Retry_Interval\n";
print "  Data_Talk_Group = $Data_Talk_Group\n";
print "  Verbose = $Trbo_Verbose\n";
print "----------------------------------------------------------------------\n";



# TRBO::NET
print color('green'), "Creating TRBO::NET\n", color('reset');
my $Net = TRBO::NET->new(
	'card_ip' => $Moto_Card_IP,
	'ars_port' => $ARS_Port,
	'loc_port' => $Loc_Port,
	'tms_port' => $TMS_Port,
	'debug' => 1,
	'cai_net' => $CAI_Network,
	'cai_group_net' => $CAI_Group_Network,
	'registry_poll_interval' => $ARS_Ping_Interval,
	'registry_timeout' => $ARS_Timeout,
);
if ($Trbo_Verbose >= 1){
	TRBO::NET::debug(1);
	TRBO::Common::debug(1);
	TRBO::DupeCache::debug(1);
}
print "----------------------------------------------------------------------\n";



# APRS-IS:
print color('green'), "Loading APRS-IS...\n", color('reset');
my $APRS_IS_Enable = $config->val('APRS', 'Enable');
my $Callsign = $config->val('APRS', 'Callsign');
my $APRS_Suffix = $config->val('APRS', 'Suffix');
my $APRS_Passcode = $config->val('APRS', 'Passcode');
my $APRS_Server= $config->val('APRS', 'Server');
my $APRS_File = $config->val('APRS', 'APRS_File');
my $APRS_Interval = $config->val('APRS', 'APRS_Interval') * 60;
my $My_Latitude = $config->val('APRS', 'Latitude');
my $My_Longitude = $config->val('APRS', 'Longitude');
my $My_Symbol = $config->val('APRS', 'Symbol');
my $My_Altitude = $config->val('APRS', 'Altitude');
my $My_Freq = $config->val('APRS', 'Frequency');
my $My_Tone = $config->val('APRS', 'AccessTone');
my $My_Offset = $config->val('APRS', 'Offset');
my $My_Comment = $config->val('APRS', 'APRSComment');
my $APRS_Verbose= $config->val('APRS', 'Verbose');
print "  Enable = $APRS_IS_Enable\n";
print "  Callsign = $Callsign\n";
print "  Suffix = $APRS_Suffix\n";
print "  Passcode = $APRS_Passcode\n";
print "  Server = $APRS_Server\n";
print "  APRS File + $APRS_File\n";
print "  APRS Interval = $APRS_Interval\n";
print "  Latitude = $My_Latitude\n";
print "  Longitude = $My_Longitude\n";
print "  Symbol = $My_Symbol\n";
print "  Altitude = $My_Altitude\n";
print "  Freq = $My_Freq\n";
print "  Tone = $My_Tone\n";
print "  Offset = $My_Offset\n";
print "  Comment = $My_Comment\n";
print "  Verbose = $APRS_Verbose\n";
my $APRS_IS;
my %APRS;
my $APRS_NextTimer = time();
if ($APRS_Passcode ne Ham::APRS::IS::aprspass($Callsign)) {
	$APRS_Server = undef;
	warn color('red'), "APRS invalid pasword.\n", color('reset');
}
my $APRS_Callsign = $Callsign . '-' . $APRS_Suffix;
print "  APRS Callsign = $APRS_Callsign\n";
if (defined $APRS_Server) {
	$APRS_IS = new Ham::APRS::IS($APRS_Server, $APRS_Callsign,
		'appid' => "$AppName $Version",
		'passcode' => $APRS_Passcode,
		'filter' => 't/m');
	if (!$APRS_IS) {
		warn color('red'), "Failed to create APRS-IS Server object: " . 
			$APRS_IS->{'error'} . "\n", color('reset');
	}
	if ($APRS_Verbose >= 3){
		Ham::APRS::FAP::debug(1);
	}
}
print "----------------------------------------------------------------------\n";



# SMS:
print color('green'), "Loading SMS...\n", color('reset');
my $sms_username = $config->val('SMS', 'sms_username');
my $sms_password = $config->val('SMS', 'sms_password');
my $APRS_Verbose= $config->val('APRS', 'Verbose');
print "  sms_username = $sms_username\n";
print "  sms_password = $sms_password\n";
print "  Verbose = $APRS_Verbose\n";
print "----------------------------------------------------------------------\n";



# Load Users conf file.
print color('green'), "Loading Users...\n", color('reset');
my $Users;
#my @cfgfiles = ( '/home/pi/moto_x/users.conf', 'users.conf', '/usr/local/etc/users.conf', 
my @cfgfiles = ( '/home/pi/moto-gate/users.conf' );
# select which config file is present
my $counter;
my $cfgfile;
my $UsersFile;
foreach my $f (@cfgfiles) {
	if ( -f $f ) {
		$cfgfile = $f;
		last;
	}
}

if (!defined $cfgfile) {
	die "  Could not find a configuration file from: @cfgfiles\n";
}

# Settings:
print "  Reading YAML configuration from $cfgfile\n";
my $yaml = YAML::Tiny->new;
my $conf = YAML::Tiny->read($cfgfile);
$Users = shift @$conf;

print color('grey12'), "  Users: " . Dumper($Users), color('reset');

# configure radios
while (my $Radio = shift @$conf) {
	$Net->configure_radio($Radio);
	print "  Radio:\n" . Dumper($Radio);
}

Reload_State();

my $aprs_msg_cache = new TRBO::DupeCache();

$aprs_msg_cache->init();

###############################################################################
# Valid Commands
###############################################################################
my %cmds = (
	'a' => \&Cmd_APRS_IS,
	'aprs' => \&Cmd_APRS_IS,
	'ctrl' => \&Cmd_Ctrl,
	'e' => \&Cmd_email,
	'email' => \&Cmd_email,
	'item' => \&Cmd_APRS_item,
	'h' => \&Cmd_Help,
	'help' => \&Cmd_Help,
	'obj' => \&Cmd_APRS_IS_Obj,
	'ping' => \&Cmd_ping,
	'sms' => \&Cmd_SMS,
	'w' => \&Cmd_Who,
	'wea' => \&Cmd_WEA,
	'where' => \&Cmd_Where,
	'who' => \&Cmd_Who,
);

if (defined $APRS_Server) {
	APRS_IS_Init();
	# configure APRS commands
	$cmds{'a'} = $cmds{'aprs'} = \&Cmd_APRS_IS;
}
print color('green'), "ARS-E Service started up.\n", color('reset');

my $IS_Beacon_Int = 19*60 + rand(120);
my $IS_Next_Beacon = time() + 30;
print "----------------------------------------------------------------------\n";

my $link_channel;
my @upd_q;
#my $APRS_IS;
my $start_time = time();



# Read Keys:
if ($HotKeys) {
	ReadMode 3;
	PrintMenu();
}
print "----------------------------------------------------------------------\n";

# Misc
my $Run = 1;

###############################################################################
# MAIN 
###############################################################################
while ($Run) {
	MainLoop();
}
# Program exit:
print "----------------------------------------------------------------------\n";
ReadMode 0; # Set keys back to normal State.
if ($APRS_IS and $APRS_IS->connected()) {
	$APRS_IS->disconnect();
	print color('green'), "APRS-IS Disconected.\n", color('reset');
}
print "Good bye cruel World.\n";
print "----------------------------------------------------------------------\n\n";
exit;



###############################################################################
# Menu
###############################################################################
sub PrintMenu {
	print "Shortcuts menu:\n";
	print "  Q/q = Quit.                      h = Help..\n";
	print "  A/a = APRS  show/hide verbose.   \n";
	print "  S/s = STUN  show/hide verbose.   t   = Test.\n\n";
}



###############################################################################
# APRS-IS
###############################################################################
sub APRS_IS_Init() {
	$APRS_IS = new Ham::APRS::IS($APRS_Server, $Callsign,
		'appid' => "$AppName v$Version",
		'passcode' => $APRS_Passcode,
		'filter' => 't/m');
	if (!$APRS_IS) {
		print color('red'), "Failed to create APRS-IS server object: " .
			$APRS_IS->{'error'} . "\n", color('reset');
		return;
	}
}

sub APRS_IS_Connect() {
	my $Res = $APRS_IS->connect('retryuntil' => 2);
	if (!$Res) {
		print color('red'), "Failed to connect to IS server: " . $APRS_IS->{'error'} .
			"\n", color('reset');
		return;
	}
	print color('green'), "APRS-IS: Connected.\n", color('reset');
}

sub APRS_IS_Process_Rx_Net_Data($) {
	my($RawData) = @_;

	if ($APRS_Verbose >= 1) {print color('green'), "APRS_IS_Process_Rx_Net_Data\n", color('reset');}
	my %PacketData;
	my $Res = Ham::APRS::FAP::parseaprs($RawData, \%PacketData);
	return if (!$Res);
	if (defined $PacketData{'type'} && $PacketData{'type'} eq 'message') {
		APRS_IS_Process_Rx_Net_Msg(\%PacketData);
	}
}

sub APRS_IS_Process_Rx_Net_Msg($) {
	my($PacketData) = @_;

	if ($APRS_Verbose >= 1) {print color('green'), "APRS_IS_Process_Rx_Net_Msg\n", color('reset');}
	if ($APRS_Verbose >= 1) {print "  destination = $PacketData->{'destination'}\n";}
	if ($APRS_Verbose >= 1) {print Dumper($PacketData);}

	# Check if APRS-IS Callsign is ALL TEST or SKY and send a Group TMS.
	if (	substr($PacketData->{'destination'}, 0, 3) eq "AIR" ||
			substr($PacketData->{'destination'}, 0, 3) eq "ALL" ||
#			substr($PacketData->{'destination'}, 0, 2) eq "AP" ||
#			substr($PacketData->{'destination'}, 0, 6) eq "BEACON" ||
#			substr($PacketData->{'destination'}, 0, 2) eq "CQ" ||
#			substr($PacketData->{'destination'}, 0, 3) eq "GPS" ||
#			substr($PacketData->{'destination'}, 0, 2) eq "DF" ||
#			substr($PacketData->{'destination'}, 0, 4) eq "DGPS" ||
			substr($PacketData->{'destination'}, 0, 5) eq "DRILL" ||
#			substr($PacketData->{'destination'}, 0, 2) eq "DX" ||
#			substr($PacketData->{'destination'}, 0, 2) eq "ID" ||
#			substr($PacketData->{'destination'}, 0, 4) eq "JAVA" ||
			substr($PacketData->{'destination'}, 0, 4) eq "MAIL" ||
#			substr($PacketData->{'destination'}, 0, 4) eq "MICE") ||
#			substr($PacketData->{'destination'}, 0, 3) eq "QST" ||
#			substr($PacketData->{'destination'}, 0, 3) eq "QTH" ||
#			substr($PacketData->{'destination'}, 0, 4) eq "RTCM" ||
			substr($PacketData->{'destination'}, 0, 3) eq "SKY" ||
#			substr($PacketData->{'destination'}, 0, 5) eq "SPACE" ||
#			substr($PacketData->{'destination'}, 0, 3) eq "SPC" ||
#			substr($PacketData->{'destination'}, 0, 3) eq "SYM" ||
#			substr($PacketData->{'destination'}, 0, 3) eq "TEL" ||
			substr($PacketData->{'destination'}, 0, 4) eq "TEST" ||
#			substr($PacketData->{'destination'}, 0, 3) eq "TLM" ||
#			substr($PacketData->{'destination'}, 0, 2) eq "WX" || {
			substr($PacketData->{'destination'}, 0, 3) eq "ZIP" ) {
		print color('magenta'),"  Generic APRS Destination Address Received = " . 
			$PacketData->{'destination'} . " from " . $PacketData->{'srccallsign'} . 
			" to Mototrbo TG = " . $Data_Talk_Group . " msg = " . $PacketData->{'message'} .
			"\n", color('reset');

		# TMS to Talk Group:
		$Net->{'tms'}->queue_msg($Data_Talk_Group, 'APRS ' . $PacketData->{'srccallsign'} .
			': ' . $PacketData->{'message'}, $CAI_Group_Network);
		return;
	}

	# Check if APRS-IS Callsign is on registered users file.
	my $Radio = $Net->registry_find_call($PacketData->{'destination'});
	return if (!defined $Radio); # Not found
	my $cacheid;
	if (defined $PacketData->{'messageid'}) {
		print "  destination = $PacketData->{'destination'}, srccallsign = $PacketData->{'srccallsign'}, " .
		"messageid = $PacketData->{'messageid'}\n";
		
		my $Packet = sprintf(APRS_IS_Make_Ack($PacketData->{'destination'},
			$PacketData->{'srccallsign'}, $PacketData->{'messageid'}));
		print color('blue'), "  $Packet\n", color('reset');
		my $Res = $APRS_IS->sendline($Packet);
		if (!$Res) {
			print color('red'), "Error sending APRS-IS Ack packet $Res\n", color('reset');
			$APRS_IS->disconnect();
			return;
		}
		print "  Ack Sent.\n";
		
		$cacheid = md5_hex($PacketData->{'srccallsign'} . '_' .
			$PacketData->{'destination'} . '_' . $PacketData->{'messageid'});
	} else {
		print "three\n";
		$cacheid = md5_hex($PacketData->{'srccallsign'} . '_' .
			$PacketData->{'destination'} . '_' . $PacketData->{'message'});
	}

	if ($aprs_msg_cache->add($cacheid)) {
		print "four\n";
		print "  Dupe ignored: APRS-IS to Mototrbo " .
			$PacketData->{'srccallsign'} . '>' . $PacketData->{'destination'} .
				" " . $Radio->{'id'}
			. ((defined $PacketData->{'messageid'}) ? '(id ' . $PacketData->{'messageid'} . ')' : '')
			. ": " . $PacketData->{'message'} . "\n";
		return;
	}

	print "  APRS-IS to Mototrbo: "
		. $PacketData->{'srccallsign'} . ' to ' . $PacketData->{'destination'} .
			" " . $Radio->{'id'}
		. "msg = " . $PacketData->{'message'} . "\n";

	$Net->{'tms'}->queue_msg($Radio->{'id'}, 'APRS ' . $PacketData->{'srccallsign'} .
		': ' . $PacketData->{'message'});
}

sub APRS_IS_Make_Ack($$$) {
	my($src, $dst, $msgid) = @_;
	return sprintf("%s>APRS::%-9s:ack%s", $src, $dst, $msgid);
}

sub APRS_IS_Push_Position_Updates() {
	# Look if APRS-IS object exist (it could happen? IDK).
	if (!$APRS_IS) {
		@upd_q = ();
		return;
	}
	# Look if APRS-IS is connected, if not try to connect.
	if (!$APRS_IS->connected()) {
		APRS_IS_Connect();
	}
	# If no success, flush variable and return.
	if (!$APRS_IS->connected()) {
		@upd_q = ();
		return;
	}
	my $Comment = "By Moto-Gate ";
	print color('green'), "APRS-IS Push Updates:\n", color('reset');
	# Make an ARPS position packet for each entry.
	foreach my $ent (@upd_q) {
		my $APRS_Position = Ham::APRS::FAP::make_position(
			$ent->{'latitude'},
			$ent->{'longitude'},
			$ent->{'speed'}, # speed
			$ent->{'course'}, # course
			$ent->{'altitude'}, # altitude
			(defined $ent->{'symbol'}) ? $ent->{'symbol'} : '/[', # symbol
			{
			#'compression' => 1,
			#'ambiguity' => 1, # still can not make it work.
			#'timestamp' => time(), # still can not make it work.
			'comment' => $Comment,
			#'dao' => 1
		});
#			#1, # compression
#			#0 # no ambiguity
#		);
		print "$APRS_Position\n";

		if (!defined $ent->{'comment'}) {
			$ent->{'comment'} = '';
		};

		my $Packet = sprintf('%s>APTR01:!%s', $ent->{'callsign'}, $APRS_Position . $ent->{'comment'});
		print color('blue'), "  $Packet\n", color('reset');
		my $Res = $APRS_IS->sendline($Packet);
		if (!$Res) {
			print color('red'), "Error sending APRS-IS Pos packet $Res\n", color('reset');
			$APRS_IS->disconnect();
			return;
		}
		print "  Push Update Done.\n";
	}
	@upd_q = (); # Flush variable.
}

sub APRS_IS_Push_Object() {
	# Look if APRS-IS object exist (it could happen? IDK).
	if (!$APRS_IS) {
		@upd_q = ();
		return;
	}
	# Look if APRS-IS is connected, if not try to connect.
	if (!$APRS_IS->connected()) {
		APRS_IS_Connect();
	}
	# If no success, flush variable and return.
	if (!$APRS_IS->connected()) {
		@upd_q = ();
		return;
	}
	print color('green'), "APRS-IS Push Object:\n", color('reset');
	# Make an ARPS position packet for each entry.
	foreach my $ent (@upd_q) {
		my $APRS_Object = Ham::APRS::FAP::make_object(
			$ent->{'name'},
			$ent->{'timestamp'}, # timestamp (current == 0)
			$ent->{'latitude'},
			$ent->{'longitude'},
			(defined $ent->{'symbol'}) ? $ent->{'symbol'} : '\.', # symbol
			$ent->{'speed'}, # speed
			$ent->{'course'}, # course
			$ent->{'altitude'}, # altitude
			$ent->{'status'}, # alive or death (1 or 0)
			1, # compression
			0, # no ambiguity
			$ent->{'comment'}
		); # comment
		print "$APRS_Object\n";

		my $Packet = sprintf('%s>APTR01:%s', $ent->{'callsign'}, $APRS_Object);
		print color('blue'), "  $Packet\n", color('reset');

		my $Res = $APRS_IS->sendline($Packet);
		if (!$Res) {
			print color('red'), "Error sending APRS-IS Pos packet $Res\n", color('reset');
			$APRS_IS->disconnect();
		}
		print "  Push Object Ok.\n";
	}
	@upd_q = (); # Flush variable.
}

sub APRS_IS_Push_Item() {
	# Look if APRS-IS object exist (it could happen? IDK).
	if (!$APRS_IS) {
		@upd_q = ();
		return;
	}
	# Look if APRS-IS is connected, if not try to connect.
	if (!$APRS_IS->connected()) {
		APRS_IS_Connect();
	}
	# If no success, flush variable and return.
	if (!$APRS_IS->connected()) {
		@upd_q = ();
		return;
	}
	print color('green'), "APRS-IS Push Item:\n", color('reset');
	# Make an ARPS position packet for each entry.
	foreach my $ent (@upd_q) {
		my $APRS_Item = Ham::APRS::FAP::make_item(
			$ent->{'name'},
			$ent->{'latitude'},
			$ent->{'longitude'},
			(defined $ent->{'symbol'}) ? $ent->{'symbol'} : '\.', # symbol
			$ent->{'speed'}, # speed
			$ent->{'course'}, # course
			$ent->{'altitude'}, # altitude
			$ent->{'status'}, # alive or death (1 or 0)
			1, # compression
			0, # no ambiguity
			$ent->{'comment'}); # comment
		print "$APRS_Item\n";

		my $Packet = sprintf('%s>APTR01:!%s', $ent->{'callsign'}, $APRS_Item);
		print color('blue'), "  $Packet\n", color('reset');

		my $Res = $APRS_IS->sendline($Packet);
		if (!$Res) {
			print color('red'), "Error sending APRS-IS Pos packet $Res\n", color('reset');
			$APRS_IS->disconnect();
		}
		print "  Push Object Ok.\n";
	}
	@upd_q = (); # Flush variable.
}

sub APRS_IS_Consider_Beacon($) {
	my($Rx_Radio) = @_;

	my $reg = $Rx_Radio->{'registry'};
	$reg->{'last_lat'} = $Rx_Radio->{'latitude'};
	$reg->{'last_lng'} = $Rx_Radio->{'longitude'};

	# If never beaconed before, do it now
	return APRS_IS_Do_Beacon($Rx_Radio) if (!defined $reg->{'last_aprsis'});

	# If very often, don't do it now
	my $Since_Last = time() - $reg->{'last_aprsis'};
	if ($Since_Last < 0) {
		# clock has jumped backwards, reset the timer!
		$reg->{'last_aprsis'} = time();
		return 0;
	}
	return 0 if ($Since_Last < 30);

	if (defined $reg->{'last_aprsis_lat'}) {
		my $Displaced_Distance = Ham::APRS::FAP::distance(
			$reg->{'last_aprsis_lng'}, $reg->{'last_aprsis_lat'},
			$Rx_Radio->{'longitude'}, $Rx_Radio->{'latitude'});
		if ($Displaced_Distance < 0.05) {
			if ($Since_Last < 15*60) {
				return 0;
			}
			return APRS_IS_Do_Beacon($Rx_Radio);
		} else {
			return APRS_IS_Do_Beacon($Rx_Radio);
		}
	}
	return APRS_IS_Do_Beacon($Rx_Radio);
}

sub APRS_IS_Do_Beacon($) {
	my($Rx_Radio) = @_;

	my $reg = $Rx_Radio->{'registry'};
	$reg->{'last_aprsis'} = time();
	$reg->{'last_aprsis_lat'} = $Rx_Radio->{'latitude'};
	$reg->{'last_aprsis_lng'} = $Rx_Radio->{'longitude'};
	print "  Beaconing position of " . $reg->{'id'} . ": " .
		$reg->{'callsign'} . "\n";
	return 1;
}



###############################################################################
# APRS
###############################################################################
sub APRS_Symbol_by_Name($) {
	my $name = shift @_;
	my $symbol;
	# Basic symbol table '/'
	if (lc($name) eq 'police'){
		$symbol = '/!';
	} elsif (uc($name) eq 'DIGI') {
		$symbol = '/#';
	} elsif (uc($name) eq 'PHONE') {
		$symbol = '/$';
	} elsif (uc($name) eq 'DX') {
		$symbol = '/%';
	} elsif (uc($name) eq 'HFGateway') {
		$symbol = '/&';
	} elsif (lc($name) eq 'aircraft') {
		$symbol = '/\'';
	} elsif (uc($name) eq 'MSS') {
		$symbol = '/(';
	} elsif (lc($name) eq 'wheelch') {
		$symbol = '/)';
	} elsif (lc($name) eq 'snowmob') {
		$symbol = '/*';
	} elsif (lc($name) eq 'redcross') {
		$symbol = '/+';
	} elsif (lc($name) eq 'boyscout') {
		$symbol = '/,';
	} elsif (uc($name) eq 'QTH') {
		$symbol = '/-';
	} elsif (uc($name) eq 'X') {
		$symbol = '/.';
	} elsif (lc($name) eq 'reddot') {
		$symbol = '//';

	} elsif (lc($name) eq 'fire') {
		$symbol = '/:';
	} elsif (lc($name) eq 'camp') {
		$symbol = '/;';
	} elsif (lc($name) eq 'motorcyc') {
		$symbol = '/<';
	} elsif (lc($name) eq 'rrengine') {
		$symbol = '/=';
	} elsif (lc($name) eq 'car') {
		$symbol = '/>';
	} elsif (lc($name) eq 'server') {
		$symbol = '/?';
	} elsif (uc($name) eq 'HCFUTURE') {
		$symbol = '/@';
	} elsif (lc($name) eq 'aid') {
		$symbol = '/A';
	} elsif (Uc($name) eq 'BBS') {
		$symbol = '/B';
	} elsif (lc($name) eq 'PBBS') {
		$symbol = '/B';
	} elsif (lc($name) eq 'canoe') {
		$symbol = '/C';
	} elsif (uc($name) eq 'EYEBALL') {
		$symbol = '/E';
	} elsif (lc($name) eq 'farmvehc') {
		$symbol = '/F';
	} elsif (lc($name) eq 'grid') {
		$symbol = '/G';
	} elsif (uc($name) eq 'HOTEL') {
		$symbol = '/H';
	} elsif (uc($name) eq 'TCPIP') {
		$symbol = '/I';
	} elsif (lc($name) eq 'school') {
		$symbol = '/K';
	} elsif (lc($name) eq 'PC') {
		$symbol = '/L';
	} elsif (uc($name) eq 'MACAPRS') {
		$symbol = '/M';
	} elsif (uc($name) eq 'NTS') {
		$symbol = '/N';
	} elsif (uc($name) eq 'BALLOON') {
		$symbol = '/O';
	} elsif (lc($name) eq 'police') {
		$symbol = '/P';
	} elsif (lc($name) eq 'recvehc') {
		$symbol = '/R';
	} elsif (uc($name) eq 'SHUTTLE') {
		$symbol = '/S';
	} elsif (uc($name) eq 'SSTV') {
		$symbol = '/T';
	} elsif (uc($name) eq 'BUS') {
		$symbol = '/U';
	} elsif (uc($name) eq 'ATV') {
		$symbol = '/V';
	} elsif (uc($name) eq 'WX') {
		$symbol = '/W';
	} elsif (uc($name) eq 'HELO') {
		$symbol = '/X';
	} elsif (uc($name) eq 'YATCH') {
		$symbol = '/Y';
	} elsif (uc($name) eq 'WINAPRS') {
		$symbol = '/Z';

	} elsif (lc($name) eq 'human') {
		$symbol = '/[';
	} elsif (lc($name) eq 'person') {
		$symbol = '/[';
	} elsif (uc($name) eq 'TRIANGLE') {
		$symbol = '/\\';
	} elsif (uc($name) eq 'MAIL') {
		$symbol = '/Z]';
	} elsif (uc($name) eq 'AIRCRAFT') {
		$symbol = '/Z^';
	} elsif (uc($name) eq 'WEATHERST') {
		$symbol = '/_';
	} elsif (lc($name) eq 'dishant') {
		$symbol = '/`';

	} elsif (lc($name) eq 'ambulance') {
		$symbol = '/a';
	} elsif (lc($name) eq 'bike') {
		$symbol = '/b';
	} elsif (lc($name) eq 'icidcom') {
		$symbol = '/c';
	} elsif (lc($name) eq 'firedep') {
		$symbol = '/d';
	} elsif (lc($name) eq 'horse') {
		$symbol = '/e';
	} elsif (lc($name) eq 'firetruck') {
		$symbol = '/f';
	} elsif (lc($name) eq 'glider') {
		$symbol = '/g';
	} elsif (lc($name) eq 'hospital') {
		$symbol = '/h';
	} elsif (uc($name) eq 'IOTA') {
		$symbol = '/i';
	} elsif (lc($name) eq 'jeep') {
		$symbol = '/j';
	} elsif (lc($name) eq 'truck') {
		$symbol = '/k';
	} elsif (lc($name) eq 'laptop') {
		$symbol = '/l';
	} elsif (lc($name) eq 'mic-e/r') {
		$symbol = '/m';
	} elsif (lc($name) eq 'node') {
		$symbol = '/n';
	} elsif (uc($name) eq 'EOC') {
		$symbol = '/o';
	} elsif (uc($name) eq 'ROVER') {
		$symbol = '/p';
	} elsif (uc($name) eq 'GRIDSQ') {
		$symbol = '/q';
	} elsif (lc($name) eq 'repeater') {
		$symbol = '/r';
	} elsif (uc($name) eq 'SHIP') {
		$symbol = '/s';
	} elsif (uc($name) eq 'TRUCKSTOP') {
		$symbol = '/t';
	} elsif (uc($name) eq 'TRUCK') {
		$symbol = '/u';
	} elsif (uc($name) eq 'VAN') {
		$symbol = '/v';
	} elsif (uc($name) eq 'WATER') {
		$symbol = '/w';
	} elsif (uc($name) eq 'XAPRS') {
		$symbol = '/x';
	} elsif (uc($name) eq 'YAGI') {
		$symbol = '/y';
	} elsif (uc($name) eq 'TNCST') {
		$symbol = '/|';
	} elsif (uc($name) eq 'TNCSTREAM') {
		$symbol = '/~';

	# Other symbol table '\'
	} elsif (uc($name) eq 'EMERGENCY') {
		$symbol = '\!';
	} elsif (uc($name) eq 'OLDIGI') {
		$symbol = '\#';
	} elsif (uc($name) eq 'BANK') {
		$symbol = '\$';
	} elsif (uc($name) eq 'POWER') {
		$symbol = '\%';
	} elsif (lc($name) eq 'igate') {
		$symbol = '\&';
	} elsif (lc($name) eq 'crash') {
		# $symbol = '\' . "\'";
	} elsif (uc($name) eq 'CLOUDY') {
		$symbol = '\(';
	} elsif (lc($name) eq 'firenet') {
		$symbol = '\)';
	} elsif (lc($name) eq 'church') {
		$symbol = '\+';
	} elsif (lc($name) eq 'girlscout') {
		$symbol = '\,';
	} elsif (lc($name) eq 'house') {
		$symbol = '\-';
	} elsif (uc($name) eq '?') {
		$symbol = '\.';
	} elsif (uc($name) eq 'waypoint') {
		$symbol = '\/';

	} elsif (uc($name) eq 'CIRCLE') {
		$symbol = '\0';
	} elsif (uc($name) eq 'IRLP') {
		$symbol = '\0';
	} elsif (lc($name) eq 'echolink') {
		$symbol = '\0';
	} elsif (uc($name) eq '802.11') {
		$symbol = '\8';
	} elsif (lc($name) eq 'gas') {
		$symbol = '\9';
	} elsif (lc($name) eq 'picnik') {
		$symbol = '\,';
	} elsif (uc($name) eq 'ADVISORY') {
		$symbol = '\<';
	} elsif (uc($name) eq 'APRSTT') {
		$symbol = '\=';
	} elsif (uc($name) eq 'OVERLAYED') {
		$symbol = '\>';
	} elsif (uc($name) eq 'INFO') {
		$symbol = '\?';
	} elsif (uc($name) eq 'HURICANE') {
		$symbol = '\@';
	} elsif (lc($name) eq 'overlay') {
		$symbol = '\A';
	} elsif (lc($name) eq 'coastg') {
		$symbol = '\C';
	} elsif (uc($name) eq 'DEPOTS') {
		$symbol = '\D';
	} elsif (lc($name) eq 'smoke') {
		$symbol = '\E';
	} elsif (lc($name) eq 'haze') {
		$symbol = '\H';
	} elsif (lc($name) eq 'rain') {
		$symbol = '\I';
	} elsif (lc($name) eq 'kenwood') {
		$symbol = '\K';
	} elsif (lc($name) eq 'lighth') {
		$symbol = '\L';
	} elsif (uc($name) eq 'MARS') {
		$symbol = '\M';
	} elsif (lc($name) eq 'navboy') {
		$symbol = '\N';
	} elsif (lc($name) eq 'ovbaloon') {
		$symbol = '\O';
	} elsif (lc($name) eq 'parking') {
		$symbol = '\P';
	} elsif (uc($name) eq 'QUAKE') {
		$symbol = '\Q';
	} elsif (lc($name) eq 'rest') {
		$symbol = '\R';
	} elsif (lc($name) eq 'sattelite') {
		$symbol = '\S';
	} elsif (lc($name) eq 'thunder') {
		$symbol = '\T';
	} elsif (uc($name) eq 'SUNNY') {
		$symbol = '\U';
	} elsif (uc($name) eq 'VORTAC') {
		$symbol = '\V';
	} elsif (uc($name) eq 'NWS') {
		$symbol = '\W';
	} elsif (lc($name) eq 'pharmacy') {
		$symbol = '\X';
	} elsif (lc($name) eq 'radio') {
		$symbol = '\Y';
	} elsif (lc($name) eq 'device') {
		$symbol = '\Y';
	} elsif (lc($name) eq 'wcloud') {
		$symbol = '\[';
	} elsif (lc($name) eq 'GPS') {
		# $symbol = '\' . '\';
	} elsif (lc($name) eq 'aircraft2') {
		$symbol = '\^';
	} elsif (lc($name) eq 'WX') {
		$symbol = '\_';
	} elsif (lc($name) eq 'rain') {
		$symbol = '\`';

	} elsif (uc($name) eq 'ARRL') {
		$symbol = '\a';
	} elsif (uc($name) eq 'ARES') {
		$symbol = '\a';
	} elsif (uc($name) eq 'WINLINK') {
		$symbol = '\a';
	} elsif (uc($name) eq 'DSTAR') {
		$symbol = '\a';
	} elsif (uc($name) eq 'CD') {
		$symbol = '\c';
	} elsif (uc($name) eq 'DXSPOT') {
		$symbol = '\d';
	} elsif (lc($name) eq 'sleet') {
		$symbol = '\e';
	} elsif (lc($name) eq 'funnel') {
		$symbol = '\f';
	} elsif (lc($name) eq 'galeflags') {
		$symbol = '\g';
	} elsif (uc($name) eq 'HAMFEST') {
		$symbol = '\h';
	} elsif (uc($name) eq 'STORE') {
		$symbol = '\h';
	} elsif (uc($name) eq 'POI') {
		$symbol = '\i';
	} elsif (lc($name) eq 'workzone') {
		$symbol = '\j';
	} elsif (lc($name) eq '4x4') {
		$symbol = '\k';
	} elsif (lc($name) eq 'areas') {
		$symbol = '\l';
	} elsif (lc($name) eq 'value') {
		$symbol = '\m';
	} elsif (uc($name) eq 'OVTRIAGLE') {
		$symbol = '\n';
	} elsif (lc($name) eq 'scircle') {
		$symbol = '\o';
	} elsif (lc($name) eq 'restroom') {
		$symbol = '\r';
	} elsif (lc($name) eq 'restrooms') {
		$symbol = '\r';
	} elsif (uc($name) eq 'SHIP') {
		$symbol = '\s';
	} elsif (lc($name) eq 'tornado') {
		$symbol = '\t';
	} elsif (uc($name) eq 'TRUCK') {
		$symbol = '\u';
	} elsif (lc($name) eq 'van') {
		$symbol = '\v';
	} elsif (lc($name) eq 'flooding') {
		$symbol = '\w';
	} elsif (lc($name) eq 'wreck') {
		$symbol = '\x';
	} elsif (lc($name) eq 'skywarn') {
		$symbol = '\y';
	} elsif (lc($name) eq 'shelter') {
		$symbol = '\z';
	} elsif (lc($name) eq 'TNC2') {
		$symbol = '\|';
	} elsif (lc($name) eq 'TNC3') {
		$symbol = '\~';
	};
	return $symbol;
}



###############################################################################
# Reverse Geocoding
###############################################################################
sub reverse_geocode($$) {
	my($lat, $lng) = @_;

print "zero\n'";
return;
	my $ua = LWP::UserAgent->new;
	$ua->agent(
		agent => "$AppName v$Version",
		timeout => 5,
		max_redirect => 0,
	);
print "one\n";
	my $url = "http://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&sensor=true";
print "two\n";

	my $req = HTTP::Request->new(GET => $url);
	my $res = $ua->simple_request($req);
print "three\n";

	if ($res->status_line !~ /^(\d+)\s+(.*)$/) {
		print "reverse_geocode: HTTP status line could not be parsed for " . $url . ": " . 
			$res->status_line;
		return;
	}
print "four\n";

	my($status_code, $status_message) = ($1, $2);

	if ($status_code ne 200) {
		print "reverse_geocode: HTTP error $status_code: $status_message - " . $url;
		return;
	}

	if ($res->header('Content-Type') !~ /application\/json/) {
		print "reverse_geocode: Server returned wrong content type (should be application/json): " . 
			$res->header('Content-Type') . " - " . $url;
		return;
	}

	my $state = from_json($res->content);
	print "  state\n" . Dumper($state);

	return if (!defined $state);
	return if ($state->{'status'} ne 'OK');
	return if (!defined $state->{'results'});
	my @res = @{ $state->{'results'} };
	$res = shift @res;
	return if (!defined $res->{'formatted_address'});

	return $res->{'formatted_address'};
}

sub status_msg($) {
	my($s) = @_;

	if ($Net && $config->{'arse_status_group'}) {
		$Net->{'tms'}->queue_msg($config->{'arse_status_group'}, $s, 1);
	}
}



###############################################################################
# State data
###############################################################################
sub Dump_State() {
	print color('green'), "Dump State Called.\n", color('reset');
	if (!defined $State_Dump_File) {
		print color('red'), "State_Dump_File $State_Dump_File not defined.", color('reset');
		return;
	}

	my %state = (
		'time' => time(),
		'uptime' => time() - $start_time,
		'ars_clients' => $Net->{'ars_clients'},
		'ars_clients_here' => $Net->{'ars_clients_here'},
		'tms_q_len' => $Net->{'tms'}->{'queue_length'},
		'tms_msg_rx' => $Net->{'tms'}->{'msg_rx'},
		'tms_msg_rx_dupe' => $Net->{'tms'}->{'msg_rx_dupe'},
		'tms_msg_tx' => $Net->{'tms'}->{'msg_tx'},
		'tms_msg_tx_ok' => $Net->{'tms'}->{'msg_tx_ok'},
		'tms_msg_tx_group' => $Net->{'tms'}->{'msg_tx_group'},
		'tms_msg_tx_drop' => $Net->{'tms'}->{'msg_tx_drop'},
		'bytes_rx' => $Net->{'bytes_rx'},
		'bytes_tx' => $Net->{'ars'}->{'bytes_tx'} + $Net->{'tms'}->{'bytes_tx'} + $Net->{'loc'}->{'bytes_tx'},
		'pkts_rx' => $Net->{'pkts_rx'},
		'pkts_tx' => $Net->{'ars'}->{'pkts_tx'} + $Net->{'tms'}->{'pkts_tx'} + $Net->{'loc'}->{'pkts_tx'},
		'registry' => $Net->{'registry'}
	);

	my $TempFile = $State_Dump_File . '.tmp';
	if (!open(F, ">$TempFile")) {
		print color('yellow'), "  Could not open $TempFile for writing: $!\n", color('reset');
		return;
	}

	if (!print F to_json(\%state)) {
		print color('yellow'),  "  Could could not write to $TempFile: $!\n", color('reset');
		close(F);
		return;
	}

	if (!close(F)) {
		print color('yellow'),  "  Could could not close $TempFile after writing: $!\n", color('reset');
		return;
	}

	if (!rename($TempFile, $State_Dump_File)) {
		print color('yellow'),  "  Could could not rename $TempFile to " .
			$State_Dump_File . ": $!\n", color('reset');
		return;
	}
	if ($Verbose >= 1) {print "  Dump State Done.\n";}
}

sub Reload_State() {
	print color('green'), "Reload State Called.\n", color('reset');
	if (!defined $State_Dump_File) {
		print color('red'), "State_Dump_File $State_Dump_File not defined.", color('reset');
		return;
	}

	if (!open(F, $State_Dump_File)) {
		print color('yellow'),  "  Could could not open state dump " . $State_Dump_File .
			" for reading: $!\n", color('reset');
		return;
	}

	my $l = <F>;
	print color('grey12'), "  l " . Dumper($l), color('reset');
	my $state = from_json($l);
	#print "  state " . Dumper($state);

	close(F);

	return if (!defined $state->{'registry'});

	my $reg = $Net->{'registry'};
	foreach my $Radio (values %{ $state->{'registry'} }) {
		if (!defined $reg->{$Radio->{'id'}}) {
			print "  Reload_State: radio " . $Radio->{'id'} . " not configured, ignoring\n";
			next;
		}
		print "  Reload_State: reloading radio " . $Radio->{'id'} . "\n";
		for my $k ('last_poll_tx', 'last_poll_rx', 'first_heard', 'last_heard', 'away_reason', 'state', 'heard_what') {
			$reg->{$Radio->{'id'}}{$k} = $Radio->{$k};
		}
	}

	$Net->registry_scan(1);
	print "  Reload State Done.\n";
}



###############################################################################
# Process Received TMS Command
###############################################################################
sub Process_Rx_Msg($) {
	my($Rx) = @_;

	print color('green'),"Process_Rx_Msg\n", color('reset');
	#print Dumper($Rx);

	if ($Rx->{'text'} =~ /^\s*([a-z]+)\s*/i) {
		my($cmd) = lc($1);
		print"  Command = '$cmd' from = $Rx->{'src_id'}\n";
		my $t = $Rx->{'text'};
		$t =~ s/^\s+//;
		$t =~ s/\s+$//;
		$t =~ s/\s+/ /g;
		my @args = split(' ', $t);

		if (defined $cmds{$cmd}) {
			$cmds{$cmd}($Rx, \@args);
			return;
		}
	} else {
		print color('yellow'), "  Invalid Command.\n", color('reset');
	}

	Cmd_Help($Rx);
}



###############################################################################
# Cmd APRS_IS
###############################################################################
sub Cmd_APRS_IS($$) {
	my($Rx, $args) = @_;

	my($cmd, $dst, @words) = @$args;
	my $msg = join(' ', @words);
	print color('green'), "Cmd_APRS_IS\n", color('reset');

	return if (!$APRS_IS);

	my $now = time();
	# Send specific help for incomplete messages.
	if (!defined $dst || $dst eq '' || $msg eq '') {
		$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Usage: APRS <callsign> <message>');
		return;
	}

	$dst = uc($dst); # Make destination callsign uppercase.
	print "  cmd = $cmd, dst = $dst, msg = $msg\n";

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
	my $MsgID = "$min$sec";

	my $APRS_IS_Message = Ham::APRS::FAP::make_message(
		$dst,
		$msg,
		$MsgID # seq if aknowlegement expected, up to 5 char.
	);
	print "  $APRS_IS_Message\n";

	my $Packet = sprintf('%s>APTR01:%s', $Rx->{'registry'}->{'callsign'}, $APRS_IS_Message);
	print color('blue'), "  $Packet\n", color('reset');
	my $Res = $APRS_IS->sendline($Packet);

	if (!$Res) {
		print color('red'), "  Error sending APRS-IS message from " .
			$Rx->{'registry'}->{'callsign'} . " to $dst\n", color('reset');
		$APRS_IS->disconnect();
	}
}

sub Cmd_APRS_IS_Obj($$) {
	my($Rx, $args) = @_;

	my($cmd, $name, $symbol_name, @words) = @$args;
	my $comment = join(' ', @words);
	print color('green'), "Cmd_APRS_IS_Obj\n", color('reset');

	return if (!$APRS_IS);

	my $now = time();
	# Send specific help for incomplete messages.
	if (!defined $name || $name eq '' || !defined $symbol_name || $symbol_name eq '' || $comment eq '') {
		$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Usage: Obj <name> <symbol> <comment>');
		return;
	}

	my $symbol = APRS_Symbol_by_Name($symbol_name); # Symbol
	my $APRS_IS_Object = Ham::APRS::FAP::make_object(
		$name,
		0, # timestamp (current == 0)
		$Rx->{'registry'}->{'last_lat'},
		$Rx->{'registry'}->{'last_lng'},
		(defined $symbol) ? $symbol : '\.', # symbol
		-1, # Speed
		-1, # Course
		-10000, # Altitude
		1, # Status Alive
		1, # Compression
		0, # Position Ambiguity
		$comment # Comment
	);
	print $APRS_IS_Object;

	my $Packet = sprintf('%s>APTR01:%s', $Rx->{'registry'}->{'callsign'}, $APRS_IS_Object);
	print color('blue'), "  $Packet\n", color('reset');
	my $Res = $APRS_IS->sendline($Packet);

	if (!$Res) {
		print color('red'), "  Error sending APRS-IS object from " .
			$Rx->{'registry'}->{'callsign'} . " $name\n", color('reset');
		$APRS_IS->disconnect();
	}
}

###############################################################################
# Cmd_Ctrl
###############################################################################
sub Cmd_Ctrl($$) {
	my($Rx, $args) = @_;

	my($cmd, $sub_cmd, @words) = @$args;
	my $msg = join(' ', @words);
	print color('green'), "Cmd_Ctrl user $Rx->{'registry'}->{'callsign'}, ID $Rx->{'src_id'}" .
		" sub_cmd $sub_cmd value $msg\n", color('reset');

	return if (!$APRS_IS);
	# APRS enable/disable control:
	if (lc($sub_cmd) eq 'aprs') {
		$APRS_IS_Enable = $msg;
		$Net->{'tms'}->queue_msg("APRS-IS Enable set to = " . $APRS_IS_Enable);
	}
	# Analog Aux1 port using GPIO 21 (pins 40):
#	if (lc($dst) eq 'aux1') {
#		if ($msg == 0 ){
#			Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_21, 0);
#		} else {
#			Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_21, 1);
#		};
#	};
	# Kill app:
	if (lc($sub_cmd) eq 'kill') {
		$Net->{'tms'}->queue_msg($Admin_Radio_ID, "Radio " . $Rx->{'src_id'} . ' killed $AppName.');
		die("Warning: radio " . $Rx->{'src_id'} . " killed $AppName.");
	}
}

###############################################################################
# Cmd_email
###############################################################################
sub Cmd_email($$) {
	my($Rx, $args) = @_;

	my($cmd, $dst, @words) = @$args;
	my $msg = join(' ', @words);
	print color('green'), "Cmd_email . $Rx->{'registry'}->{'callsign'} To: $dst " .
		"Body: $msg\n", color('reset');

	my $subject= "DMR originated e-mail from: $Rx->{'registry'}->{'name'}, callsign " .
		$Rx->{'registry'}->{'callsign'};
	my $body= $msg . "\n\n $Rx->{'registry'}->{'name'}\n $Rx->{'registry'}->{'callsign'}";

#	my $mail=Email::Send::SMTP::Gmail->new( -smtp=>'smtp.gmail.com',
#		-login=>$Rx->{'registry'}->{'email_username'},
#		-pass=>$Rx->{'registry'}->{'email_password'},
#		-layer=>'ssl',
#		-port=>465,
##		-verbose=>1,
##		-debug=>1
#		);
#	$mail->send( -to=>$dst,
#	-subject=>$subject,
#	-body=>$body,
#	-contenttype=>'text/html',
#	-layer=>'ssl',
#	-port=>465,
##	-verbose=>1,
##	-debug=>1
#	);
#	$mail->bye;

	print "email Sent by: $Rx->{'registry'}->{'name'} $Rx->{'registry'}->{'callsign'}.\n";
}

###############################################################################
# Cmd_Help
###############################################################################
sub Cmd_Help($) {
	my($Rx) = @_;

	# Reply with a TMS listing the commands available.
	print color('green'), "Cmd_Help to RadioID $Rx->{'src_id'}\n", color('reset');
	$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Commands: A or APRS, Ctrl, e or email, h or Help, Ping, SMS, WEA, W or Who');
}

###############################################################################
# Cmd_Ping
###############################################################################
sub Cmd_ping($$) {
	my($Rx) = @_;

	print color('green'), "Cmd_ping from $Rx->{'src_id'}\n", color('reset');
	my $datestring = gmtime();
	$Net->{'tms'}->queue_msg($Rx->{'src_id'}, "Pong to: $Rx->{'src_id'} GMT=$datestring.");
}

###############################################################################
# Cmd_SMS
###############################################################################
sub Cmd_SMS($$) {
	my($Rx, $args) = @_;

	my($cmd, $dst, @words) = @$args;
	my $msg = join(' ', @words);
	print color('green'), "Cmd_SMS from $Rx->{'registry'}->{'callsign'} to $dst msg = $msg\n", color('reset');

	my $Repliable = 0;
	# This block is from Bulk SMS code samples, Perl version.
	my $ua = LWP::UserAgent->new(timeout => 30);
	my $res = $ua->request(POST 'http://bulksms.vsms.net/eapi/submission/send_sms/2/2.0',
		Header => 'content_type: application/x-www-form-urlencoded',
		Content => [
			username => $sms_username,
			password => $sms_password,
			msisdn => $dst,
#			repliable => $Repliable,
			message => "$Rx->{'registry'}->{'callsign'}:$msg",
		]
	);

	if ($res->is_error) {
		print color('red'), "HTTP request error, with error code " . $res->code .
			", and body:\n\n" . $res->error_as_HTML, color('reset');
	}

	my ($result_code, $result_string, $batch_id) = split(/\|/, $res->content);

	if ($result_code eq '0') {
		print color('blue');
		print "  Message sent: batch $batch_id\n" .
			"username=$sms_username" . 
			"password=$sms_password" . 
			"msisdn=$dst" .
			"message=$Rx->{'registry'}->{'callsign'}:$msg\n";
		print , color('reset');
		$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'SMS Sent.');
	} else {
		print color('red'), "Error sending: $result_code: $result_string\n", color('reset');
		$Net->{'tms'}->queue_msg($Rx->{'src_id'}, "SMS Error sending: $result_code: $result_string.");
	}
}

###############################################################################
# Weather
###############################################################################
sub Cmd_WEA($$) {
	my($Rx, $args) = @_;

	my($cmd, @words) = @$args;
	my $msg = join(' ', @words);
	print color('green'), "Cmd_WEA $msg\n", color('reset');

	# Send specific help for incomplete messages.
	if (!defined $msg || $msg eq '') {
		$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Usage: Wea <RadioID>');
		return;
	}

	# Wunderground Api was deprecated.
	# Process...
	$msg = "Sorry, Wunderground Api was deprecated.";
	
	#$msg = "$place at $updated Temp: $temp_c, wind: $wind_kmph kmph $wind_dir, Humidity: $humidity, Press: $pressure";
	print "  Message: $msg\n";

	print "Weather report to radio: $Rx->{'registry'}->{'callsign'} > $msg\n";
	$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'WEA: ' . $msg);
}

###############################################################################
# Command Where
###############################################################################
sub Cmd_Where($$) {
	my($Rx, $args) = @_;
	
	my($cmd, $dst) = @$args;
	print color('green'), "Cmd_Where from $Rx->{'src_id'} about $Rx->{'src_id'}\n", color('reset');

	# Send specific help for incomplete messages.
	if (!defined $dst || $dst eq '') {
		$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Usage: Where <RadioID>');
		return;
	}

	my $now = time();
	if (defined $dst) {
		my @matches;
		my $match;
		foreach my $Radio (values %{ $Net->{'registry'} }) {
			my $s = (defined $Radio->{'callsign'}) ? $Radio->{'callsign'} : $Radio->{'id'};
			if (index($Radio->{'id'}, $dst) >= 0) {
				$match = $Radio;
				push @matches, $s;
				next;
			}
			if (defined $Radio->{'callsign'} && index(uc($Radio->{'callsign'}), uc($dst)) >= 0) {
				$match = $Radio;
				push @matches, $s;
				next;
			}
		}
		if (!@matches) {
			$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'No match for ' . $dst);
			return;
		}
		if ($#matches > 0) {
			$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Multiple matches: ' . join(' ', @matches));
			return;
		}

		my $s = '' . join(' ', @matches);
		if (defined $match->{'last_heard'}) {
			$s .= ' Heard ' . dur_str($now - $match->{'last_heard'});
		}
		# Test location
		$match->{'last_lat'} = 51.5034066;
		$match->{'last_lng'} = -0.1275923;

		if ($match->{'last_loc'} && ($match->{'last_lat'}) && ($match->{'last_lng'})) {
			$s .= ' Loc ' . dur_str($now - $match->{'last_loc'});
			$s .= ' Lat ' . $match->{'last_lat'};
			$s .= ' Lng ' . $match->{'last_lng'};
			my($addr) = reverse_geocode($match->{'last_lat'}, $match->{'last_lng'});
			$s .= ' ' . $addr if (defined $addr);
		}

		print "  Reply = $s\n";
#		$Net->{'tms'}->queue_msg($Rx->{'src_id'}, $s);
		return;
	}

	my @Here;
	foreach my $Radio (sort { $b->{'last_heard'} <=> $a->{'last_heard'} } values %{ $Net->{'registry'} }) {
		#print Dumper($Radio);
		if ($Radio->{'state'} eq 'here') {
			print "  Radio: " . Dumper($Radio);
			my $s = (defined $Radio->{'callsign'}) ? $Radio->{'callsign'} : $Radio->{'id'};
			if ($now - $Radio->{'last_heard'} > $ARS_Timeout/2) {
				$s = lc($s);
			}
			if (defined $Radio->{'last_loc'} && $now - $Radio->{'last_loc'} < 15*60 && ($Radio->{'last_lat'})) {
				$s .= '*'; 
			}
			push @Here, $s;
			print "  Reply = $s\n";
		}
	}
	$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Available: ' . join(' ', @Here));
}

###############################################################################
# Command Who
###############################################################################
sub Cmd_Who($$) {
	my($Rx, $args) = @_;

	my($cmd, $dst) = @$args;
	print color('green'), "Cmd_Who from $Rx->{'src_id'} ask about $dst\n", color('reset');

	# Send specific help for incomplete messages.
	if (!defined $dst || $dst eq '') {
		$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Usage: Who <RadioID>');
		return;
	}

	my $now = time();
	if (defined $dst) {
		my @matches;
		my $match;
		foreach my $Radio (values %{ $Net->{'registry'} }) {
			my $s = (defined $Radio->{'callsign'}) ? $Radio->{'callsign'} : $Radio->{'id'};
			if (index($Radio->{'id'}, $dst) >= 0) {
				$match = $Radio;
				push @matches, $s;
				next;
			}
			if (defined $Radio->{'callsign'} && index(uc($Radio->{'callsign'}), uc($dst)) >= 0) {
				$match = $Radio;
				push @matches, $s;
				next;
			}
		}
		if (!@matches) {
			$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'No match for ' . $dst);
			return;
		}
		if ($#matches > 0) {
			$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Multiple matches: ' . join(' ', @matches));
			return;
		}

		my $s = '' . join(' ', @matches);
		if (defined $match->{'last_heard'}) {
			$s .= ' last heard ' . dur_str($now - $match->{'last_heard'});
		}

		print "  Reply = $s\n";
		$Net->{'tms'}->queue_msg($Rx->{'src_id'}, $s);
		return;
	}

	my @Here;
	foreach my $Radio (sort { $b->{'last_heard'} <=> $a->{'last_heard'} } values %{ $Net->{'registry'} }) {
		#print Dumper($Radio);
		if ($Radio->{'state'} eq 'here') {
			print "  Radio: " . Dumper($Radio);
			my $s = (defined $Radio->{'callsign'}) ? $Radio->{'callsign'} : $Radio->{'id'};
			if ($now - $Radio->{'last_heard'} > $ARS_Timeout/2) {
				$s = lc($s);
			}
			if (defined $Radio->{'last_loc'} && $now - $Radio->{'last_loc'} < 15*60 && ($Radio->{'last_lat'})) {
				$s .= '*'; 
			}
			push @Here, $s;
			print "  Reply = $s\n";
		}
	}
	$Net->{'tms'}->queue_msg($Rx->{'src_id'}, 'Available: ' . join(' ', @Here));
}

sub dur_str($) {
	my($s) = @_;

	my $str = '';
	if ($s < 0) {
		$str = "-";
		$s *= -1;
	}

	my $origs = $s;
	if ($s < 1) {
		$str .= "0s";
		return $str;
	}

	if ($s >= 24 * 60 * 60) {
		my $d = POSIX::floor($s / (24 * 60 * 60));
		$s -= $d * 24 * 60 * 60;
		$str .= $d . 'd ';
	}

	if ($s >= 60 * 60) {
		my $d = POSIX::floor($s / (60 * 60));
		$s -= $d * 60 * 60;
		$str .= $d . "h";
	}

	if ($s >= 60) {
		my $d = POSIX::floor($s / 60);
		$s -= $d * 60;
		$str .= $d . "m";
	}

	if ($s >= 1) {
		if ($origs < 60*60) {
			$str .= POSIX::floor($s) . "s";
		}
	}

	return $str;
}



###############################################################################
# 
###############################################################################
sub spool_read($) {
	my($f) = @_;

	if (!open(F, $f)) {
		print "Could not open $f for reading: $!\n";
		return;
	}

	my $dst_l = <F>;
	my $msg = '';
	while (my $l = <F>) {
		$msg .= $l;
	}

	if (!close(F)) {
		print "Could not close $f after reading: $!\n";
		return;
	}

	$dst_l =~ s/\s+//gs;
	if ($dst_l !~ /^(\@{0,1})(\d+)$/) {
		print "Spool file $f contained invalid destination: '$dst_l'\n";
		return;
	}
	my $group_msg = ($1 eq '@') ? 1 : 0;
	my $dst = $2;

	$msg =~ s/^\s+//s;
	$msg =~ s/\s+$//s;
	$msg =~ s/\s+/ /gs;

	if ($msg eq '') {
		print "Spool file $f contained empty message\n";
		return;
	}

	print "MSG from spool to $dst_l: $msg\n";
	$Net->{'tms'}->queue_msg($dst, $msg, $group_msg);
}

sub scan_spool($)
{
	my($dir) = @_;

	opendir(D, $dir) || die "Could not open $dir for reading directory: $!";
	my @files = grep { /\.msg$/ && -f "$dir/$_" } readdir(D);
	closedir(D) || die "Could not close directory $dir: $!";

	foreach my $f (@files) {
		my $fp = "$dir/$f";
		print "processing spool file '$fp'\n";
		spool_read($fp);
		unlink($fp) || die "Could not unlink '$fp' after processing: $!";
	}
}



###############################################################################
# 
###############################################################################
sub Consider_LOC_Requests()
{
	my $reg = $Net->{'registry'};

	foreach my $id (keys %{ $reg }) {
		if (defined $reg->{$id}->{'consider_loc_req'} && $reg->{$id}->{'consider_loc_req'} < time()) {
			my $Radio = $reg->{$id};
			delete $Radio->{'consider_loc_req'};
			next if ($Radio->{'state'} ne 'here');
			# loc request configured, check if we have received locs recently
			if (!defined $Radio->{'last_loc'} || $Radio->{'last_loc'} < time() - 7200) {
				$Net->{'loc'}->request_locs($id, $GPS_Req_Interval - 10 + int(rand(30)));
			}
		}
	}
}



###############################################################################
# Hot Keys
###############################################################################
sub HotKeys {
	# Hot Keys.
	if ($HotKeys) {
		if (not defined (my $key = ReadKey(-1))) {
			# No key yet.
		} else {
			# Testing user data
			my $Rx;
			$Rx->{'src_id'} = 3341100;
			$Rx->{'msg'} = 'msg';
			$Rx->{'class'} = 'tms';
			$Rx->{'registry'}->{'callsign'} = 'XE1F-1';
			$Rx->{'registry'}->{'name'} = 'Juan C';
			$Rx->{'registry'}->{'symbol'} = '/[';

			switch (ord($key)) {
				case 0x1B { # Escape
					print "EscKey Pressed.\n";
					$Run = 0;
				}
				case ord('A') { # 'A'
					$Rx->{'text'} = 'aprs KM4NNO-7 Testing msg 01';
					print "  HotKeys A Rx\n" . Dumper($Rx);
					Process_Rx_Msg($Rx);
					$APRS_Verbose = 1;
				}
				case ord('a') { # 'a'
					$APRS_Verbose = 0;
				}
				case ord('H') { # 'H'
					$Verbose = 1;
				}
				case ord('h') { # 'h'
					PrintMenu();
					$Verbose = 0;
				}
				case ord('L') { # 'L'
					$Rx->{'text'} = 'where XE1F-7';
					print "  HotKeys L Rx\n" . Dumper($Rx);
					Process_Rx_Msg($Rx);
				}
				case ord('M') { # 'M'
					# Send a TMS.
					$Rx->{'text'} = 'Test 01.';
					print "  HotKeys M Rx\n" . Dumper($Rx);
					Process_Rx_Msg($Rx);
				}
				case ord('O') { # 'O'
					# TMS Object.
					$Rx->{'text'} = 'Obj N0CALL power Testing Object 01';
					print "  HotKeys O Rx\n" . Dumper($Rx);
					Process_Rx_Msg($Rx);
				}
				case ord('Q') { # 'Q'
					$Run = 0;
				}
				case ord('q') { # 'q'
					$Run = 0;
				}
				case ord('S') { # 'S'
					$Rx->{'text'} = 'sms +525554356002 Testing SMS 01';
					print "  HotKeys S Rx\n" . Dumper($Rx);
					Process_Rx_Msg($Rx);
				}
				case ord('T') { # 'T'
					TRBO::NET::debug(1);
					TRBO::Common::debug(1);
					TRBO::DupeCache::debug(1);
				}
				case ord('t') { # 't'
					TRBO::NET::debug(0);
					TRBO::Common::debug(0);
					TRBO::DupeCache::debug(0);
				}
				case ord('W') { # 'W'
					$Rx->{'text'} = 'Wea MMMX';
					print "  HotKeys W Rx\n" . Dumper($Rx);
					Process_Rx_Msg($Rx);
				}
				case ord('w') { # 'w'
					$Rx->{'text'} = 'Who 3341001';
					print "  HotKeys W Rx\n" . Dumper($Rx);
					Process_Rx_Msg($Rx);
				}
				case 0x41 { # 'UpKey'
					print "UpKey Pressed.\n";
				}
				case 0x42 { # 'DownKey'
					print "DownKey Pressed.\n";
				}
				case 0x43 { # 'RightKey'
					print "RightKey Pressed.\n";
				}
				case 0x44 { # 'LeftKey'
					print "LeftKey Pressed.\n";
				}
				case '[' { # '['
					print "[ Pressed (used also as an escape char).\n";
				}
				else {
					if ($Verbose) {
						print sprintf(" %x", ord($key));
						print " Key Pressed\n";
					}
				}
			}
		}
	}
}



#################################################################################
# Main Loop #####################################################################
#################################################################################
sub MainLoop {
	HotKeys(); # Keystrokes events.
	if ($APRS_IS) {
		if (!$APRS_IS->connected()) {
			print color('bright_yellow'), "Reconnecting APRS-IS.\n", color('reset');
			APRS_IS_Connect();
		}

		# This makes a 1 sec timer for the loop.
		while (my $APRS_IS_Raw_Rx = $APRS_IS->getline(1)) {
			if ($APRS_Verbose >= 1) {print color('grey12'), "  APRS-IS RAW: $APRS_IS_Raw_Rx\n", color('reset');}
			next if ($APRS_IS_Raw_Rx =~ /^#/);
			APRS_IS_Process_Rx_Net_Data($APRS_IS_Raw_Rx);
		}

		# Send Gateway APRS position.
		if (time() >= $APRS_NextTimer) {
			if (defined $My_Latitude && defined $My_Longitude && abs($My_Latitude) > 0.1 && 
					abs($My_Longitude) > 0.1) {
				print "  APRS-IS: beaconing Gateway position\n";
				# Push my Gateway LOC
				push @upd_q, {
					'name' => $APRS_Callsign,
					'timestamp' => 0,# timestamp (current == 0)
					'latitude' => $My_Latitude,
					'longitude' => $My_Longitude,
					'symbol' => $My_Symbol,
					'speed' => -1,
					'course' => -1,
					'altitude' => $My_Altitude,
					'status' => 1,
					'comment' => $My_Comment,
					'callsign' => $APRS_Callsign
				};
				APRS_IS_Push_Position_Updates();
			}
			$APRS_NextTimer = time() + $APRS_Interval;
		}
	}

	# Scan for messages which should be sent
	if (defined $config->{'tms_incoming_spool'}) {
		scan_spool($config->{'tms_incoming_spool'});
	}

	my $Rx = $Net->receive();

	if (!$Rx) {
		#print "No Rx.\n";
		$Net->registry_scan();
		$Net->{'tms'}->queue_run();
		$aprs_msg_cache->scan(300);
		Consider_LOC_Requests();
		Dump_State();
		#next;
	}
	if ($Verbose) {print "  Rx\n" . Dumper($Rx);}

	if (!defined $Rx->{'class'}) {
		# ouch!

	} elsif ($Rx->{'class'} eq 'ars') {
		if ($Rx->{'msg'} eq 'hello') {
			# Could have some policy here on what to accept...

			# Register radio internally and start polling it
			$Net->register_radio($Rx);
			# After 10 minutes, check if we're getting LOC packets, and if not,
			# ask for them
			if ($GPS_Req_Interval) {
#				$Rx->{'registry'}->{'consider_loc_req'} = time() + 600;
				$Rx->{'registry'}->{'consider_loc_req'} = time() + 60;
			}
		}

	} elsif ($Rx->{'class'} eq 'loc') {
		if ($Rx->{'msg'} eq 'loc' && defined $Rx->{'latitude'}) {
			if (!($GPS_Req_Interval)) {
				# Got LOC but not requested so Disable it.
				$Net->{'loc'}->request_no_locs($Rx->{'src_id'});
			} elsif (defined $Rx->{'registry'} && defined $Rx->{'registry'}->{'callsign'} 
					&& APRS_IS_Consider_Beacon($Rx)) {
				if ($Mode){
					push @upd_q,{
						'name' => $Rx->{'registry'}->{'callsign'},
						'latitude' => $Rx->{'latitude'},
						'longitude' => $Rx->{'longitude'},
						'symbol' => $Rx->{'registry'}->{'symbol'},
						'speed' => $Rx->{'speed'},
						'course' => -1,
						'altitude' => $Rx->{'altitude'},
						'status' => 1,
						'comment' => $Rx->{'registry'}->{'comment'},
						'callsign' => $Rx->{'registry'}->{'callsign'}
					};
					print "Mode 1.\n";
					print $Rx->{'registry'}->{'callsign'} . "\n";
				} else {
					push @upd_q,{
						'name' => $Rx->{'registry'}->{'callsign'},
						'latitude' => 19.380834,# Test Location.
						'longitude' => -99.176753,# Test Location.
						'symbol' => $Rx->{'registry'}->{'symbol'},
						'speed' => -1,
						'course' => -1,
						'altitude' => 2000, # Test Location.
						'status' => 1,
						'comment' => $Rx->{'registry'}->{'comment'},
						'callsign' => $Rx->{'registry'}->{'callsign'}
					};
					print "Mode 0.\n";
					print $Rx->{'registry'}->{'callsign'} . "\n";
				}
				APRS_IS_Push_Position_Updates();
			}
		}
		$Rx->{'registry'}->{'last_loc'} = time();

	} elsif ($Rx->{'class'} eq 'tms') {
		if ($Rx->{'msg'} eq 'msg') {
			Process_Rx_Msg($Rx);
		}
	}
	if ($Verbose >= 5) { print "Looping the right way.\n"; }
}

