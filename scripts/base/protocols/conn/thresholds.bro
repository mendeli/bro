##! Implements a generic way to throw events when a connection crosses a
##! fixed threshold of bytes or packets

module ConnThreshold;

export {

	type Thresholds: record {
		orig_byte_thresholds: set[count] &default=count_set(); ##< current originator byte thresholds we watch for
		resp_byte_thresholds: set[count] &default=count_set(); ##< current responder byte thresholds we watch for
		orig_packet_thresholds: set[count] &default=count_set(); ##< corrent originator packet thresholds we watch for
		resp_packet_thresholds: set[count] &default=count_set(); ##< corrent responder packet thresholds we watch for
	};

	## Sets a byte threshold for connection sizes, adding it to potentially already existing thresholds.
	## conn_bytes_threshold_crossed will be raised for each set threshold.
	##
	## cid: The connection id.
	##
	## threshold: Threshold in bytes.
	##
	## is_orig: If true, threshold is set for bytes from originator, otherwhise for bytes from responder.
	##
	## Returns: T on success, F on failure.
	##
	## .. bro:see:: bytes_threshold_crossed packets_threshold_crossed set_packets_threshold
	##              delete_bytes_threshold delete_packets_threshold
	global set_bytes_threshold: function(c: connection, threshold: count, is_orig: bool): bool;

	## Sets a packet threshold for connection sizes, adding it to potentially already existing thresholds.
	## conn_packets_threshold_crossed will be raised for each set threshold.
	##
	## cid: The connection id.
	##
	## threshold: Threshold in packets.
	##
	## is_orig: If true, threshold is set for packets from originator, otherwhise for packets from responder.
	##
	## Returns: T on success, F on failure.
	##
	## .. bro:see:: bytes_threshold_crossed packets_threshold_crossed set_bytes_threshold
	##              delete_bytes_threshold delete_packets_threshold
	global set_packets_threshold: function(c: connection, threshold: count, is_orig: bool): bool;

	## Deletes a byte threshold for connection sizes.
	##
	## cid: The connection id.
	##
	## threshold: Threshold in bytes to remove.
	##
	## is_orig: If true, threshold is removed for packets from originator, otherwhise for packets from responder.
	##
	## Returns: T on success, F on failure.
	##
	## .. bro:see:: bytes_threshold_crossed packets_threshold_crossed set_bytes_threshold set_packets_threshold
	##              delete_packets_threshold
	global delete_bytes_threshold: function(c: connection, threshold: count, is_orig: bool): bool;

	## Deletes a packet threshold for connection sizes.
	##
	## cid: The connection id.
	##
	## threshold: Threshold in packets.
	##
	## is_orig: If true, threshold is removed for packets from originator, otherwhise for packets from responder.
	##
	## Returns: T on success, F on failure.
	##
	## .. bro:see:: bytes_threshold_crossed packets_threshold_crossed set_bytes_threshold set_packets_threshold
	##              delete_bytes_threshold
	global delete_packets_threshold: function(c: connection, threshold: count, is_orig: bool): bool;

	## Generated for a connection that crossed a set byte threshold
	##
	## c: the connection
	##
	## threshold: the threshold that was set
	##
	## is_orig: True if the threshold was crossed by the originator of the connection
	##
	## .. bro:see:: packets_threshold_crossed set_bytes_threshold set_packets_threshold
	##              delete_bytes_threshold delete_packets_threshold
	global bytes_threshold_crossed: event(c: connection, threshold: count, is_orig: bool);

	## Generated for a connection that crossed a set byte threshold
	##
	## c: the connection
	##
	## threshold: the threshold that was set
	##
	## is_orig: True if the threshold was crossed by the originator of the connection
	##
	## .. bro:see:: bytes_threshold_crossed  set_bytes_threshold set_packets_threshold
	##              delete_bytes_threshold delete_packets_threshold
	global packets_threshold_crossed: event(c: connection, threshold: count, is_orig: bool);
}

redef record connection += {
	thresholds: ConnThreshold::Thresholds &optional;
};

function set_conn_thresholds(c: connection)
	{
	if ( c?$thresholds )
		return;

	c$thresholds = Thresholds();
	}

function find_min_threshold(t: set[count]): count
	{
	if ( |t| == 0 )
		return 0;

	local first = T;
	local min: count = 0;

	for ( i in t )
		{
		if ( first )
			{
			min = i;
			first = F;
			}
		else
			{
			if ( i < min )
				min = i;
			}
		}

	return min;
	}

