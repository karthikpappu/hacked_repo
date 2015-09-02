#!/usr/bin/env python

import sys
import os
import getopt
import re
import json
import pprint
import time

os.environ["BOTO_CONFIG"] = os.environ["HOME"] + "/.aws/config"

from boto import kms

'''
 Debug function
'''
DEBUG = 0
VERSION = '1.0.0'
NAME = 'kms'
  
def     debug(str):
        if DEBUG == 1:
                print "DEBUG: %s" % str

'''
 Logging function
'''
def     log(level, str):
        print "%s: %s" % (level, str)

def     usage():
        print 'Usage: %s [-r region] [-p aws_profile] -D description create|list|disable' % NAME
        print '-r specifies the region'
        print '-p specifies the AWS profile (~/.aws/config)'
        print '-D specifies the description for the key. Required'
        print 'AWS credentials are passed via the environment or via the profile option'
        print 'AWS credentials need to be passed via the environment (AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY)'
        print 'proxy settings are passed via the environment.'

def  _kms_find(conn, options, enabled=True):
    kms_list = conn.list_keys()
    for k in kms_list['Keys']:
        desc = conn.describe_key(k['KeyId'])
        if desc['KeyMetadata']['Description'] == options['description'] and desc['KeyMetadata']['Enabled'] == enabled:
            return desc['KeyMetadata']['KeyId'], desc['KeyMetadata']['Arn']
    return (None, None)

def _kms_create(conn, options):
    (key_id, key_arn) = _kms_find(conn, options, True)
    if key_id != None:
        conn.enable_key(key_id)
        print key_arn
    else:
        (key_id, key_arn) = _kms_find(conn, options)
        if key_id == None:
            new_key = conn.create_key(description=options['description'])
            print new_key['KeyMetadata']['Arn']
        else:
            print key_arn

def _kms_disable(conn, options):
    (key_id, key_arn) = _kms_find(conn, options)
    if key_id != None:
        print "Disable key: %s" % key_arn
        conn.disable_key(key_id)


'''
_kms main function
'''
def   _kms(options):
        if options['profile'] != '':
             conn = kms.connect_to_region(options['region'], profile_name=options['profile'])
        else:
            conn = kms.connect_to_region(options['region'], aws_access_key_id=options['AWS_ACCESS_KEY_ID'], aws_secret_access_key=options['AWS_SECRET_ACCESS_KEY'])
        if options['action'] == 'list':
            (key_id, key_arn) = _kms_find(conn, options)
            if key_id != None:
                print key_arn
        elif options['action'] == 'create':
            _kms_create(conn, options)
        elif options['action'] == 'disable':
            _kms_disable(conn, options)


'''
kms entry function
'''
def   main_kms(argv):
        options = { 'region': 'us-west-2', 'profile': '', 'description': '', 'action': '' }
        asgs = {}
        try:
                opts, args = getopt.getopt(argv,"hdvr:D:p:", ["--region", "--profile", "--debug", "--desc" ])
        except getopt.GetoptError:
                usage()
                sys.exit(2)
        if os.environ.get('AWS_REGION') != None:
                options['region'] = os.environ.get('AWS_REGION')
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
                elif opt in ("-r", "--region"):
                        options['region'] = arg
                elif opt in ("-D", "--desc"):
                        options['description'] = arg
                elif opt in ("-p", "--profile"):
                        options['profile'] = arg
        if options['description'] == '':
            print "Description is empty. Required argument."
            exit(1)
        if len(args) == 0:
            usage()
            exit(1)
        action = args[0]
        if action in [ 'list', 'create', 'disable' ]:
            options['action'] = action
        else:
            print "Wrong action on kms: %s" % action
            usage()
            exit(1)
        if options['profile'] == '' and (os.environ.get('AWS_ACCESS_KEY_ID') == None or os.environ.get('AWS_SECRET_ACCESS_KEY') == None):
                log("ERROR", "Missing AWS credentials. Check your environment/profile.")
                exit(1)
        options['AWS_ACCESS_KEY_ID'] = os.environ.get('AWS_ACCESS_KEY_ID')
        options['AWS_SECRET_ACCESS_KEY'] = os.environ.get('AWS_SECRET_ACCESS_KEY')
        _kms(options)

'''
 Main
'''
def main(argv):
        if len(argv) == 0:
                usage()
                sys.exit()
        main_kms(argv)


if __name__=='__main__':
        main(sys.argv[1:])
