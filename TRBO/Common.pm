package TRBO::Common;

=head1 NAME

TRBO::Common - Common utilities used by other modules

=head1 ABSTRACT

TRBO::NET - A trbo parser

=head1 FUNCTIONS

=cut

our $VERSION = "1.3";

# no debugging by default
my $debug = 0;

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor;

use Socket;



sub Bytes_2_HexString($) {
	my ($Buffer) = @_;
	# Display Hex String.
	for (my $x = 0; $x < length($Buffer); $x++) {
		print sprintf(" %x", ord(substr($Buffer, $x, 1)));
	}
	print "\n";
}

sub _hex_dump($) {
	my($s) = @_;

	#print color('cyan'), "TRBO::Common::_hex_dump\n", color('reset');
	my $out = '';
	my $l = length($s);
	my $bytes_in_a_chunk = 4;
	my $bytes_in_a_row = $bytes_in_a_chunk * 8;

	# this is bit slow, but only used for debugging
	for (my $i = 0; $i < $l; $i += 1) {
		if ($i % $bytes_in_a_row == 0 && $i != 0) {
			$out .= "\n";
		} elsif ($i % $bytes_in_a_chunk == 0 && $i != 0) {
			$out .= ' ';
		}
		$out .= sprintf('%02x', ord(substr($s, $i, 1)));
	}
	return $out;
}

sub new {
	if ($debug) {print color('cyan'), "TRBO::Common::new\n", color('reset');}
	my $class = shift;
	my $self = bless { @_ }, $class;

	$self->{'initialized'} = 0;
	$self->{'version'} = $VERSION;

	# store config
	my %h = @_;
	$self->{'config'} = \%h;
	#if ($debug) {print "settings:\n" . Dumper(\%h);}

	$self->{'pkts_tx'} = 0;
	$self->{'pkts_rx'} = 0;
	$self->{'bytes_tx'} = 0;
	$self->{'bytes_rx'} = 0;

	$self->{'sock'} = $self->{'config'}->{'sock'};

	$self->{'debug'} = ( $self->{'config'}->{'debug'} );
	$self->{'log_prefix'} = $self;
	$self->{'log_prefix'} =~ s/=.*//;

	$self->_debug('initialized');

	$self->_clear_errors();
	return $self;
}



# clear error flags

sub _clear_errors($) {
	my($self) = @_;

	print color('yellow'), "TRBO::Common::_clear_errors\n", color('reset');
	$self->{'last_err_code'} = 'ok';
	$self->{'last_err_msg'} = 'no error reported';
}

#
#	Logg tools
#

sub log_time {
	my($t) = @_;

	#if ($debug) {print color('cyan'), "TRBO::Common::log_time\n", color('reset');}
	$t = time() if (!defined $t);

	my(@tf) = gmtime($t);
	return sprintf("%04d-%02d-%02d %02d:%02d:%02d",
	$tf[5]+1900, $tf[4]+1, $tf[3], $tf[2], $tf[1], $tf[0]);
}

sub _log($$) {
	my($self, $msg) = @_;

	#print color('cyan'), "TRBO::Common::_log\n", color('reset');
	print "  " . log_time() . ' ' . $self->{'log_prefix'} . " $msg\n";
}

sub _debug($$) {
	my($self, $msg) = @_;

	#print color('cyan'), "TRBO::Common::_debug\n", color('reset');
	return if (!$self->{'debug'});

	$self->_log("DEB: $msg");
}

sub _info($$) {
	my($self, $msg) = @_;

	#print color('cyan'), "TRBO::Common::_info\n", color('reset');
	$self->_log("FYI: $msg");
}

sub _fail($$$) {
	my($self, $rh, $code) = @_;

	print color('bright_yellow'), "TRBO::Common::_fail\n", color('reset');
	$rh->{'err_code'} = $code;
	print color('yellow');
	$self->_log("WTF: $code");
	print color('reset');
	return 0;
}

sub _crash($$$) {
	my($self, $rh, $code) = @_;

	print color('red'), "TRBO::Common::_crash\n", color('reset');
	$rh->{'err_code'} = $code;

	$self->_log("OMG: $code");

	exit(1);
}

=over

=item set_debug($enable)

Enable or disable debug printout in module. Debug output goes to standard error.

=back

=cut

sub set_debug($$) {
	my($self, $status) = @_;

	print color('cyan'), "TRBO::Common::set_debug\n", color('reset');
	$self->{'debug'} = ($status);
}

=over

=item _decode_ber($data, $index)

Decode var-length int from data. Appear to be encoded
like in BER/ASN.1/SNMP:

"base-128 in big-endian order where the 8th bit is 1 if more bytes follow and 0 for the last byte"
(wikipedia)

Start decode from given position. Return list of decoded int value
and index *after* last decode byte (where decode of following
data continues).

=back

=cut

