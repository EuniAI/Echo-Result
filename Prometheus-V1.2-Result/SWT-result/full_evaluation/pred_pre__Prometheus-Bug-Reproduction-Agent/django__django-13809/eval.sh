#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD bef6f7584280f1cc80e5e2d80b7ad073a93d26ec >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff bef6f7584280f1cc80e5e2d80b7ad073a93d26ec
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/builtin_server/test_runserver_command.py b/tests/builtin_server/test_runserver_command.py
new file mode 100644
index 0000000000..ed124934eb
--- /dev/null
+++ b/tests/builtin_server/test_runserver_command.py
@@ -0,0 +1,190 @@
+import sys
+import traceback
+from io import BytesIO
+from unittest import TestCase, mock
+from wsgiref import simple_server
+
+from django.core.management import call_command
+from django.core.servers.basehttp import get_internal_wsgi_application
+from django.core.signals import request_finished
+from django.test import RequestFactory, SimpleTestCase, override_settings
+
+from .views import FILE_RESPONSE_HOLDER
+
+# If data is too large, socket will choke, so write chunks no larger than 32MB
+# at a time. The rationale behind the 32MB can be found in #5596#comment:4.
+MAX_SOCKET_CHUNK_SIZE = 32 * 1024 * 1024  # 32 MB
+
+
+class ServerHandler(simple_server.ServerHandler):
+    error_status = "500 INTERNAL SERVER ERROR"
+
+    def write(self, data):
+        """'''write()''' callable as specified by PEP 3333"""
+
+        assert isinstance(data, bytes), "write() argument must be bytestring"
+
+        if not self.status:
+            raise AssertionError("write() before start_response()")
+
+        elif not self.headers_sent:
+            # Before the first output, send the stored headers
+            self.bytes_sent = len(data)    # make sure we know content-length
+            self.send_headers()
+        else:
+            self.bytes_sent += len(data)
+
+        # XXX check Content-Length and truncate if too many bytes written?
+        data = BytesIO(data)
+        for chunk in iter(lambda: data.read(MAX_SOCKET_CHUNK_SIZE), b''):
+            self._write(chunk)
+            self._flush()
+
+    def error_output(self, environ, start_response):
+        super().error_output(environ, start_response)
+        return ['\n'.join(traceback.format_exception(*sys.exc_info()))]
+
+
+class DummyHandler:
+    def log_request(self, *args, **kwargs):
+        pass
+
+
+class FileWrapperHandler(ServerHandler):
+    def __init__(self, *args, **kwargs):
+        super().__init__(*args, **kwargs)
+        self.request_handler = DummyHandler()
+        self._used_sendfile = False
+
+    def sendfile(self):
+        self._used_sendfile = True
+        return True
+
+
+def wsgi_app(environ, start_response):
+    start_response('200 OK', [('Content-Type', 'text/plain')])
+    return [b'Hello World!']
+
+
+def wsgi_app_file_wrapper(environ, start_response):
+    start_response('200 OK', [('Content-Type', 'text/plain')])
+    return environ['wsgi.file_wrapper'](BytesIO(b'foo'))
+
+
+class WSGIFileWrapperTests(TestCase):
+    """
+    The wsgi.file_wrapper works for the builtin server.
+
+    Tests for #9659: wsgi.file_wrapper in the builtin server.
+    We need to mock a couple of handlers and keep track of what
+    gets called when using a couple kinds of WSGI apps.
+    """
+
+    def test_file_wrapper_uses_sendfile(self):
+        env = {'SERVER_PROTOCOL': 'HTTP/1.0'}
+        handler = FileWrapperHandler(None, BytesIO(), BytesIO(), env)
+        handler.run(wsgi_app_file_wrapper)
+        self.assertTrue(handler._used_sendfile)
+        self.assertEqual(handler.stdout.getvalue(), b'')
+        self.assertEqual(handler.stderr.getvalue(), b'')
+
+    def test_file_wrapper_no_sendfile(self):
+        env = {'SERVER_PROTOCOL': 'HTTP/1.0'}
+        handler = FileWrapperHandler(None, BytesIO(), BytesIO(), env)
+        handler.run(wsgi_app)
+        self.assertFalse(handler._used_sendfile)
+        self.assertEqual(handler.stdout.getvalue().splitlines()[-1], b'Hello World!')
+        self.assertEqual(handler.stderr.getvalue(), b'')
+
+    @override_settings(ROOT_URLCONF='builtin_server.urls')
+    def test_file_response_closing(self):
+        """
+        View returning a FileResponse properly closes the file and http
+        response when file_wrapper is used.
+        """
+        env = RequestFactory().get('/fileresponse/').environ
+        handler = FileWrapperHandler(None, BytesIO(), BytesIO(), env)
+        handler.run(get_internal_wsgi_application())
+        # Sendfile is used only when file_wrapper has been used.
+        self.assertTrue(handler._used_sendfile)
+        # Fetch the original response object.
+        self.assertIn('response', FILE_RESPONSE_HOLDER)
+        response = FILE_RESPONSE_HOLDER['response']
+        # The response and file buffers are closed.
+        self.assertIs(response.closed, True)
+        buf1, buf2 = FILE_RESPONSE_HOLDER['buffers']
+        self.assertIs(buf1.closed, True)
+        self.assertIs(buf2.closed, True)
+        FILE_RESPONSE_HOLDER.clear()
+
+    @override_settings(ROOT_URLCONF='builtin_server.urls')
+    def test_file_response_call_request_finished(self):
+        env = RequestFactory().get('/fileresponse/').environ
+        handler = FileWrapperHandler(None, BytesIO(), BytesIO(), env)
+        with mock.MagicMock() as signal_handler:
+            request_finished.connect(signal_handler)
+            handler.run(get_internal_wsgi_application())
+            self.assertEqual(signal_handler.call_count, 1)
+
+
+class WriteChunkCounterHandler(ServerHandler):
+    """
+    Server handler that counts the number of chunks written after headers were
+    sent. Used to make sure large response body chunking works properly.
+    """
+
+    def __init__(self, *args, **kwargs):
+        super().__init__(*args, **kwargs)
+        self.request_handler = DummyHandler()
+        self.headers_written = False
+        self.write_chunk_counter = 0
+
+    def send_headers(self):
+        super().send_headers()
+        self.headers_written = True
+
+    def _write(self, data):
+        if self.headers_written:
+            self.write_chunk_counter += 1
+        self.stdout.write(data)
+
+
+def send_big_data_app(environ, start_response):
+    start_response('200 OK', [('Content-Type', 'text/plain')])
+    # Return a blob of data that is 1.5 times the maximum chunk size.
+    return [b'x' * (MAX_SOCKET_CHUNK_SIZE + MAX_SOCKET_CHUNK_SIZE // 2)]
+
+
+class ServerHandlerChunksProperly(TestCase):
+    """
+    The ServerHandler chunks data properly.
+
+    Tests for #18972: The logic that performs the math to break data into
+    32MB (MAX_SOCKET_CHUNK_SIZE) chunks was flawed, BUT it didn't actually
+    cause any problems.
+    """
+
+    def test_chunked_data(self):
+        env = {'SERVER_PROTOCOL': 'HTTP/1.0'}
+        handler = WriteChunkCounterHandler(None, BytesIO(), BytesIO(), env)
+        handler.run(send_big_data_app)
+        self.assertEqual(handler.write_chunk_counter, 2)
+
+
+class RunserverCommandTests(SimpleTestCase):
+    @override_settings(
+        STATICFILES_DIRS='foo',
+        INSTALLED_APPS=[
+            'django.contrib.auth',
+            'django.contrib.contenttypes',
+            'django.contrib.staticfiles',
+        ],
+    )
+    @mock.patch('django.core.servers.basehttp.run')
+    def test_skip_checks_option(self, mocked_run):
+        """
+        The runserver command should not perform system checks with
+        --skip-checks.
+        """
+        call_command('runserver', '--skip-checks')
+        mocked_run.assert_called_once()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/runserver\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 builtin_server.test_runserver_command
cat coverage.cover
git checkout bef6f7584280f1cc80e5e2d80b7ad073a93d26ec
git apply /root/pre_state.patch
