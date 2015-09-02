#!/usr/bin/env python
# Slingshot shared helper functions

import argparse
import re


def get_input(text):
    return raw_input(text)


def get_confirmation(msg):
    '''
        Get confirmation from user
        msg: Confirmation message
    '''
    while True:
        confirmation = get_input(msg + " (yes/NO): ").lower()
        if confirmation == '' or confirmation == 'no':
            return False
        elif confirmation == 'yes':
            return True


def valid_regexp(arg):
    '''
        check that arg is a valid regexp.

        This function is ment to be used as a type for argparse
        parser.add_argument(
            '-e', '--regex',
            required=False,
            type=valid_regexp,
            dest='regex',
            default='',
            help='specifies a regex to be compared to the volume name'
        )
    '''
    try:
        re.compile(arg)
    except Exception as e:
        msg = "'%s' is not a valid regular expression: %s" % (arg, e)
        raise argparse.ArgumentTypeError(msg)
    return arg


