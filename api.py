#!/usr/bin/env python
import os
import time

from daemon import runner
from tornado.wsgi import WSGIContainer
from tornado.httpserver import HTTPServer
from tornado.ioloop import IOLoop
from api import app



class webservice():

	def __init__(self):
	  self.stdin_path = '/dev/null'
	  self.stdout_path = '/dev/tty'
	  self.stderr_path = '/dev/tty'
	  self.pidfile_path = '/opt/f5backup/pid/'
	  self.pidfile_timeout = 5

	def run(self):
		http_server = HTTPServer(WSGIContainer(app))
		http_server.listen(5380, address='127.0.0.1')
		IOLoop.instance().start()

daemon_runner = runner.DaemonRunner( webservice() )
daemon_runner.do_action()