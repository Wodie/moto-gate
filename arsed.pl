#!/usr/bin/perl

# ARS-E daemon: ARS Extendable

# Strict and warnings recommended.
use strict;
use warnings;
use Switch;
use Config::IniFiles;
use Data::Dumper qw(Dumper);

#use Data::Dumper;
use YAML::Tiny;
use Digest::MD5 qw(md5_hex);
use JSON;
use POSIX;

use Ham::APRS::IS;
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
my $AppName = 'Arsed';
use constant VersionInfo => 2;
use constant MinorVersionInfo => 00;
use constant RevisionInfo => 0;
my $Version = VersionInfo . '.' . MinorVersionInfo . '-' . RevisionInfo;
print "\n##################################################################\n";
print "	*** $AppName v$Version ***\n";
print "	Released: January 22, 2022. Created March 07, 2015.\n";
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
sub status_msg($);
sub Reload_State();
sub APRS_IS_Init();



# Detect Target OS.
my $OS = $^O;
print color('green'), "Current OS is $OS\n", color('reset');
print "----------------------------------------------------------------------\n";



# Load Settings ini file.
print color('green'), "Loading Settings...\n", color('reset');
my $config = Config::IniFiles->new( -file => "/home/pi/moto_x/config.ini");
# Settings:
my $State_Dump_File = $config->val('Settings', 'state_dump');
my $Mode = 1;
my $HotKeys = $config->val('Settings', 'HotKeys');
my $Verbose = $config->val('Settings', 'Verbose');
print "  State Dump File = $State_Dump_File\n";
print "  HotKeys = $HotKeys\n";
print "  Verbose = $Verbose\n";
print "----------------------------------------------------------------------\n";



# Mototrbo
print color('green'), "Loading Mototrbo settings...\n", color('reset');
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
print "----------------------------------------------------------------------\n";



# TRBO::NET
print color('green'), "Creating TRBO::NET\n", color('reset');
my $Net = TRBO::NET->new(
	'ars_port' => $ARS_Port,
	'loc_port' => $Loc_Port,
	'tms_port' => $TMS_Port,
	'debug' => 1,
	'cai_net' => $CAI_Network,
	'cai_group_net' => $CAI_Group_Network,
	'registry_poll_interval' => $ARS_Ping_Interval,
	'registry_timeout' => $ARS_Timeout,
);
print "----------------------------------------------------------------------\n";



# APRS-IS:
print color('green'), "Loading APRS-IS...\n", color('reset');
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
my $My_NAC = $config->val('APRS', 'NAC');
my $My_Comment = $config->val('APRS', 'APRSComment');
my $APRS_Verbose= $config->val('APRS', 'Verbose');
print "  Passcode = $APRS_Passcode\n";
print "  Suffix = $APRS_Suffix\n";
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
print "  NAC = $My_NAC\n";
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
		warn color('red'), "Failed to create APRS-IS Server object: " . $APRS_IS->{'error'} .
			"\n", color('reset');
	}
	#Ham::APRS::FAP::debug(1);
}
print "----------------------------------------------------------------------\n";



# Load Users conf file.
print color('green'), "Loading Users...\n", color('reset');
my $Users;
my @cfgfiles = ( '/home/pi/moto_x/users.conf','users.conf', '/usr/local/etc/users.conf', '/etc/users.conf' );
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
print "  Reading YAML configuration from   $cfgfile\n";
my $yaml = YAML::Tiny->new;
my $Conf = YAML::Tiny->read($cfgfile);
$Users = shift @$Conf;

#print color('grey12'), "  Users: " . Dumper($Users), color('reset');

# configure radios
while (my $Radio = shift @$Conf) {
	$Net->configure_radio($Radio);
	print "  radio: " . Dumper($Radio);
}

Reload_State();

my $aprs_msg_cache = new TRBO::DupeCache();

$aprs_msg_cache->init();

