require "excon"
require "log4r"
require "json"
require "securerandom"
require "set"
require 'singleton'
require "thread"

module VagrantCloud
  autoload :Account, "vagrant_cloud/account"
  autoload :Box, "vagrant_cloud/box"
  autoload :Client, "vagrant_cloud/client"
  autoload :Data, "vagrant_cloud/data"
  autoload :Error, "vagrant_cloud/error"
  autoload :Instrumentor, "vagrant_cloud/instrumentor"
  autoload :Logger, "vagrant_cloud/logger"
  autoload :Organization, "vagrant_cloud/organization"
  autoload :Response, "vagrant_cloud/response"
  autoload :Search, "vagrant_cloud/search"
  autoload :VERSION, "vagrant_cloud/version"
end
