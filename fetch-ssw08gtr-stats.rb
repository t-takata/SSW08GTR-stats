#!/usr/bin/env ruby
# vim: ai ts=2 sts=2 et sw=2 ft=ruby

require 'net/http'
require 'uri'
require 'pp'
require 'json'
require 'optparse'

COUNTER_INDEXES = [
  {:name => "ifInOctets", :index => 0}, 
  {:name => "ifInUcastPkts", :index => 1}, 
  {:name => "ifOutOctets", :index => 16}, 
  {:name => "ifOutUcastPkts", :index => 17}, 
  {:name => "ifInErrors", :index => 26}, 
  {:name => "ifOutErrors", :index => 27}, 
  {:name => "ifInNUcastPkts", :index => 33}, 
  {:name => "ifOutNUcastPkts", :index => 36}, 
]

def generate_port_statistics(counters)
  result = {}
  COUNTER_INDEXES.each do |metric_def|
    result[metric_def[:name]] = counters[metric_def[:index]].to_i
  end
  return result
end

def login_to_switch(host_or_ip, user, pass)
  login_uri = "http://%s/pass" % [host_or_ip]
  res = Net::HTTP.post_form(URI.parse(login_uri), {
    "loginName" => user,
    "password"  => pass,
    "submit"    => "Apply",
  })

  if res.code == "200"
    return true
  else
    return false
  end
end

def get_switch_ports_stat(host_or_ip, port_range)
  ports = {}
  port_range.each do |i|
    stats_uri = "http://%s/stat?page=det&port=%d" % [host_or_ip, i]
    response_body = Net::HTTP.get(URI.parse(stats_uri))
    match = /var counters = new Array\((.*?)\);/m.match(response_body)
    if match
      counters = match[1].strip.split(/,\n?/).map{|v| v.gsub(/"/, "")}
      ports[i] = generate_port_statistics(counters)
    end
  end

  return ports
end

def main
  
  options = {}
  opt = OptionParser.new
  opt.on('-h HOSTNAME') {|v| options[:switch] = v }
  opt.on('-u USER') {|v| options[:user] = v }
  opt.on('-p PASSWORD') {|v| options[:password] = v }
  opt.parse!(ARGV)

  timestamp = Time.now.to_i
  unless login_to_switch(options[:switch], options[:user], options[:password])
    exit(1)
  end
  ports = get_switch_ports_stat(options[:switch], (0...8))
  result_hash = {
    "timestamp" => timestamp,
    "ports" => ports,
  }
  puts(JSON.dump(result_hash))
  exit(0)
end

if __FILE__ == $0
  main
end