##############################################################################################
# Valid Commands
##############################################################################################
my %cmds = (
	'ctrl' => \&Cmd_Ctrl,
	'e' => \&Cmd_email,
	'email' => \&Cmd_email,
	'item' => \&Cmd_APRS_item,
	'h' => \&Cmd_Help,
	'help' => \&Cmd_Help,
	'obj' => \&Cmd_APRS_Obj,
	'ping' => \&Cmd_ping,
	'sms' => \&Cmd_SMS,
	'w' => \&Cmd_Who,
	'wea' => \&Cmd_WEA,
	'who' => \&Cmd_Who,
);

if (defined $APRS_Server) {
	APRS_IS_Init();
	# configure APRS commands
	$cmds{'a'} = $cmds{'aprs'} = \&Cmd_APRS;
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

###################################################################
# MAIN ############################################################
###################################################################
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



##################################################################
# Menu ###########################################################
##################################################################
sub PrintMenu {
	print "Shortcuts menu:\n";
	print "  Q/q = Quit.                      h = Help..\n";
	print "  A/a = APRS  show/hide verbose.   \n";
	print "  S/s = STUN  show/hide verbose.   t   = Test.\n\n";
}



##############################################################################################
# 
##############################################################################################
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



##############################################################################################
# Reverse Geocoding
##############################################################################################
sub reverse_geocode($$) {
	my($lat, $lng) = @_;

	my $ua = LWP::UserAgent->new;
	$ua->agent(
		agent => "$AppName v$Version",
		timeout => 5,
		max_redirect => 0,
	);

	my $url = "http://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&sensor=true";

	my $req = HTTP::Request->new(GET => $url);
	my $res = $ua->simple_request($req);

	if ($res->status_line !~ /^(\d+)\s+(.*)$/) {
		print "reverse_geocode: HTTP status line could not be parsed for " . $url . ": " . $res->status_line;
		return;
	}

	my($status_code, $status_message) = ($1, $2);

	if ($status_code ne 200) {
		print "reverse_geocode: HTTP error $status_code: $status_message - " . $url;
		return;
	}

	if ($res->header('Content-Type') !~ /application\/json/) {
		print "reverse_geocode: Server returned wrong content type (should be application/json): " . $res->header('Content-Type') . " - " . $url;
		return;
	}

	my $state = from_json($res->content);
	print Dumper($state);

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



##############################################################################################
# APRS-IS
##############################################################################################
sub APRS_IS_Init() {
	$APRS_IS = new Ham::APRS::IS($APRS_Server, $Callsign,
		'appid' => "$AppName v$Version",
		'passcode' => $APRS_Passcode,
		'filter' => 't/m');
	if (!$APRS_IS) {
		print color('red'), "Failed to create IS server object: " . $APRS_IS->{'error'} . "\n", color('reset');
		return;
	}
}

sub APRS_IS_Connect() {
	my $Res = $APRS_IS->connect('retryuntil' => 2);
	if (!$Res) {
		print color('red'), "Failed to connect to IS server: " . $APRS_IS->{'error'} . "\n", color('reset');
		return;
	}
	print color('green'), "APRS-IS: Connected.\n", color('reset');
}

sub APRS_IS_Process_Rx_Net_Data($) {
	my($RawData) = @_;

	my %PacketData;
	my $Res = Ham::APRS::FAP::parseaprs($RawData, \%PacketData);
	return if (!$Res);
	if (defined $PacketData{'type'} && $PacketData{'type'} eq 'message') {
		APRS_IS_Process_Rx_Net_Msg(\%PacketData);
	}
}

sub APRS_IS_Process_Rx_Net_Msg($) {
	my($PacketData) = @_;

	if ($APRS_Verbose >= 1) {print color('green'), "APRS-IS Process Rx Net Msg:\n", color('reset');}
	if ($APRS_Verbose >= 2) {print Dumper($PacketData);}

	# Check if APRS-IS Callsign is on registered users file.
	my $radio = $Net->registry_find_call($PacketData->{'destination'});
	return if (!defined $radio); # Not found

	my $cacheid;
	if (defined $PacketData->{'messageid'}) {
		$APRS_IS->sendline(APRS_IS_Make_Ack($PacketData->{'destination'}, $PacketData->{'srccallsign'}, $PacketData->{'messageid'}));
		$cacheid = md5_hex($PacketData->{'srccallsign'} . '_' . $PacketData->{'destination'} . '_' . $PacketData->{'messageid'});
	} else {
		$cacheid = md5_hex($PacketData->{'srccallsign'} . '_' . $PacketData->{'destination'} . '_' . $PacketData->{'message'});
	}

	if ($aprs_msg_cache->add($cacheid)) {
		print "APRS-IS message gateway dupe ignored: IS>TRBO "
			. $PacketData->{'srccallsign'} . '>' . $PacketData->{'destination'} . " " . $radio->{'id'}
			. ((defined $PacketData->{'messageid'}) ? '(id ' . $PacketData->{'messageid'} . ')' : '')
			. ": " . $PacketData->{'message'} . "\n";
		return;
	}

	print "APRS-IS message gateway: APRS-IS>MtotoTrbo "
		. $PacketData->{'srccallsign'} . '>' . $PacketData->{'destination'} . " " . $radio->{'id'}
		. ": " . $PacketData->{'message'} . "\n";
	
	$Net->{'tms'}->queue_msg($radio->{'id'}, 'APRS ' . $PacketData->{'srccallsign'} . ': ' . $PacketData->{'message'});
}

sub APRS_IS_Make_Ack($$$) {
	my($src, $dst, $id) = @_;
	return sprintf("%s>APRS::%-9s:ack%s", $src, $dst, $id);
}






sub APRS_IS_Push_Updates() {
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
			#1, # compression
			#0 # no ambiguity
		);
		print "$APRS_Position\n";

		if ($ent->{'comment'} eq '') {
			$ent->{'comment'} = ' ';
		};

		my $Packet = sprintf('%s>APTR01:!%s', $ent->{'callsign'}, $APRS_Position . $ent->{'comment'});
		print "  $Packet\n";
		my $Res = $APRS_IS->sendline($Packet);
		if (!$Res) {
			print color('red'), "Error sending APRS-IS Pos packet $Res\n", color('reset');
			$APRS_IS->disconnect();
			return;
		}
		print "  Push Updates Done.\n";
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
			$ent->{'comment'}); # comment
		print "$APRS_Object\n";

		my $Packet = sprintf('%s>APTR01:!%s', $ent->{'callsign'}, $APRS_Object);
		print color('cyan'), "  $Packet\n", color('reset');

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
	print "  Beaconing position of " . $reg->{'id'} . ": " . $reg->{'callsign'} . "\n";
	return 1;
}



