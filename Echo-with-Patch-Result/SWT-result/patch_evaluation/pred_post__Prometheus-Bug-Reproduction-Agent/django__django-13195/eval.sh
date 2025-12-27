#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 156a2138db20abc89933121e4ff2ee2ce56a173a >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 156a2138db20abc89933121e4ff2ee2ce56a173a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/messages/storage/cookie.py b/django/contrib/messages/storage/cookie.py
--- a/django/contrib/messages/storage/cookie.py
+++ b/django/contrib/messages/storage/cookie.py
@@ -92,7 +92,11 @@ def _update_cookie(self, encoded_data, response):
                 samesite=settings.SESSION_COOKIE_SAMESITE,
             )
         else:
-            response.delete_cookie(self.cookie_name, domain=settings.SESSION_COOKIE_DOMAIN)
+            response.delete_cookie(
+                self.cookie_name,
+                domain=settings.SESSION_COOKIE_DOMAIN,
+                samesite=settings.SESSION_COOKIE_SAMESITE,
+            )
 
     def _store(self, messages, response, remove_oldest=True, *args, **kwargs):
         """
diff --git a/django/contrib/sessions/middleware.py b/django/contrib/sessions/middleware.py
--- a/django/contrib/sessions/middleware.py
+++ b/django/contrib/sessions/middleware.py
@@ -42,6 +42,7 @@ def process_response(self, request, response):
                 settings.SESSION_COOKIE_NAME,
                 path=settings.SESSION_COOKIE_PATH,
                 domain=settings.SESSION_COOKIE_DOMAIN,
+                samesite=settings.SESSION_COOKIE_SAMESITE,
             )
             patch_vary_headers(response, ('Cookie',))
         else:
diff --git a/django/http/response.py b/django/http/response.py
--- a/django/http/response.py
+++ b/django/http/response.py
@@ -210,13 +210,18 @@ def set_signed_cookie(self, key, value, salt='', **kwargs):
         value = signing.get_cookie_signer(salt=key + salt).sign(value)
         return self.set_cookie(key, value, **kwargs)
 
-    def delete_cookie(self, key, path='/', domain=None):
-        # Most browsers ignore the Set-Cookie header if the cookie name starts
-        # with __Host- or __Secure- and the cookie doesn't use the secure flag.
-        secure = key.startswith(('__Secure-', '__Host-'))
+    def delete_cookie(self, key, path='/', domain=None, samesite=None):
+        # Browsers can ignore the Set-Cookie header if the cookie doesn't use
+        # the secure flag and:
+        # - the cookie name starts with "__Host-" or "__Secure-", or
+        # - the samesite is "none".
+        secure = (
+            key.startswith(('__Secure-', '__Host-')) or
+            (samesite and samesite.lower() == 'none')
+        )
         self.set_cookie(
             key, max_age=0, path=path, domain=domain, secure=secure,
-            expires='Thu, 01 Jan 1970 00:00:00 GMT',
+            expires='Thu, 01 Jan 1970 00:00:00 GMT', samesite=samesite,
         )
 
     # Common methods used by subclasses

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_http_response_cookies.py b/tests/test_http_response_cookies.py
new file mode 100644
index 0000000000..595c8866ba
--- /dev/null
+++ b/tests/test_http_response_cookies.py
@@ -0,0 +1,129 @@
+import time
+from datetime import datetime, timedelta
+from http import cookies
+
+from django.http import HttpResponse
+from django.test import SimpleTestCase
+from django.test.utils import freeze_time
+from django.utils.http import http_date
+from django.utils.timezone import utc
+
+
+class SetCookieTests(SimpleTestCase):
+
+    def test_near_expiration(self):
+        """Cookie will expire when a near expiration time is provided."""
+        response = HttpResponse()
+        # There's a timing weakness in this test; The expected result for
+        # max-age requires that there be a very slight difference between the
+        # evaluated expiration time and the time evaluated in set_cookie(). If
+        # this difference doesn't exist, the cookie time will be 1 second
+        # larger. The sleep guarantees that there will be a time difference.
+        expires = datetime.utcnow() + timedelta(seconds=10)
+        time.sleep(0.001)
+        response.set_cookie('datetime', expires=expires)
+        datetime_cookie = response.cookies['datetime']
+        self.assertEqual(datetime_cookie['max-age'], 10)
+
+    def test_aware_expiration(self):
+        """set_cookie() accepts an aware datetime as expiration time."""
+        response = HttpResponse()
+        expires = (datetime.utcnow() + timedelta(seconds=10)).replace(tzinfo=utc)
+        time.sleep(0.001)
+        response.set_cookie('datetime', expires=expires)
+        datetime_cookie = response.cookies['datetime']
+        self.assertEqual(datetime_cookie['max-age'], 10)
+
+    def test_create_cookie_after_deleting_cookie(self):
+        """Setting a cookie after deletion clears the expiry date."""
+        response = HttpResponse()
+        response.set_cookie('c', 'old-value')
+        self.assertEqual(response.cookies['c']['expires'], '')
+        response.delete_cookie('c')
+        self.assertEqual(response.cookies['c']['expires'], 'Thu, 01 Jan 1970 00:00:00 GMT')
+        response.set_cookie('c', 'new-value')
+        self.assertEqual(response.cookies['c']['expires'], '')
+
+    def test_far_expiration(self):
+        """Cookie will expire when a distant expiration time is provided."""
+        response = HttpResponse()
+        response.set_cookie('datetime', expires=datetime(2038, 1, 1, 4, 5, 6))
+        datetime_cookie = response.cookies['datetime']
+        self.assertIn(
+            datetime_cookie['expires'],
+            # assertIn accounts for slight time dependency (#23450)
+            ('Fri, 01 Jan 2038 04:05:06 GMT', 'Fri, 01 Jan 2038 04:05:07 GMT')
+        )
+
+    def test_max_age_expiration(self):
+        """Cookie will expire if max_age is provided."""
+        response = HttpResponse()
+        set_cookie_time = time.time()
+        with freeze_time(set_cookie_time):
+            response.set_cookie('max_age', max_age=10)
+        max_age_cookie = response.cookies['max_age']
+        self.assertEqual(max_age_cookie['max-age'], 10)
+        self.assertEqual(max_age_cookie['expires'], http_date(set_cookie_time + 10))
+
+    def test_httponly_cookie(self):
+        response = HttpResponse()
+        response.set_cookie('example', httponly=True)
+        example_cookie = response.cookies['example']
+        self.assertIn('; %s' % cookies.Morsel._reserved['httponly'], str(example_cookie))
+        self.assertIs(example_cookie['httponly'], True)
+
+    def test_unicode_cookie(self):
+        """HttpResponse.set_cookie() works with Unicode data."""
+        response = HttpResponse()
+        cookie_value = '清風'
+        response.set_cookie('test', cookie_value)
+        self.assertEqual(response.cookies['test'].value, cookie_value)
+
+    def test_samesite(self):
+        response = HttpResponse()
+        response.set_cookie('example', samesite='None')
+        self.assertEqual(response.cookies['example']['samesite'], 'None')
+        response.set_cookie('example', samesite='Lax')
+        self.assertEqual(response.cookies['example']['samesite'], 'Lax')
+        response.set_cookie('example', samesite='strict')
+        self.assertEqual(response.cookies['example']['samesite'], 'strict')
+
+    def test_invalid_samesite(self):
+        msg = 'samesite must be "lax", "none", or "strict".'
+        with self.assertRaisesMessage(ValueError, msg):
+            HttpResponse().set_cookie('example', samesite='invalid')
+
+
+class DeleteCookieTests(SimpleTestCase):
+
+    def test_default(self):
+        response = HttpResponse()
+        response.delete_cookie('c')
+        cookie = response.cookies['c']
+        self.assertEqual(cookie['expires'], 'Thu, 01 Jan 1970 00:00:00 GMT')
+        self.assertEqual(cookie['max-age'], 0)
+        self.assertEqual(cookie['path'], '/')
+        self.assertEqual(cookie['secure'], '')
+        self.assertEqual(cookie['domain'], '')
+
+    def test_delete_cookie_secure_prefix(self):
+        """
+        delete_cookie() sets the secure flag if the cookie name starts with
+        __Host- or __Secure- (without that, browsers ignore cookies with those
+        prefixes).
+        """
+        response = HttpResponse()
+        for prefix in ('Secure', 'Host'):
+            with self.subTest(prefix=prefix):
+                cookie_name = '__%s-c' % prefix
+                response.delete_cookie(cookie_name)
+                self.assertIs(response.cookies[cookie_name]['secure'], True)
+
+    def test_delete_cookie_samesite(self):
+        """
+        delete_cookie() can set the SameSite attribute.
+        """
+        response = HttpResponse()
+        response.delete_cookie('c', samesite='Lax')
+        cookie = response.cookies['c']
+        self.assertEqual(cookie['samesite'], 'Lax')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/http/response\.py|django/contrib/sessions/middleware\.py|django/contrib/messages/storage/cookie\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_http_response_cookies
cat coverage.cover
git checkout 156a2138db20abc89933121e4ff2ee2ce56a173a
git apply /root/pre_state.patch
