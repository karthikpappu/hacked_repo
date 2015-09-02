#!/usr/bin/env python

import sys
import os
import getopt
import re
import json
import pprint
import time

os.environ["BOTO_CONFIG"] = os.environ["HOME"] + "/.aws/config"

from boto import cloudformation

'''
 Debug function
'''
DEBUG = 0
VERSION = '1.3.2'
NAME = 'query_stack'
  
def     debug(str):
        if DEBUG == 1:
                print "DEBUG: %s" % str

'''
 Logging function
'''
def     log(level, str):
        print "%s: %s" % (level, str)

def     usage():
                print 'Usage: %s -r region -s stack [-p aws_profile] [-S | -o output_key | -i resource_logical_id]' % NAME
                print '-r specifies the region. Required.'
                print '-s specifies a regex to be compared to the stack name.'
                print '-o specifies the key name of the output value to print out.'
                print '-i specifies the logical id name of the resource value to print out.'
                print '-S will print the stack status'
                print '-n will disable regular expression matching on stack name. provide exact stack name for -s option.'
                print '-p specifies the AWS profile (~/.aws/config)'
                print '-s, -o and -i options can be specified multiple times to match multiple targets.'
                print 'AWS credentials are passed via the environment or via the profile option'
                print 'AWS credentials need to be passed via the environment (AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY)'
                print 'proxy settings are passed via the environment.'

def discover_stack(options, conn, json_all_stacks, stack_name):
      try:
          detailed_stack = conn.describe_stacks(stack_name_or_id=stack_name)
      except Exception, e:
          #log("ERROR", "Could not find the stack \"%s\": %s" % (stack_name, e))
          return 
      # Getting outputs
      if len(options['outputs']) > 0:
          for ds in detailed_stack:
            for o in ds.outputs:
                for output in options['outputs']:
                    if o.key == output:
                        debug("DEBUG %s=%s" % (o.key, o.value))
                        print o.value
      # Getting resources
      elif len(options['resources']) > 0:
        resources = conn.list_stack_resources(stack_name_or_id=stack_name)
        for resource in resources:
          debug("resource: %s=%s" % (resource.logical_resource_id, resource.physical_resource_id))
          for matching_resource in options['resources']:
            if resource.logical_resource_id == matching_resource:
                print resource.physical_resource_id
      elif options['status'] == True:
        if len(detailed_stack) == 1:
            print "%s:%s" % (stack_name, detailed_stack[0].stack_status)
      else: # Print full details of Resources/Output if no key/id specified
        json_stack = dict()
        json_stack[stack_name] = dict()
        resources = conn.list_stack_resources(stack_name_or_id=stack_name)
        json_stack[stack_name]['resources'] = dict()
        for resource in resources:
          json_stack[stack_name]['resources'][resource.logical_resource_id] = resource.physical_resource_id
        json_stack[stack_name]['outputs'] = dict()
        detailed_stack = conn.describe_stacks(stack_name_or_id=stack_name)
        for ds in detailed_stack:
          for o in ds.outputs:
            json_stack[stack_name]['outputs'][o.key] = o.value
        #print json.dumps(json_stack, indent=4, sort_keys=True)
        json_all_stacks['stacks'] = dict(json_all_stacks['stacks'].items() + json_stack.items())

'''
_query_stack main function
'''
def   _query_stack(options):
        if options['profile'] != '':
             conn = cloudformation.connect_to_region(options['region'], profile_name=options['profile'])
        else:
            conn = cloudformation.connect_to_region(options['region'], aws_access_key_id=options['AWS_ACCESS_KEY_ID'], aws_secret_access_key=options['AWS_SECRET_ACCESS_KEY'])
        stack_status_filters=[ 'CREATE_IN_PROGRESS', 'CREATE_COMPLETE', 'UPDATE_IN_PROGRESS', 'UPDATE_COMPLETE' ]
        next_token=None
        end_list=False
        json_all_stacks = dict()
        json_all_stacks['stacks'] = dict()
        ## Using no regex will improve speed of the process
        if options['regex'] == False:
            for stack_name in options['stacks']:
                  debug("Will discover %s" % (stack_name))
                  discover_stack(options, conn, json_all_stacks, stack_name)
        else:
            while (end_list == False):
                stacks = conn.list_stacks(stack_status_filters=stack_status_filters, next_token=next_token)
                next_token = stacks.next_token
                if next_token == None:
                    end_list=True

                for stack in stacks:
                  debug("%s : %s" % (stack.stack_name, stack.stack_status))
                  for match_stack in options['stacks']:
                      a = re.compile(match_stack)
                      result = a.match(stack.stack_name)
                      if result == None:
                        continue
                      debug("Will discover %s" % (stack.stack_name))
                      discover_stack(options, conn, json_all_stacks, stack.stack_name)
        if len(json_all_stacks['stacks']) > 0:
          print json.dumps(json_all_stacks, indent=4, sort_keys=True)


'''
query_stack entry function
'''
def   query_stack(argv):
        options = { 'region': '', 'stacks': [], 'regex': True, 'profile': '', 'outputs': [], 'resources': [], 'status': False}
        asgs = {}
        try:
                opts, args = getopt.getopt(argv,"hdvSs:nr:o:i:p:", ["--region", "--noregex", "--profile", "--debug", "--status", "--stack", "--output", "--id", "--version" ])
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
                elif opt in ("-p", "--profile"):
                        options['profile'] = arg
                elif opt in ("-S", "--status"):
                        options['status'] = True
                elif opt in ("-n", "--noregex"):
                        options['regex'] = False
                elif opt in ("-s", "--stack"):
                        options['stacks'].append(arg)
                        try:
                                re.compile(arg)
                        except Exception, e:
                                log("ERROR", "Invalid regular expression %s" % arg)
                                exit(1)
                elif opt in ("-o", "--output"):
                        options['outputs'].append(arg)
                elif opt in ("-i", "--id"):
                        options['resources'].append(arg)
        if options['region'] == '':
                log("ERROR", "Needs region specified.")
                exit(1)
        if options['profile'] == '' and (os.environ.get('AWS_ACCESS_KEY_ID') == None or os.environ.get('AWS_SECRET_ACCESS_KEY') == None):
                log("ERROR", "Missing AWS credentials. Check your environment/profile.")
                exit(1)
        options['AWS_ACCESS_KEY_ID'] = os.environ.get('AWS_ACCESS_KEY_ID')
        options['AWS_SECRET_ACCESS_KEY'] = os.environ.get('AWS_SECRET_ACCESS_KEY')
        ## Need sleep to avoid the AWS Rate exceeded in throttling error
        time.sleep(1)
        _query_stack(options)

'''
 Main
'''
def main(argv):
        if len(argv) == 0:
                usage()
                sys.exit()
        query_stack(argv)


if __name__=='__main__':
        main(sys.argv[1:])