##############################################################################################
# APRS
##############################################################################################
sub APRS_Symbol($$) {
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



##############################################################################################
# State data
##############################################################################################
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
		print color('yellow'),  "  Could could not rename $TempFile to " . $State_Dump_File . ": $!\n", color('reset');
		return;
	}
	print "  Dump State Done.\n";
}

sub Reload_State() {
	print color('green'), "Reload State Called.\n", color('reset');
	if (!defined $State_Dump_File) {
		print color('red'), "State_Dump_File $State_Dump_File not defined.", color('reset');	
		return;
	}

	if (!open(F, $State_Dump_File)) {
		print color('yellow'),  "  Could could not open state dump " . $State_Dump_File . " for reading: $!\n", color('reset');
		return;
	}

	my $l = <F>;
	print color('grey12'), "  l " . Dumper($l), color('reset');
	my $state = from_json($l);
	#print "  state " . Dumper($state);

	close(F);

	return if (!defined $state->{'registry'});

	my $reg = $Net->{'registry'};
	foreach my $radio (values %{ $state->{'registry'} }) {
		if (!defined $reg->{$radio->{'id'}}) {
			print "  Reload_State: radio " . $radio->{'id'} . " not configured, ignoring\n";
			next;
		}
		print "  Reload_State: reloading radio " . $radio->{'id'} . "\n";
		for my $k ('last_poll_tx', 'last_poll_rx', 'first_heard', 'last_heard', 'away_reason', 'state', 'heard_what') {
			$reg->{$radio->{'id'}}{$k} = $radio->{$k};
		}
	}

	$Net->registry_scan(1);
	print "  Reload State Done.\n";
}



