#!/usr/bin/env python
# Script for purging AWS Ebs Unused volumes
# Author: etienne_grignon@intuit.com

import os
import sys
import re
import logging
from slingshot import valid_regexp
from datetime import datetime, timedelta
from boto import ec2
import argparse

logger = logging.getLogger(__name__)
console_log = logging.StreamHandler()
formatter = logging.Formatter('[%(asctime)-15s] %(levelname)7s: %(message)s')
console_log.setFormatter(formatter)
logger.addHandler(console_log)
logger.setLevel(logging.INFO)

DEFAULT_DAYS=7

VERSION = '1.0.0'
NAME = 'purge_ebs_volumes'

def list_ebs_volumes(conn, days, regex=None):
    '''
        Return a list of all available ebs volumes that matches regexp if any and are older than days

        conn: Boto connection
        days: Number of days
        regex: Regex
    '''
    filtered_volumes = []
    volumes = conn.get_all_volumes(filters={'status':'available'})
    logger.debug('Volumes: %s', volumes)
    time_limit = datetime.now() - timedelta(days=days)
    logger.debug("Time Limit: %s" % time_limit)
    for v in volumes:
        # Check if the volume is old enough to be deleted
        create_time = datetime.strptime(v.create_time[:-5], "%Y-%m-%dT%H:%M:%S")
        if create_time >= time_limit:
            continue
        # Check if it matches the regex
        if regex and (not re.match(regex, v.tags['Name'])):
            continue
        filtered_volumes.append(v)
    return filtered_volumes


def purge_ebs_volumes(conn, days, regex, dry_run=False):
    '''
    purge_ebs_volumes main function
    '''
    for v in list_ebs_volumes(conn, days, regex):
        logger.info("Delete volume %s %s", v.id, v.tags['Name'])
        if not dry_run:
            conn.delete_volume(v.id)


def parse_args():
    '''
        Parse arguments
    '''
    # Program options
    parser = argparse.ArgumentParser(
            prog=NAME,
            usage="%(prog)s -r region [options]",
            description='''AWS credentials are passed via the environment
AWS credentials need to be passed via the environment (AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY)
proxy settings are passed via the environment.
'''
        )
    parser.add_argument(
        '-v', '--version', action='version', version="Version: %s" % VERSION,
        help='Print version and exit'
    )
    parser.add_argument(
        '-d', '--debug',
        required=False, default=False, dest='debug', action='store_true',
        help='Debug on'
    )
    parser.add_argument(
        '-r', '--region', required=True,
        dest='region',
        default=None,
        help='AWS Region. Required'
    )
    parser.add_argument(
        '-e', '--regex',
        required=False,
        type=valid_regexp,
        dest='regex',
        default='',
        help='specifies a regex to be compared to the volume name'
    )
    parser.add_argument(
        '-t', '--days',
        type=int,
        required=False,
        dest='days',
        default=DEFAULT_DAYS,
        help="specifies the minimum number of days the volume has to be for deletion. Default to %s days" % DEFAULT_DAYS
    )
    parser.add_argument(
        '-n', '--noop',
        required=False, default=False, dest='dry_run', action='store_true',
        help='Dry run mode'
    )
    options = parser.parse_args()

    return options


def main(argv):
    '''
     Main
    '''
    options = parse_args()
    if options.debug:
        logger.setLevel(logging.DEBUG)
        logger.debug('Log level DEBUG')

    if 'AWS_PROFILE' in os.environ:
        conn = ec2.connect_to_region(
            options.region,
            profile_name=os.environ['AWS_PROFILE'])
    elif 'AWS_ACCESS_KEY_ID' in os.environ and 'AWS_SECRET_ACCESS_KEY' in os.environ:
        conn = ec2.connect_to_region(
            options.region,
            aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
            aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'])
    else:
        logger.error("Missing AWS credentials. Check your environment.")
        sys.exit(1)

    if options.dry_run:
        logger.info("Dry run mode, just listing")

    purge_ebs_volumes(conn, options.days, options.regex, options.dry_run)

    if options.dry_run:
        logger.info("Dry run mode, no volume has been removed")

if __name__ == '__main__':
    main(sys.argv[1:])