function set_current_threshold(c: connection, bytes: bool, is_orig: bool): bool
	{
	local t: count = 0;
	local cur: count = 0;

	if ( bytes && is_orig )
		{
		t = find_min_threshold(c$thresholds$orig_byte_thresholds);
		cur = get_current_conn_bytes_threshold(c$id, is_orig);
		}
	else if ( bytes && ! is_orig )
		{
		t = find_min_threshold(c$thresholds$resp_byte_thresholds);
		cur = get_current_conn_bytes_threshold(c$id, is_orig);
		}
	else if ( ! bytes && is_orig )
		{
		t = find_min_threshold(c$thresholds$orig_packet_thresholds);
		cur = get_current_conn_packets_threshold(c$id, is_orig);
		}
	else if ( ! bytes && ! is_orig )
		{
		t = find_min_threshold(c$thresholds$resp_packet_thresholds);
		cur = get_current_conn_packets_threshold(c$id, is_orig);
		}

	if ( t == cur )
		return T;

	if ( bytes && is_orig )
		return set_current_conn_bytes_threshold(c$id, t, T);
	else if ( bytes && ! is_orig )
		return set_current_conn_bytes_threshold(c$id, t, F);
	else if ( ! bytes && is_orig )
		return set_current_conn_packets_threshold(c$id, t, T);
	else if ( ! bytes && ! is_orig )
		return set_current_conn_packets_threshold(c$id, t, F);
	}

function set_bytes_threshold(c: connection, threshold: count, is_orig: bool): bool
	{
	set_conn_thresholds(c);

	if ( threshold == 0 )
		return F;

	if ( is_orig )
		add c$thresholds$orig_byte_thresholds[threshold];
	else
		add c$thresholds$resp_byte_thresholds[threshold];

	return set_current_threshold(c, T, is_orig);
	}

function set_packets_threshold(c: connection, threshold: count, is_orig: bool): bool
	{
	set_conn_thresholds(c);

	if ( threshold == 0 )
		return F;

	if ( is_orig )
		add c$thresholds$orig_packet_thresholds[threshold];
	else
		add c$thresholds$resp_packet_thresholds[threshold];

	return set_current_threshold(c, F, is_orig);
	}

function delete_bytes_threshold(c: connection, threshold: count, is_orig: bool): bool
	{
	set_conn_thresholds(c);

	if ( is_orig && threshold in c$thresholds$orig_byte_thresholds )
		{
		delete c$thresholds$orig_byte_thresholds[threshold];
		set_current_threshold(c, T, is_orig);
		return T;
		}
	else if ( ! is_orig && threshold in c$thresholds$resp_byte_thresholds )
		{
		delete c$thresholds$resp_byte_thresholds[threshold];
		set_current_threshold(c, T, is_orig);
		return T;
		}

	return F;
	}

function delete_packets_threshold(c: connection, threshold: count, is_orig: bool): bool
	{
	set_conn_thresholds(c);

	if ( is_orig && threshold in c$thresholds$orig_packet_thresholds )
		{
		delete c$thresholds$orig_packet_thresholds[threshold];
		set_current_threshold(c, F, is_orig);
		return T;
		}
	else if ( ! is_orig && threshold in c$thresholds$resp_packet_thresholds )
		{
		delete c$thresholds$resp_packet_thresholds[threshold];
		set_current_threshold(c, F, is_orig);
		return T;
		}

	return F;
	}

event conn_bytes_threshold_crossed(c: connection, threshold: count, is_orig: bool) &priority=5
	{
	if ( is_orig && threshold in c$thresholds$orig_byte_thresholds )
		{
		delete c$thresholds$orig_byte_thresholds[threshold];
		event ConnThreshold::bytes_threshold_crossed(c, threshold, is_orig);
		}
	else if ( ! is_orig && threshold in c$thresholds$resp_byte_thresholds )
		{
		delete c$thresholds$resp_byte_thresholds[threshold];
		event ConnThreshold::bytes_threshold_crossed(c, threshold, is_orig);
		}

	set_current_threshold(c, T, is_orig);
	}

event conn_packets_threshold_crossed(c: connection, threshold: count, is_orig: bool) &priority=5
	{
	if ( is_orig && threshold in c$thresholds$orig_packet_thresholds )
		{
		delete c$thresholds$orig_packet_thresholds[threshold];
		event ConnThreshold::packets_threshold_crossed(c, threshold, is_orig);
		}
	else if ( ! is_orig && threshold in c$thresholds$resp_packet_thresholds )
		{
		delete c$thresholds$resp_packet_thresholds[threshold];
		event ConnThreshold::packets_threshold_crossed(c, threshold, is_orig);
		}

	set_current_threshold(c, F, is_orig);
	}