###############################################################################
# Commands
###############################################################################
sub Cmd_APRS($$) {
	my($rx, $args) = @_;
	
	print color('green'), "Cmd_APRS\n", color('reset');

	return if (!$APRS_IS);
	my($cmd, $dst, @words) = @$args;
	my $msg = join(' ', @words);
	if (!defined $dst || $dst eq '' || $msg eq '') {
		$Net->{'tms'}->queue_msg($rx->{'src_id'}, 'Usage: Aprs <callsign> <message>');
		return;
	}

	$dst = uc($dst);

	my $aprsmsg = sprintf("%s>APRS::%-9s:%s", $rx->{'registry'}->{'callsign'}, uc($dst), $msg);
	#print "$aprsmsg\n";
	print "APRS-IS message gateway: TRBO>IS "
		. $rx->{'registry'}->{'callsign'} . '>' . $dst
		. ": $msg\n";
	my $ok = $APRS_IS->sendline($aprsmsg);
	if (!$ok) {
		print color('red'), "Error sending APRS message from " . $rx->{'registry'}->{'callsign'} . "to $dst \n", color('reset');
		$APRS_IS->disconnect();
	}
}

sub Cmd_APRS_Obj($$) {
	my($rx, $args) = @_;

	print color('green'), "Cmd_APRS_Obj\n", color('reset');

	return if (!$APRS_IS);
	my($cmd, $name, $status,  @words) = @$args;
	my $comment = join(' ', @words);
	my $now = time();
	my $symbol = APRS_Symbol($name => $name);

	push @upd_q,{
	'name' => $name,
	'timestamp' => 0,# timestamp (current == 0)
	'latitude' => $rx->{'registry'}->{'last_lat'},
	'longitude' => $rx->{'registry'}->{'last_lng'},
	'symbol'   => $symbol,
	'speed' => -1,
	'course' => -1,
	'altitude' => -10000,
	'status' => $status,
	'comment' => $comment,
	'callsign' => $rx->{'registry'}->{'callsign'}
	};
	APRS_IS_Push_Object();
}

###############################################################################
sub Cmd_Ctrl($$) {
	my($rx, $args) = @_;

	my($cmd, $dst, @words) = @$args;
	my $msg = join(' ', @words);
	print color('green'), "Cmd_Ctrl: "
		. $rx->{'registry'}->{'callsign'} . ' ' . $rx->{'src_id'} . ' > ' . $dst
		. ": $msg\n", color('reset');

	return if (!$APRS_IS);
	# APRS enable/disable control:
	if (lc($dst) eq 'aprs') {
#		$aprs_enable = $msg;
#		$Net->{'tms'}->queue_msg($Admin_Radio_ID, "APRS Enable set to = " . $aprs_enable);
	}
	# Analog Aux1 port using GPIO 21 (pins 40):
#	if (lc($dst) eq 'aux1') {
#		if ($msg == 1 ){
#			Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_21, 1);
#	} else {
#			Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_21, 0);
#		};
#	};
	# Analog Aux2 port using GPIO 26 (pins 37):
#	if (lc($dst) eq 'aux2') {
#		if ($msg == 1 ){
#			Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_21, 1);
#		} else {
#			Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_21, 0);
#		};
#	};
	# Kill app:
	if (lc($dst) eq 'kill') {
		$Net->{'tms'}->queue_msg($Admin_Radio_ID, "Radio " . $rx->{'src_id'} . ' killed ARSED.');
		die("Warning: radio " . $rx->{'src_id'} . " killed ARSED.");
	}
}

