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
diff --git a/tests/mail/test_unicode.py b/tests/mail/test_unicode.py
new file mode 100644
index 0000000000..ea00e14c3b
--- /dev/null
+++ b/tests/mail/test_unicode.py
@@ -0,0 +1,23 @@
+from unittest.mock import patch
+
+from django.core.mail import EmailMessage
+from django.test import SimpleTestCase
+
+
+class MailUnicodeHostnameTests(SimpleTestCase):
+    def test_unicode_hostname_message_id(self):
+        """
+        A non-ASCII hostname doesn't crash email sending with a non-UTF-8
+        encoding.
+        """
+        # The hostname "正宗" from the issue description is used here.
+        with patch("django.core.mail.message.DNS_NAME", "正宗"):
+            email = EmailMessage(
+                'subject', '', 'from@example.com', ['to@example.com']
+            )
+            email.encoding = 'iso-8859-1'
+            # Before the fix, this line raises UnicodeEncodeError.
+            message = email.message()
+            # After the fix, the hostname should be punycode-encoded.
+            # "正宗" in punycode is "xn--p8s937b".
+            self.assertIn('xn--p8s937b', message['Message-ID'])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/validators\.py|django/core/mail/utils\.py|django/utils/html\.py|django/core/mail/message\.py|django/utils/encoding\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 mail.test_unicode
cat coverage.cover
git checkout a5308514fb4bc5086c9a16a8a24a945eeebb073c
git apply /root/pre_state.patch