sub _decode_ber_int($$$) {
	my($self, $data, $i) = @_;

	if ($debug) {print color('cyan'), "TRBO::Common::_decoder_ber_int\n", color('reset');}
	my $i_start = $i;
	my $n = unpack('C', substr($data, $i, 1));
	my $sign = $n & 0x40;
	my $no = $n & 0x3f;

	while ($n & 0x80) {
		$i++;
		$n = unpack('C', substr($data, $i, 1));
		$no = $no * 128 + ($n & 0x7f);
	}

	my $c = $i - $i_start + 1;
	#$self->_debug("_decode_ber_int of $c bytes ($i_start...$i): $no - 0x" . _hex_dump(substr($data, $i_start, $c)));
	$i++;

	# TODO: which way the sign is?

	return ($no, $i);
}

sub _decode_ber_uint($$$){
	my($self, $data, $i) = @_;

	#if ($debug) {print color('cyan'), "TRBO::Common::_decoder_ber_uint\n", color('reset');}
	my $i_start = $i;
	my $n = unpack('C', substr($data, $i, 1));
	my $no = $n & 0x7f;

	while ($n & 0x80) {
		$i++;
		$n = unpack('C', substr($data, $i, 1));
		$no = $no * 128 + ($n & 0x7f);
	}

	my $c = $i - $i_start + 1;
	#$self->_debug("_decode_ber_uint of $c bytes ($i_start...$i): $no - 0x" . _hex_dump(substr($data, $i_start, $c)));
	$i++;

	return ($no, $i);
}

sub _encode_ber_uint($$) {
	my($self, $int) = @_;

	if ($debug) {print color('cyan'), "TRBO::Common::_encoder_ber_uint\n", color('reset');}
	my $out = '';

	#$self->_debug("_encode_ber_uint $int");

	my $firstbit = 0;
	while ($int) {
		$out = pack('C', ($int & 0x7f) | $firstbit ) . $out;
		$int = $int >> 7;
		$firstbit = 0x80;
	}
	$out = pack('C', 0) if ($out eq '');

	#$self->_debug("result: " . _hex_dump($out));

	return $out;
}

=over

=item _make_addr($id)

With configured CAI network number and radio ID number, generate
IP address of radio. Retur packed sockaddr_in format
which can pass to sendmsg() direct.

=back

=cut

sub _make_addr($$;$) {
	my($self, $id, $group_net) = @_;

	if ($debug) {print color('cyan'), "TRBO::Common::_make_addr\n", color('reset');}

	#print "id = $id\n";
	#print "self->{'config'}->{'cai_net'} = $self->{'config'}->{'cai_net'}\n";
	#print "group_net = $group_net\n";
	#print "\n" . Dumper($self);

	#my $host = (defined $group_net && ($group_net)) ? $self->{'config'}->{'cai_group_net'} : $self->{'config'}->{'cai_net'};
	my $host;
	if (defined $group_net && ($group_net)) {
		#print "Group id $group_net\n";
		$host = $group_net;
	} else {
		#print "Private id $id\n";
		$host = $self->{'config'}->{'cai_net'};
	}
	$host .= '.' . (($id >> 16) & 0xff) .'.' . (($id >> 8) & 0xff) . '.' . ($id & 0xff);
	my $hisiaddr = inet_aton($host);
	$self->_debug("_make_addr id = $id, host = $host " . $self->{'config'}->{'port'});
	my $sin = sockaddr_in($self->{'config'}->{'port'}, $hisiaddr);
	return $sin;
}

=over

=item send($id, $data)

Send binary message UDP to radio ID.

=back

=cut

sub _send($$$;$$) {
	my($self, $id, $data, $prefix, $group_net) = @_;

	print color('magenta'), "TRBO::Common::_send\n", color('reset');
	#print "self = $self\n";
	print "id = $id\n";
	#print "data = $data\n";
	if (defined $prefix) {
		print "prefix = $prefix\n";
	}
	if (defined $group_net) {
		print "group_net = $group_net\n";
	}

	my $out = $self->_pack($data, $prefix);

	print color('magenta');
	print "out $out\n";
	$self->_debug("_send to $id:" . $self->{'config'}->{'port'} . "\n");
	print color('reset');
	#Bytes_2_HexString($out);
	#print "length(out) = " . length($out) . "\n";

	$self->{'sock'}->send($out, 0, $self->_make_addr($id, $group_net));
	$self->{'pkts_tx'} += 1;
	$self->{'bytes_tx'} += length($out);
}

sub _rx_accounting($$) {
	my($self, $msg) = @_;

	#if ($debug) {print color('cyan'), "TRBO::Common::_rx_accounting\n", color('reset');}
	$self->{'pkts_rx'} += 1;
	$self->{'bytes_rx'} += length($msg);
}

sub _pack($$;$) {
	my($self, $data, $prefix) = @_;

	#if ($debug) {print color('cyan'), "TRBO::Common::pack\n", color('reset');}
	my $out = pack('n', length($data)) . $data;
	if (defined $prefix) {
		$out = $prefix . $out;
	}
	return $out;
}

sub debug($) {
	my $dval = shift @_;
	if ($dval) {
		$debug = 1;
	} else {
		$debug = 0;
	}
}


1;
