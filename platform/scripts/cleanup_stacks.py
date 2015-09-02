#!/usr/bin/env python

import sys
import os
import getopt
import re
import logging
from slingshot import get_confirmation
os.environ["BOTO_CONFIG"] = os.environ["HOME"] + "/.aws/config"
from boto import cloudformation

logger = logging.getLogger(__name__)
console_log = logging.StreamHandler()
formatter = logging.Formatter('[%(asctime)-15s] %(levelname)7s: %(message)s')
console_log.setFormatter(formatter)
logger.addHandler(console_log)
logger.setLevel(logging.INFO)


VERSION = '1.1.0'
NAME = 'cleanup_stacks'

STACK_STATUS_FILTERS = [
  'CREATE_COMPLETE',
  'UPDATE_COMPLETE',
  'UPDATE_ROLLBACK_COMPLETE',
  'UPDATE_ROLLBACK_FAILED',
  'CREATE_FAILED',
  'DELETE_FAILED',
  'ROLLBACK_COMPLETE',
  'ROLLBACK_FAILED'
  ]

FORBIDDEN_STACKS = [
  '-vpc-',
  'Subnet',
  '-vyatta',
  '-subnets',
  '-security-groups',
  '-route-tables',
  '-bucket',
  'rpm-',
  'bin-'
  ]


def usage():
    print 'Usage: %s -r region -s stack [-p aws_profile]' % NAME
    print '-r specifies the region. Required.'
    print '-s specifies a regex to be compared to the stack names.'
    print '   it can be specified multiple times to match multiple targets.'
    print '-p specifies the AWS profile (~/.aws/config)'
    print '-y will delete stacks without prompting for confirmation.'
    print 'AWS credentials are passed via the environment or via the profile option'
    print 'proxy settings are passed via the environment.'



def get_safe_stack_list(conn, regexp_stack_list):
    next_token = None
    end_list = False
    stack_list = []
    while not end_list:
        stacks = conn.list_stacks(stack_status_filters=STACK_STATUS_FILTERS, next_token=next_token)
        next_token = stacks.next_token
        end_list = next_token is None
        for stack in stacks:
            logger.debug('Stack name: %s', stack.stack_name)
            for match_stack in regexp_stack_list:
                if not re.match(match_stack, stack.stack_name):
                    continue
                if [True for f in FORBIDDEN_STACKS if f in stack.stack_name]:
                    logger.info("Cannot remove stack %s because it contains forbidden string", stack.stack_name)
                    continue
                stack_list.append(stack)
    return stack_list


def cleanup_stacks(conn, regexp_stack_list, interactive=True):
    '''
        cleanup_stacks main function

        conn: AWS connection
        regexp_stack_list: List list regex to be compared to the stack names.
        interactive: Interactive mode, ask user before delete the stacks
    '''

    logger.info("Stacks to delete:")
    stack_list = get_safe_stack_list(conn, regexp_stack_list)
    for s in stack_list:
        logger.info(s.stack_name)
    # delete the stacks matched
    confirmation_message = "Do you agree to delete those %d stacks?" % len(stack_list)
    if not interactive or get_confirmation(confirmation_message):
        for stack in stack_list:
            logger.info("deleting stack %s...", stack.stack_name)
            conn.delete_stack(stack.stack_name)


def parse_input(argv):
    '''
        parse_input entry function
    '''
    options = {
        'region': os.environ.get('AWS_REGION'),
        'noconfirmation': False,
        'stacks': [],
        'profile': None,
        'list_stacks': False
        }
    try:
        opts, args = getopt.getopt(argv, "hdp:r:vs:nyl", ["--region", "--profile", "--debug", "--stack", "--version", "--list"])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            usage()
            sys.exit()
        elif opt in ("-v", "--version"):
            print "version: %s" % VERSION
            sys.exit()
        elif opt in ("-l", "--list"):
            options['noconfirmation'] = False
            options['list_stacks'] = True
        elif opt in ("-d", "--debug"):
            logger.setLevel(logging.DEBUG)
            logger.debug('Log level DEBUG')
        elif opt in ("-r", "--region"):
            options['region'] = arg
        elif opt in ("-p", "--profile"):
            options['profile'] = arg
        elif opt in ("-y"):
            options['noconfirmation'] = True
        elif opt in ("-s", "--stack"):
            try:
                re.compile(arg)
            except Exception, e:
                logger.error("Invalid regular expression %s", arg)
                sys.exit(1)
            options['stacks'].append(arg)

    if not options['region']:
        logger.error('Needs region specified.')
        sys.exit(1)

    if options['profile']:
        conn = cloudformation.connect_to_region(options['region'], profile_name=options['profile'])
    elif 'AWS_ACCESS_KEY_ID' in os.environ and 'AWS_SECRET_ACCESS_KEY' in os.environ:
        conn = cloudformation.connect_to_region(
                options['region'],
                aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
                aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY']
            )
    else:
        logger.error('Missing AWS credentials. Check your environment/profile.')
        sys.exit(1)

    if options['list_stacks']:
        for s in get_safe_stack_list(conn, options['stacks']):
            print s.stack_name
        sys.exit()

    cleanup_stacks(conn, options['stacks'], not options['noconfirmation'])


def main(argv):
    '''
    Main
    '''
    if len(argv) == 0:
        usage()
        sys.exit()
    parse_input(argv)


if __name__ == '__main__':
    main(sys.argv[1:])