##############################################################################################
sub Cmd_email($$) {
	my($rx, $args) = @_;

	my($cmd, $dst, @words) = @$args;
	my $msg = join(' ', @words);
	print color('green'), "Cmd_email\n", color('reset');

	return if (!$APRS_IS);

	print "e-mail message gateway: "
		. $rx->{'registry'}->{'callsign'} . ' To: ' . $dst
		. " Body: $msg\n";

	my $subject= 'DMR e-mail from: ' . $rx->{'registry'}->{'name'} . ' ' .  $rx->{'registry'}->{'short_callsign'};
	my $body= $msg . "\n" . $rx->{'registry'}->{'name'} . "\n" . $rx->{'registry'}->{'short_callsign'};

#	my $mail=Email::Send::SMTP::Gmail->new( -smtp=>'smtp.gmail.com',
#	-login=>$rx->{'registry'}->{'email_username'},
#		-pass=>$rx->{'registry'}->{'email_password'},
#	-layer=>'ssl',
#	-port=>465,
##	-verbose=>1,
##	-debug=>1
#	);
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

	print "email Sent by: $rx->{'registry'}->{'name'} $rx->{'registry'}->{'short_callsign'}.\n";
}

##############################################################################################
sub Cmd_ping($$) {
	my($rx) = @_;

	print color('green'), "Cmd_ping\n", color('reset');
	my $datestring = gmtime();
	$Net->{'tms'}->queue_msg($rx->{'src_id'}, 'Echo to radio: ' . $rx->{'src_id'} . ' GMT ' . $datestring);
}

##############################################################################################
sub Cmd_SMS($$) {
	my($rx, $args) = @_;

	my($cmd, $dst, @words) = @$args;
	my $msg = join(' ', @words);
	print color('green'), "Cmd_SMS\n", color('reset');

	return if (!$APRS_IS);

	print "Bulk SMS message gateway: "
	. $rx->{'registry'}->{'callsign'} . ' > ' . $dst
	. " > $msg\n";


	# This block is from Bulk SMS code samples, Perl version.
	my $ua = LWP::UserAgent->new(timeout => 30);

	# Please see the FAQ regarding HTTPS (port 443) and HTTP (port 80/5567)
	# If your firewall blocks acces to port 5567, you can fall back to port 80:
	# my $req = HTTP::Request->new(POST =>'http://bulksms.vsms.net/eapi/submission/send_sms/2/2.0');
	# (See FAQ for more details.)
	#my $req = HTTP::Request->new(POST =>'http://bulksms.vsms.net:5567/eapi/submission/send_sms/2/2.0');
#	my $req = HTTP::Request->new(POST =>'http://bulksms.vsms.net/eapi/submission/send_sms/2/2.0');
#	$req->content_type('application/x-www-form-urlencoded');

#	$req->content('username=' . $rx->{'registry'}->{'sms_username'} . '&password=' . $rx->{'registry'}->{'sms_password'} . '&msisdn=' . $dst . 
#	'&sender=' . $rx->{'registry'}->{'sms_sender_id'} . '&repliable=0' . '&message= ' . $msg .
#	' From: ' . $rx->{'registry'}->{'short_callsign'} . ' ' . $rx->{'registry'}->{'sms_reply_phone'}
#	);

#	print 'username=' . $rx->{'registry'}->{'sms_username'} . '&password=' . $rx->{'registry'}->{'sms_password'} . '&msisdn=' . $dst .
#	'&sender=' . $rx->{'registry'}->{'sms_sender_id'} . '&repliable=0' . '&message=' . $msg .
#		' From: ' . $rx->{'registry'}->{'short_callsign'} . ' ' . $rx->{'registry'}->{'sms_reply_phone'} . "\n";

#	my $res = $ua->request($req);

#	if ($res->is_error) {
		#die "HTTP request error, with error code " . $res->code .
	#	", and body:\n\n" . $res->error_as_HTML;
#	}

#	my ($result_code, $result_string, $batch_id) = split(/\|/, $res->content);

#	if ($result_code eq '0') {
#		print "Message sent: batch $batch_id\n";
#		$Net->{'tms'}->queue_msg($rx->{'src_id'}, 'SMS Sent.');
#		$APRS_IS->disconnect();# This line comes from original arsed.
#	}
#	else {
#		print "Error sending: $result_code: $result_string\n";
#		$Net->{'tms'}->queue_msg($rx->{'src_id'}, "SMS Error sending: $result_code: $result_string.");
#	}
#	print "\n";
	#Bulk SMS block end.
}

