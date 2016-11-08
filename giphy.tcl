# giphy.tcl
#
# Eggdrop script to get a random gif from giphy
#
# by teel @ IRCnet
#
# https://github.com/teeli/eggdrop-giphy
#
# Version Log:
# 0.01 First version
#
################################################################################################################
#
# Usage:
#
# 1) Set the configs below
# 2) .chanset #channelname +giphy        ;# enable script
# 3) Say !giphy or .giphy on a channel where giphy is enabled
#
################################################################################################################

namespace eval Giphy {
  # CONFIG
  set ignore "bdkqr|dkqr"   ;# User flags script will ignore input from
  set delay 1               ;# minimum seconds to wait before another eggdrop use
  set timeout 5000          ;# geturl timeout (1/1000ths of a second)
  set apiUrl "http://api.giphy.com/v1/"
  set apiKey "dc6zaTOxFJmzC"

  # BINDS
  bind pub - .giphy Giphy::handler
  bind pub - !giphy Giphy::handler
  bind pub - !gif Giphy::handler
  bind pub - .gif Giphy::handler
  setudef flag giphy               ;# Channel flag to enable script.

  # INTERNAL
  set last 1                ;# Internal variable, stores time of last eggdrop use, don't change..
  set scriptVersion 0.01

  # PACKAGES
  package require http  ;# You need the http package..
  package require json  ;# and the JSON package to parse API responses

  proc handler {nick host user chan text} {
    variable delay
    variable last
    variable ignore
    set unixtime [clock seconds]

    if {[channel get $chan giphy] && ($unixtime - $delay) > $last && (![matchattr $user $ignore])} {
      set gifUrl [Giphy::callApi $text]
      if {$gifUrl != ""} {
        putserv "PRIVMSG $chan $gifUrl"
      }
    }
    # change to return 0 if you want the pubm trigger logged additionally..
    return 1
  }

  proc callApi {query} {
    variable apiUrl
    variable apiKey
    variable timeout
    set baseUrl "gifs/random"
    set encodedQuery [urlEncode $query]
    set params "?tag=$encodedQuery&api_key=$apiKey&limit=100&rating=r&fmt=json"
    set url $apiUrl$baseUrl$params

    if {[info exists url] && [string length $url]} {
      if {[catch {set http [::http::geturl $url -timeout $timeout]} results]} {
        putlog "Connection to Giphy API timed out"
      } else {
        if { [::http::status $http] == "ok" } {
          set data [::http::data $http]
          set status [::http::code $http]
          set meta [::http::meta $http]
          switch -regexp -- $status {
            "HTTP.*200.*" {
              set path "/data/image_original_url"
              set imageData [::json:select [json::json2dict $data] $path]
              return [string trim [string range $imageData [string length $path] 1024]]

            }
            "HTTP\/[0-1]\.[0-1].3.*" {
              putlog "Connection to Giphy API failed with status $status"
              return ""
            }
          }
        } else {
          putlog "Connection to Giphy API returned an invalid status"
        }
        ::http::cleanup $http
      }
    }

    return ""
  }

  # Encode all except "unreserved" characters; use UTF-8 for extended chars.
  # See http://tools.ietf.org/html/rfc3986 §2.4 and §2.5
  proc urlEncode {str} {
    # use + for spaces
    set uStr [encoding convertto utf-8 [regsub -all -nocase {\s+} $str "+"]]
    set chRE {[^-+A-Za-z0-9._~\n]};		# Newline is special case!
    set replacement {%[format "%02X" [scan "\\\0" "%c"]]}
    return [string map {"\n" "%0A"} [subst [regsub -all $chRE $uStr $replacement]]]
  }

  # Playing XPath with JSON => http://wiki.tcl.tk/40865
  proc ::json:listof? { dta class } {
    foreach i $dta {
      if { ![string is $class -strict $i] } {
        return 0
      }
    }
    return 1
  }


  proc ::json:object? { dta } {
    if { [llength $dta]%2 == 0 } {
      if { [::json:listof? $dta integer] || [::json:listof? $dta double] } {
        return 0
      }

      foreach {k v} $dta {
        if { ![string is wordchar $k] } {
          return 0
        }
      }
      return 1
    }
    return 0
  }

  proc ::json:select { dta xpr { separator "/" } {lead ""} } {
    set selection {}

    if { [::json:object? $dta] } {
      foreach { k v } $dta {
        set fv $lead$separator$k
        set selection [concat $selection [::json:select $v $xpr $separator $fv]]
        if { [string match $xpr $fv] } {
          set selection [concat [list $fv $v] $selection]
        }
      }
    }

    if { [llength $selection] == 0 } {
      set len [llength $dta]
      if { $len > 1 } {
        for {set i 0} {$i < $len} {incr i} {
          set fv $lead\($i\)
          set v [lindex $dta $i]
          set selection [concat $selection [::json:select $v $xpr $separator $fv]]
          if { [string match $xpr $fv] } {
            set selection [concat [list $fv $v] $selection]
          }
        }
      }
    }
    return $selection
  }

  putlog "Initialized Giphy v$scriptVersion"
}
