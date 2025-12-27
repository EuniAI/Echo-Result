#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a5308514fb4bc5086c9a16a8a24a945eeebb073c >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a5308514fb4bc5086c9a16a8a24a945eeebb073c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_mail_unicode_domain.py b/tests/test_mail_unicode_domain.py
new file mode 100644
index 0000000000..3eca8b8cdb
--- /dev/null
+++ b/tests/test_mail_unicode_domain.py
@@ -0,0 +1,37 @@
+from django.conf import settings
+
+# The test runner can fail with an ImproperlyConfigured error if settings
+# are not configured before test discovery begins. This explicit configuration
+# ensures the test environment is correctly set up, especially when tests are
+# run in a standalone fashion.
+if not settings.configured:
+    settings.configure(
+        # A dummy SECRET_KEY is required for Django's settings object to be valid.
+        SECRET_KEY='dummy-key-for-testing',
+    )
+
+from unittest.mock import patch
+from django.core.mail import EmailMessage
+from django.test import SimpleTestCase, override_settings
+
+
+# Overriding EMAIL_BACKEND is a clean way to ensure the test uses a specific
+# backend without affecting global configuration.
+@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
+class MailUnicodeDomainTests(SimpleTestCase):
+    def test_unicode_dns_with_non_unicode_encoding(self):
+        """
+        Punycode is used for non-ASCII domain names in Message-ID when the
+        email encoding is not Unicode.
+        """
+        # Patch DNS_NAME to simulate a non-ASCII hostname.
+        with patch('django.core.mail.message.DNS_NAME', '漢字'):
+            email = EmailMessage(
+                'subject', '', 'from@example.com', ['to@example.com']
+            )
+            # Set a non-Unicode encoding to trigger the bug.
+            email.encoding = 'iso-8859-1'
+            # This call fails on unpatched code with a UnicodeEncodeError.
+            message = email.message()
+            # The patched code should use IDNA (punycode) to encode the domain.
+            self.assertIn('xn--p8s937b', message['Message-ID'])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/html\.py|django/core/validators\.py|django/utils/encoding\.py|django/core/mail/utils\.py|django/core/mail/message\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_mail_unicode_domain
cat coverage.cover
git checkout a5308514fb4bc5086c9a16a8a24a945eeebb073c
git apply /root/pre_state.patch
