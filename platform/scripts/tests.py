#!/usr/bin/python
# -*- coding: utf-8 -*-

import unittest
import datetime
from argparse import ArgumentTypeError
from mock import Mock, patch
from cleanup_stacks import *
from slingshot import get_confirmation
from slingshot import valid_regexp
from purge_ebs_volumes import list_ebs_volumes, purge_ebs_volumes

import logging
logger = logging.getLogger(__name__)


class Stack:
    def __init__(self, name):
        self.stack_name = name


class StackList(list):
    def __init__(self, result_list, next_token):
        super(StackList, self).__init__(result_list)
        self.next_token = next_token

class AWSConnectionTestClass:
    def __init__(self, result):
        self.result = result
        self.calls = 0
        self.stack_status_filters = []
        self.next_token = []

    def list_stacks(self, stack_status_filters, next_token):
        self.stack_status_filters.append(stack_status_filters)
        self.next_token.append(next_token)
        self.calls += 1
        r = self.result[self.calls - 1]
        return StackList(r['result'], r['next_token'])


class TestConfirmation(unittest.TestCase):
    @patch('slingshot.get_input', side_effect=['asdf', 'qwer', 'nO'])
    def test_get_confirmation_negative(self, mock):
        self.assertFalse(get_confirmation('Test confirmation'))
        mock.assert_called_once()
        self.assertEqual(3, mock.call_count)
        mock.reset_mock()

    @patch('slingshot.get_input', side_effect=['asdf', 'qwer', 'yEs'])
    def test_get_confirmation_possitive(self, mock):
        self.assertTrue(get_confirmation('Test confirmation'))
        mock.assert_called_once()
        self.assertEqual(3, mock.call_count)
        mock.reset_mock()


class TestValidRegexp(unittest.TestCase):
    def test_invalid_reguexp(self):
        invalid_regexp = '.*[]'
        self.assertRaises(
                ArgumentTypeError,
                valid_regexp, invalid_regexp
            )

    def test_regexp(self):
        regexp = '.*'
        self.assertEqual(regexp, valid_regexp(regexp))


class TestGetStackList(unittest.TestCase):

    def test_forbidden_list(self):
        forbiden_stacks = [Stack('test%stest' % fb) for fb in FORBIDDEN_STACKS]
        conn = AWSConnectionTestClass([
            {
                'result': forbiden_stacks,
                'next_token': None
            },
            ])
        regexp_stack_list = ['.*', ]
        returned_list = get_safe_stack_list(conn, regexp_stack_list)
        self.assertEqual(returned_list, [])

    def test_empty_list(self):
        conn = AWSConnectionTestClass([{'result': [], 'next_token':None}])
        regexp_stack_list = ['.*']
        returned_list = get_safe_stack_list(conn, regexp_stack_list)
        self.assertEqual(returned_list, [])

    def test_some_matches(self):
        stack_names = ['name1', 'name2', 'name3']
        stacks = [Stack(name) for name in stack_names]
        conn = AWSConnectionTestClass([
            {
                'result': stacks,
                'next_token': None
            },
            ])
        regexp_stack_list = ['.*', ]
        returned_list = get_safe_stack_list(conn, regexp_stack_list)
        self.assertEqual(returned_list, stacks)

    def test_several_pages(self):
        stack_names1 = ['name1', 'name2', 'name3']
        stack_names2 = ['name4', 'name5', 'name6']
        stacks1 = [Stack(name) for name in stack_names1]
        stacks2 = [Stack(name) for name in stack_names2]
        conn = AWSConnectionTestClass([
            {
                'result': stacks1,
                'next_token': True
            },
            {
                'result': stacks2,
                'next_token': None
            },
            ])
        regexp_stack_list = ['.*', ]
        returned_list = get_safe_stack_list(conn, regexp_stack_list)
        self.assertEqual(returned_list, stacks1 + stacks2)


STACKS_TO_DELETE = [Stack(name) for name in ('stack1', 'stack2', 'stack3')]