##############################################################################################
# Weather Underground
##############################################################################################
sub Cmd_WEA($$) {
	my($rx, $args) = @_;
	
	my($cmd, @words) = @$args;
	my $msg = join(' ', @words);
	print color('green'), "Cmd_WEA\n", color('reset');

	return if (!$APRS_IS);

	# Wunderground:
	my $key;
	my $value;
	my $weather = Weather::Underground->new(
		place => $msg,
			debug => 0,
		)
		|| warn color('red'), "Error, could not create new weather object: $@\n", color('reset');

	my $arrayref = $weather->get_weather()
		|| warn color('red'), "Error, calling get_weather() failed: $@\n", color('reset');

	my ($place, $temp_c, $humidity, $conditions, $wind_dir, $wind_kmph, $pressure, $updated, $clouds, $dew_point_c, $visibility_km);
	
	foreach (@$arrayref) {
		print "MATCH:\n";
		while (($key, $value) = each %{$_}) {
			print "\t$key = $value\n";
			if ($key eq 'place'  ){
				$place =  $value;
			};
			if ($key eq 'temperature_celsius'  ){
				$temp_c = $value;
			};
			if ($key eq 'humidity'  ){
				$humidity = $value;
			};
			if ($key eq 'conditions'  ){
				$conditions = $value;
			};
			if ($key eq 'wind_direction'  ){
				$wind_dir = $value;
			};
			if ($key eq 'wind_kilometersperhour'  ){
				$wind_kmph = $value;
			};
			if ($key eq 'pressure'  ){
				$pressure = $value;
			};
			if ($key eq 'updated'  ){
				$updated = $value;
			};
			if ($key eq 'clouds'  ){
				$clouds = $value;
			};
			if ($key eq 'dewpoint_celcius'  ){
				$dew_point_c = $value;
			};
			if ($key eq 'visibility_kilometers'  ){
				$visibility_km = $value;
			};
		}
	}
	$msg = "$place at $updated Temp: $temp_c, wind: $wind_kmph kmph $wind_dir, Humidity: $humidity, Press: $pressure";
	print "Message: " . $msg . "\n";

	print "Weather report to radio: "
		. $rx->{'registry'}->{'callsign'} . '>'
		. ": $msg\n";
	$Net->{'tms'}->queue_msg($rx->{'src_id'}, 'WEA: ' . $msg);
}

##############################################################################################
sub Cmd_Who($$) {
	my($rx, $args) = @_;

	my($cmd, $dst) = @$args;
	print color('green'), "Cmd_Who from $rx->{'src_id'} ask about $rx->{'src_id'}\n", color('reset');

	my $now = time();
	if (defined $dst) {
		my @matches;
		my $match;
		foreach my $radio (values %{ $Net->{'registry'} }) {
			my $s = (defined $radio->{'callsign'}) ? $radio->{'callsign'} : $radio->{'id'};
			if (index($radio->{'id'}, $dst) >= 0) {
				$match = $radio;
				push @matches, $s;
				next;
			}
			if (defined $radio->{'callsign'} && index(uc($radio->{'callsign'}), uc($dst)) >= 0) {
				$match = $radio;
				push @matches, $s;
				next;
			}
		}
		if (!@matches) {
			$Net->{'tms'}->queue_msg($rx->{'src_id'}, 'No match for ' . $dst);
			return;
		}
		if ($#matches > 0) {
			$Net->{'tms'}->queue_msg($rx->{'src_id'}, 'Multiple matches: ' . join(' ', @matches));
			return;
		}
		
		my $s = '' . join(' ', @matches);
		if (defined $match->{'last_heard'}) {
			$s .= ' Heard ' . dur_str($now - $match->{'last_heard'});
		}
		if ($match->{'last_loc'} && ($match->{'last_lat'}) && ($match->{'last_lng'})) {
			$s .= ' Loc ' . dur_str($now - $match->{'last_loc'});
			my($addr) = reverse_geocode($match->{'last_lat'}, $match->{'last_lng'});
			$s .= ': ' . $addr if (defined $addr);
			$s .= ' Lat ' . $match->{'last_lat'};
			$s .= ' Lng ' . $match->{'last_lng'};
		}

		$Net->{'tms'}->queue_msg($rx->{'src_id'}, $s);
		return;
	}

	my @Here;
	foreach my $radio (sort { $b->{'last_heard'} <=> $a->{'last_heard'} } values %{ $Net->{'registry'} }) {
		#print Dumper($radio);
		if ($radio->{'state'} eq 'here') {
			print "Who User Data: " . Dumper($radio);
			my $s = (defined $radio->{'callsign'}) ? $radio->{'callsign'} : $radio->{'id'};
			if ($now - $radio->{'last_heard'} > $ARS_Timeout/2) {
				$s = lc($s);
			}
			if (defined $radio->{'last_loc'} && $now - $radio->{'last_loc'} < 15*60 && ($radio->{'last_lat'})) {
				$s .= '*'; 
			}
			push @Here, $s;
		}
	}
	$Net->{'tms'}->queue_msg($rx->{'src_id'}, 'Available: ' . join(' ', @Here));
}

