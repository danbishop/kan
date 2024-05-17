# frozen_string_literal: true

def get_mac_address(ip)
  arp_info = `arp -a #{ip}`
  mac_address = arp_info.match(/(([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2})/)
  mac_address ? mac_address[0] : nil
end
  