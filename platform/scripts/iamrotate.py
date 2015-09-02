#!/usr/bin/env python

import sys
import os
import getopt
import re
import json
import pprint
import ConfigParser
from datetime import datetime

os.environ["BOTO_CONFIG"] = os.environ["HOME"] + "/.aws/config"

from boto import iam

'''
 Debug function
'''
DEBUG = 0
VERSION = '1.0.0'
NAME = 'iamrotate'
  
def     debug(str):
        if DEBUG == 1:
                print "DEBUG: %s" % str

'''
 Logging function
'''
def     log(level, str):
        print "%s: %s" % (level, str)



def     usage():
                print 'Usage: %s -a action -p profile|all' % NAME
                print '-a action: Required'
                print ' "rotate": the IAM credentials and update the aws configuration ~/.aws/credentials'   
                print ' "list": the IAM user with their crendentials last rotate date'             
                print '-p specifies the profile. Required. "all" will affect all profiles from ~/.aws/credentials'

def readAwsCredentials(confFile):
        config = ConfigParser.RawConfigParser(allow_no_value = True)
        config.read(confFile)
        return config

def days_between(d1, d2):
    d1 = datetime.strptime(d1, "%Y-%m-%d")
    d2 = datetime.strptime(d2, "%Y-%m-%d")
    return abs((d2 - d1).days)

def _connect_iam(region, profile):
        try:
                boto_conn = iam.connect_to_region(region, profile_name=profile)
        except Exception, e:
                log("ERROR",  "Failed to connect to profile %s %s" % (profile, e))
                raise
        return boto_conn

def _list_keys(options, awsconfig, profile):
        print "[Profile: %s]" % profile
        boto_conn = _connect_iam(options['region'], profile)
        try:
                user = boto_conn.get_user()
                keys = boto_conn.get_all_access_keys(user.user_name)
                display_config = '%-40s %-22s %-22s %-25s'
                print display_config % ('user', 'key', 'create_date', 'status')
                for k in keys.access_key_metadata:
                         print display_config % ( user.user_name, k.access_key_id, k.create_date, k.status)
        except Exception, e:
                log("ERROR", "Failed to connect to get_user %s" % (profile))


def _list(options, awsconfig):
        for s in awsconfig.sections():
                if options['profile'] != '' and options['profile'] != 'all' and s != options['profile']:
                        continue ;
                _list_keys(options, awsconfig, s)

def _rotate_key(options, awsconfig, profile):
        # create new key
        # delete previous key
        # update config file
        print "[Profile: %s]" % profile
        boto_conn = _connect_iam(options['region'], profile)
        user = boto_conn.get_user()
        #print user
        current_key_id = awsconfig.get(profile, 'aws_access_key_id')
        try:
                new_key = boto_conn.create_access_key(user_name=user.user_name)
        except Exception, e:
                log("ERROR", "Failed to create new key for user %s: %s" % (user.user_name, e))
                return
        awsconfig.set(profile, 'aws_access_key_id', new_key.access_key_id)
        awsconfig.set(profile, 'aws_secret_access_key', new_key.secret_access_key)
        print "previous key: %s" % current_key_id
        print "new key: %s" % new_key.access_key_id  
        with open(options['awsconfig'], 'wb') as configfile:
                awsconfig.write(configfile)
        boto_conn.delete_access_key(current_key_id, user_name=user.user_name)
        #_list_keys(options, awsconfig, profile)

def _rotate(options, awsconfig):
        if options['profile'] == 'all':
                for s in awsconfig.sections():
                        _rotate_key(options, awsconfig, s) 
        else:
                if awsconfig.has_section(options['profile']):
                       _rotate_key(options, awsconfig, options['profile']) 
                else:
                        log("ERROR", "No profile %s found in ~/.aws/credentials.")

def iamrotate(argv):
        options = { 'profile': '', 'region': 'us-west-2' }
        try:
                opts, args = getopt.getopt(argv,"hvdp:a:", [ "--action", "--profile", "--debug" ])
        except getopt.GetoptError:
                usage()
                sys.exit(2)
        if os.environ.get('AWS_DEFAULT_REGION') != None:
                options['region'] = os.environ.get('AWS_DEFAULT_REGION')
        for opt, arg in opts:
                if opt == '-h':
                        usage()
                        sys.exit()
                elif opt in ("-v", "--version"):
                        print "version: %s" % VERSION
                        sys.exit()
                elif opt in ("-d", "--debug"):
                        global DEBUG
                        DEBUG=1
                elif opt in ("-p", "--profile"):
                        options['profile'] = arg
                elif opt in ("-a", "--action"):
                        options['action'] = arg
                        if arg not in ['list', 'rotate']:
                                log("ERROR", "Wrong action type.")
                                usage()
                                exit(1)
        if options['action'] == '':
                log("ERROR", "Needs action specified.")
                exit(1)
        if options['profile'] == '':
                log("ERROR", "Missing profile name or 'all' statment.")
                usage()
                exit(1)
        options['awsconfig'] = "%s/.aws/credentials" % os.environ['HOME']
        awsconfig = readAwsCredentials(options['awsconfig'])
        # do not use the environment variables for the key config
        del os.environ['AWS_ACCESS_KEY_ID']
        del os.environ['AWS_SECRET_ACCESS_KEY']
        ## Take action
        if options['action'] == 'list':
                _list(options, awsconfig)
        elif options['action'] == 'rotate':
                _rotate(options, awsconfig)

'''
 Main
'''
def main(argv):
        if len(argv) == 0:
                usage()
                sys.exit()
        iamrotate(argv)


if __name__=='__main__':
        main(sys.argv[1:])