##############################################################################################
# Cmd_Help
##############################################################################################
sub Cmd_Help($) {
	my($rx) = @_;

	# Reply with a TMS listing the commands available.
	print color('green'), "Cmd_Help to RadioID $rx->{'src_id'}\n", color('reset');
	$Net->{'tms'}->queue_msg($rx->{'src_id'}, 'Commands: A or APRS, Ctrl, e or email, h or Help, Ping, SMS, WEA, W or Who');
}



##############################################################################################
# 
##############################################################################################
sub Process_Rx_Msg($) {
	my($rx) = @_;

	if ($rx->{'text'} =~ /^\s*([a-z]+)\s*/i) {
		my($cmd) = lc($1);

		print color('green'), "Process_Rx_Msg '$cmd' from $rx->{'src_id'}\n", color('reset');

		my $t = $rx->{'text'};
		$t =~ s/^\s+//;
		$t =~ s/\s+$//;
		$t =~ s/\s+/ /g;
		my @args = split(' ', $t);

		if (defined $cmds{$cmd}) {
			$cmds{$cmd}($rx, \@args);
			return;
		}
	} else {
		print color('yellow'), "Process_Rx_Msg Cmd not found.\n", color('reset');
	}

	Cmd_Help($rx);
}



##############################################################################################
# 
##############################################################################################
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



##############################################################################################
# 
##############################################################################################
sub Consider_LOC_Requests()
{
	my $reg = $Net->{'registry'};

	foreach my $id (keys %{ $reg }) {
		if (defined $reg->{$id}->{'consider_loc_req'} && $reg->{$id}->{'consider_loc_req'} < time()) {
			my $radio = $reg->{$id};
			delete $radio->{'consider_loc_req'};
			next if ($radio->{'state'} ne 'here');
			# loc request configured, check if we have received locs recently
			if (!defined $radio->{'last_loc'} || $radio->{'last_loc'} < time() - 7200) {
				$Net->{'loc'}->request_locs($id, $GPS_Req_Interval - 10 + int(rand(30)));
			}
		}
	}
}



