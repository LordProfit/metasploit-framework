# -*- coding: binary -*-

module Rex
module Proto
##
#
# Minimal support for the newer Kademlia protocol, referred to here and often
# elsewhere as Kademlia2.  It is unclear how this differs from the old protocol.
#
# Protocol details are hard to come by because most documentation is academic
# in nature and glosses over the low-level network details.  The best
# documents I found on the protocol are:
#
# http://gbmaster.wordpress.com/2013/05/05/botnets-surrounding-us-an-initial-focus-on-kad/
# http://gbmaster.wordpress.com/2013/06/16/botnets-surrounding-us-sending-kademlia2_bootstrap_req-kademlia2_hello_req-and-their-strict-cousins/
# http://gbmaster.wordpress.com/2013/11/23/botnets-surrounding-us-performing-requests-sending-out-kademlia2_req-and-asking-contact-where-art-thou/
#
##
module Kademlia
  # The header that non-compressed Kad messages use
  STANDARD_PACKET = 0xE4
  # The header that compressed Kad messages use, which is currently unsupported
  COMPRESSED_PACKET = 0xE5
  # Opcode for a BOOTSTRAP request
  BOOTSTRAP_REQ = 0x01
  # Opcode for a BOOTSTRAP response
  BOOTSTRAP_RES = 0x09
  # Opcode for a PING request
  PING = 0x60
  # Opcode for a PING response
  PONG = 0x61
  # The minimum size of a peer in a KADEMLIA2_BOOTSTRAP_RES message:
  # peer ID (16-bytes), IP (4 bytes), UDP port (2 bytes), TCP port (2 bytes)
  # and version (1 byte)
  BOOTSTRAP_PEER_SIZE = 25

  # Decodes a Kademlia message.
  #
  # @param message [String] the message to decode
  # @return [Array] the message type and body if valid, nil otherwise
  def decode_message(message)
    # minimum size is header (1) + type (1) + stuff (0+)
    return if message.length < 2
    header, type = message.unpack('CC')
    if header == COMPRESSED_PACKET
      fail NotImplementedError, "Unable to handle #{message.length}-byte compressed Kademlia message"
    end
    return if header != STANDARD_PACKET
    [type, message[2, message.length]]
  end

  # Encodes a Kademlia message.
  #
  # @param type [String] the message type
  # @param body [String] the message body
  # @return [String] the encoded Kademlia message
  def encode_message(type, body = '')
    [STANDARD_PACKET, type].pack('CC') + body
  end

  # Builds a BOOTSTRAP request
  #
  # @return [String] a BOOTSTRAP request
  def bootstrap
    encode_message(BOOTSTRAP_REQ)
  end

  # Decodes a BOOTSTRAP response
  #
  # @param response [String] the response to decode
  # @return [Array] the discovered peer ID, TCP port, version and a list of peers
  #   if the response if valid, nil otherwise
  def decode_bootstrap_res(response)
    type, body = decode_message(response)
    # abort if this isn't a valid response
    return nil unless type = BOOTSTRAP_RES
    return nil unless body.size >= 23
    peer_id = decode_peer_id(body.slice!(0,16))
    tcp_port, version, num_peers = body.slice!(0,5).unpack('vCv')
    # protocol says there are no peers and the body confirms this, so just return with no peers
    return [ tcp_port, version, []] if num_peers == 0 && body.blank?
    peers = decode_bootstrap_peers(body)
    # abort if the peer data was invalid
    return nil unless peers
    [ peer_id, tcp_port, version, peers ]
  end

  # Builds a PING request
  #
  # @return [String] a PING request
  def ping
    encode_message(PING)
  end

  # Decode a PING response, PONG
  #
  # @param response [String] the response to decode
  # @return [Integer] the source port from the PING response if the response is valid, nil otherwise
  def decode_pong(response)
    type, port = decode_message(response)
    # abort if this isn't a pong
    return nil unless type == PONG
    # abort if the response is too large/small
    return nil unless port && port.size == 2
    # this should always be equivalent to the source port from which the PING was received
    port.unpack('v')[0]
  end

  # Decode a list of peers from a BOOTSTRAP response
  #
  # @param peers_data [String] the peers data from a BOOTSTRAP response
  # @return [Array] a list of the peers and their associated metadata extracted
  # from the response if valid, nil otherwise
  def decode_bootstrap_peers(peers_data)
    # sanity check total size
    return nil unless peers_data.size % BOOTSTRAP_PEER_SIZE == 0
    peers = []
    until peers_data.blank?
      peers << decode_bootstrap_peer(peers_data.slice!(0, BOOTSTRAP_PEER_SIZE))
    end
    peers
  end

  # Decodes a single set of peer data from a BOOTSTRAP reseponse
  #
  # @param peer-data [String] the peer data for one peer from a BOOSTRAP response
  # @return [Array] the peer ID, IPv4 addresss, UDP port, TCP port and version of this peer
  def decode_bootstrap_peer(peer_data)
    # sanity check the size of this peer's data
    return nil unless peer_data.size == BOOTSTRAP_PEER_SIZE
    # TODO; interpret this properly
    peer_id = peer_data.slice!(0, 16)
    ip, udp_port, tcp_port, version = peer_data.unpack('VvvC')
    [ decode_peer_id(peer_id), Rex::Socket.addr_itoa(ip), udp_port, tcp_port, version ]
  end

  # Decodes an on-the-wire representation of a Kademlia peer to its 16-character hex equivalent
  #
  # @param bytes [String] the on-the-wire representation of a Kademlia peer
  # @return [String] the peer ID if valid, nil otherwise
  def decode_peer_id(bytes)
    peer_id = 0
    return nil unless bytes.size == 16
    bytes.unpack('VVVV').map { |p| peer_id <<= 32; peer_id ^= p; }
    peer_id.to_s(16).upcase
  end

  # TODO
  # def encode_peer_id(id)
  # end
end
end
end
