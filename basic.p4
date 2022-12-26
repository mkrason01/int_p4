#include <core.p4>
#include <v1model.p4>

//headers
typedef bit<9>  egressPort;
typedef bit<48> macAddres;
typedef bit<32> ip4Addres;
header Ethernet {
    macAddres dstAddr;
    macAddres srcAddr;
    bit<16>   etherType;
}

header ipv4 {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   headerChecksum;
    ip4Addres srcAddr;
    ip4Addres dstAddr;
    bit<64> UDP_H;
    bit<32> SHIM;
    bit<96> INT_HEADER;
    bit<32> INT_META;
}

struct metadata { }

struct headers {
    Ethernet   ethernet;
    ipv4       IPh;
}

//parser
parser MyParser(packet_in packet,
                out headers all_headers,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        packet.extract(all_headers.ethernet);
        transition select(all_headers.ethernet.etherType) {
            0x800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        packet.extract(all_headers.IPh);
	transition accept;
    }
}

//Checksum verification
control MyVerifyChecksum(inout headers all_headers, inout metadata meta) {  
    apply {  }
}

//ingress processing
control MyIngress(inout headers all_headers,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop();
    }
    //action add_delta() {
    //            all_headers.IPh.INT_META  = 15;
    //    }
    action forward(egressPort port) {
        standard_metadata.egress_spec = port;
    }
    table phy_forward {
        key = {
            standard_metadata.ingress_port: exact;
        }
        actions = {
            forward;
        //  add_delta;
	        drop;
        }
        size = 1024;
        default_action = drop();
    }
   
    apply {
        phy_forward.apply();
    }
}

//egress processing
control MyEgress(inout headers all_headers,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
        apply { 
 }
}

//checksum computation
control MyComputeChecksum(inout headers  all_headers, inout metadata meta) {
     apply {
        update_checksum(
            all_headers.IPh.isValid(),
            { all_headers.IPh.version,
              all_headers.IPh.ihl,
              all_headers.IPh.diffserv,
              all_headers.IPh.totalLen,
              all_headers.IPh.identification,
              all_headers.IPh.flags,
              all_headers.IPh.fragOffset,
              all_headers.IPh.ttl,
              all_headers.IPh.protocol,
              all_headers.IPh.srcAddr,
              all_headers.IPh.dstAddr },
            all_headers.IPh.headerChecksum,
            HashAlgorithm.csum16);
    }
}

//Deparser
control MyDeparser(packet_out packet, in headers all_headers) {
    apply {
        packet.emit(all_headers.ethernet);
        packet.emit(all_headers.IPh);
    }
}

//Combining everything together
V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;