class TestCleanupStacks(unittest.TestCase):

    @patch('cleanup_stacks.get_safe_stack_list', return_value=STACKS_TO_DELETE)
    @patch('cleanup_stacks.get_confirmation', return_value=True)
    def test_delete_some_non_interactive(self, get_confirmation, get_safe_stack_list):
        conn = Mock()
        regexp_stack_list = ['.*']
        cleanup_stacks(conn, regexp_stack_list, False)
        get_safe_stack_list.assert_called_with(conn, regexp_stack_list)
        self.assertEqual(get_confirmation.call_count, 0)
        conn.delete_stack.assert_called_with(STACKS_TO_DELETE[-1].stack_name)
        self.assertEqual(conn.delete_stack.call_count, 3)

    @patch('cleanup_stacks.get_safe_stack_list', return_value=STACKS_TO_DELETE)
    @patch('cleanup_stacks.get_confirmation', return_value=True)
    def test_delete_some_interactive(self, get_confirmation, get_safe_stack_list):
        conn = Mock()
        regexp_stack_list = ['.*']
        cleanup_stacks(conn, regexp_stack_list)
        get_safe_stack_list.assert_called_with(conn, regexp_stack_list)
        get_confirmation.assert_called_once()
        conn.delete_stack.assert_called_with(STACKS_TO_DELETE[-1].stack_name)
        self.assertEqual(conn.delete_stack.call_count, 3)

    @patch('cleanup_stacks.get_safe_stack_list', return_value=STACKS_TO_DELETE)
    @patch('cleanup_stacks.get_confirmation', return_value=False)
    def test_delete_some_interactive_user_dont_want_to_delete(self, get_confirmation, get_safe_stack_list):
        conn = Mock()
        regexp_stack_list = ['.*']
        cleanup_stacks(conn, regexp_stack_list)
        get_safe_stack_list.assert_called_with(conn, regexp_stack_list)
        get_confirmation.assert_called_once()
        self.assertEqual(conn.delete_stack.call_count, 0)


class TestPurgeEBSVolumes(unittest.TestCase):
    class DummyVolume():
        def __init__(self, id, name, creation_date):
            self.id = id
            self.tags = {'Name': name}
            self.create_time = creation_date.strftime("%Y-%m-%dT%H:%M:%S.....")

    def setUp(self):
        volumes = '''vol-6a309a8d i-e02beb28_app 1
vol-f206ac15 i-ae418166_app 2
vol-8df6436a i-305797f8_app 3
vol-aff04548 i-89589841_app 4
vol-aba99db9 i-da7c472c_app 5
vol-d3a99dc1 i-d57c4723_app 6
vol-13320201 i-2caaaeda_app 7
vol-86142494 i-325156c4_app 8
vol-721e2c60 i-76272680_app 9
vol-e4211df6 i-c0f7f436_app 10
vol-da221ec8 i-6df0f39b_app 11
vol-0fe3df1d i-c7bebd31_app 12'''
        self.volume_list = []
        for l in volumes.split('\n'):
            id, name, days = l.split(' ')
            volume_date = datetime.datetime.now() - datetime.timedelta(days=int(days))
            self.volume_list.append(TestPurgeEBSVolumes.DummyVolume(id, name, volume_date))

    def test_list_ebs_volumes_no_regexp(self):
        conn = Mock()
        conn.get_all_volumes = Mock(return_value=self.volume_list)
        conn.get_all_volumes.assert_called_once()
        conn.get_all_volumes.reset_mock()
        days = 0
        self.assertEqual(self.volume_list, list_ebs_volumes(conn, days))
        conn.get_all_volumes.assert_called_once()
        conn.get_all_volumes.reset_mock()

        days = 13
        self.assertEqual([], list_ebs_volumes(conn, days))
        conn.get_all_volumes.assert_called_once()
        conn.get_all_volumes.reset_mock()

        days = 5
        filtered_volumes = list_ebs_volumes(conn, days)
        self.assertEqual(8, len(filtered_volumes))
        conn.get_all_volumes.assert_called_once()
        conn.get_all_volumes.reset_mock()

    def test_list_ebs_volumes_regexp(self):
        conn = Mock()
        conn.get_all_volumes = Mock(return_value=self.volume_list)
        days = 0
        regexp = 'i-\d.+'
        filtered_volumes = list_ebs_volumes(conn, days, regexp)
        for v in filtered_volumes:
            self.assertTrue(re.match(regexp, v.tags['Name']))
        conn.get_all_volumes.assert_called_once()
        conn.get_all_volumes.reset_mock()

        days = 5
        filtered_volumes = list_ebs_volumes(conn, days, regexp)
        self.assertEqual(4, len(filtered_volumes))
        for v in filtered_volumes:
            self.assertTrue(re.match(regexp, v.tags['Name']))
        conn.get_all_volumes.assert_called_once()

    def test_purge_ebs_volumes_noop(self):
        conn = Mock()
        conn.delete_volume = Mock()
        with patch('purge_ebs_volumes.list_ebs_volumes', return_value=self.volume_list):
            purge_ebs_volumes(conn, 0, '', True)
        self.assertFalse(conn.delete_volume.called)

    def test_purge_ebs_volumes(self):
        conn = Mock()
        conn.delete_volume = Mock()
        with patch('purge_ebs_volumes.list_ebs_volumes', return_value=self.volume_list):
            purge_ebs_volumes(conn, 0, '', False)
        self.assertTrue(conn.delete_volume.called)
        self.assertEqual(len(self.volume_list), conn.delete_volume.call_count)

if __name__ == '__main__':
    logging.basicConfig()
    logger.setLevel(logging.DEBUG)
    unittest.main()