##############################################################################################
# Hot Keys
##############################################################################################
sub HotKeys {
	# Hot Keys.
	if ($HotKeys) {
		if (not defined (my $key = ReadKey(-1))) {
			# No key yet.
		} else {
			switch (ord($key)) {
				case 0x1B { # Escape
					print "EscKey Pressed.\n";
					$Run = 0;
				}
				case ord('A') { # 'A'
#					APRS_Update();
#					$APRS_NextTimer = time() + $APRS_Interval;
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

				case ord('m') { # 'm'
					# Send a TMS.
					print color('green'), "Test Message to RadioID 3341100.\n", color('reset');
					$Net->{'tms'}->queue_msg(3341100, 'Test.');
				}

				case ord('Q') { # 'Q'
					$Run = 0;
				}
				case ord('q') { # 'q'
					$Run = 0;
				}
				case ord('S') { # 'S'
					
				}
				case ord('s') { # 's'
					
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
			if ($APRS_Verbose >= 1) {print color('grey12'), "APRS-IS Raw Rx raw: $APRS_IS_Raw_Rx\n", color('reset');}
			next if ($APRS_IS_Raw_Rx =~ /^#/);
			APRS_IS_Process_Rx_Net_Data($APRS_IS_Raw_Rx);
		}

		# Send Gateway APRS position.
		if (time() >= $APRS_NextTimer) {
			if (defined $My_Latitude && defined $My_Longitude && abs($My_Latitude) > 0.1 && abs($My_Longitude) > 0.1) {
				print "  APRS-IS: beaconing gateway position\n";
				# Push my Gateway LOC
				push @upd_q, {
					'name' => $APRS_Callsign,
					'latitude' => $My_Latitude,
					'longitude' => $My_Longitude,
					'altitude' => $My_Altitude,
					'speed' => -1,
					'course' => -1,
					'symbol' => $My_Symbol,
					'callsign' => $APRS_Callsign,
					'comment' => $My_Comment
				};
#				APRS_IS_Push_Updates();
			}
			$APRS_NextTimer = time() + $APRS_Interval;
		}
	}

	# Scan for messages which should be sent
	if (defined $config->{'tms_incoming_spool'}) {
		scan_spool($config->{'tms_incoming_spool'});
	}

	my $rx = $Net->receive();

	if (!$rx) {
		#print "No rx.\n";
		$Net->registry_scan();
		$Net->{'tms'}->queue_run();
		$aprs_msg_cache->scan(300);
		Consider_LOC_Requests();
		Dump_State();
		#next;
	}
	print "  rx Dump " . Dumper($rx);

	if (!defined $rx->{'class'}) {
		# ouch!

	} elsif ($rx->{'class'} eq 'ars') {
		if ($rx->{'msg'} eq 'hello') {
			# Could have some policy here on what to accept...
			
			# Register radio internally and start polling it
		$Net->register_radio($rx);
		# After 10 minutes, check if we're getting LOC packets, and if not,
			# ask for them
			if ($GPS_Req_Interval) {
				$rx->{'registry'}->{'consider_loc_req'} = time() + 600;
			}
		}

	} elsif ($rx->{'class'} eq 'loc') {
		if ($rx->{'msg'} eq 'loc' && defined $rx->{'latitude'}) {
			if (!($GPS_Req_Interval)) {
				# Got LOC but not requested - disable
				$Net->{'loc'}->request_no_locs($rx->{'src_id'});
			} elsif (defined $rx->{'registry'} && defined $rx->{'registry'}->{'callsign'} && APRS_IS_Consider_Beacon($rx)) {
				if ($Mode != 1){
					push @upd_q,{
						'name' => $rx->{'registry'}->{'callsign'},
						'latitude' => $rx->{'latitude'},
						'longitude' => $rx->{'longitude'},
						'altitude' => $rx->{'altitude'},
						'speed' => $rx->{'speed'},
						'course' => -1,
						'symbol'   => $rx->{'registry'}->{'symbol'},
						'callsign' => $rx->{'registry'}->{'callsign'},
						'comment' => $rx->{'registry'}->{'comment'}
					};
					print "Mode 1.\n";
				} else {
					push @upd_q,{
						'name' => $rx->{'registry'}->{'callsign'},
						'latitude' => 19.380834,# Test Location.
						'longitude' => -99.176753,# Test Location.
						'altitude' => 2000, # Test Location.
						'speed' => -1,
						'course' => -1,
						'symbol'   => $rx->{'registry'}->{'symbol'},
						'callsign' => $rx->{'registry'}->{'callsign'},
						'comment' => $rx->{'registry'}->{'comment'}
					};
					print "Mode else.\n";
					print $rx->{'registry'}->{'short_callsign'} . "\n";
				}
				APRS_IS_Push_Updates();
			}
		}
		$rx->{'registry'}->{'last_loc'} = time();

	} elsif ($rx->{'class'} eq 'tms') {
		if ($rx->{'msg'} eq 'msg') {
			Process_Rx_Msg($rx);
		}
	}
	if ($Verbose >= 5) { print "Looping the right way.\n"; }
}

