#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9a6e2df3a8f01ea761529bec48e5a8dc0ea9575b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9a6e2df3a8f01ea761529bec48e5a8dc0ea9575b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/messages_tests/test_tags.py b/tests/messages_tests/test_tags.py
new file mode 100644
index 0000000000..0e8b970c91
--- /dev/null
+++ b/tests/messages_tests/test_tags.py
@@ -0,0 +1,17 @@
+from django.contrib.messages import constants
+from django.contrib.messages.storage.base import Message
+from django.test import SimpleTestCase, override_settings
+
+
+class MessageTagTests(SimpleTestCase):
+    @override_settings(MESSAGE_TAGS={
+        constants.INFO: 'info',
+        49: 'custom',
+    })
+    def test_custom_level_tag(self):
+        """
+        A message's level_tag is derived from MESSAGE_TAGS in settings. This
+        should be updated when using override_settings.
+        """
+        message = Message(49, 'A custom message.')
+        self.assertEqual(message.level_tag, 'custom')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/messages/apps\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 messages_tests.test_tags
cat coverage.cover
git checkout 9a6e2df3a8f01ea761529bec48e5a8dc0ea9575b
git apply /root/pre_state.patch
