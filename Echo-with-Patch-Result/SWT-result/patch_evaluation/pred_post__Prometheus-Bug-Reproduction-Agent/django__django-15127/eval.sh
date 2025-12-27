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
diff --git a/django/contrib/messages/apps.py b/django/contrib/messages/apps.py
--- a/django/contrib/messages/apps.py
+++ b/django/contrib/messages/apps.py
@@ -1,7 +1,18 @@
 from django.apps import AppConfig
+from django.contrib.messages.storage import base
+from django.contrib.messages.utils import get_level_tags
+from django.test.signals import setting_changed
 from django.utils.translation import gettext_lazy as _
 
 
+def update_level_tags(setting, **kwargs):
+    if setting == 'MESSAGE_TAGS':
+        base.LEVEL_TAGS = get_level_tags()
+
+
 class MessagesConfig(AppConfig):
     name = 'django.contrib.messages'
     verbose_name = _("Messages")
+
+    def ready(self):
+        setting_changed.connect(update_level_tags)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_message_settings.py b/tests/test_message_settings.py
new file mode 100644
index 0000000000..63498fff08
--- /dev/null
+++ b/tests/test_message_settings.py
@@ -0,0 +1,23 @@
+from unittest.mock import MagicMock
+
+from django.contrib import messages
+from django.contrib.messages.storage.fallback import FallbackStorage
+from django.test import RequestFactory, SimpleTestCase, override_settings
+
+
+class MessageSettingsTests(SimpleTestCase):
+    def test_add_message_override_settings(self):
+        """
+        The level_tag of a message is correctly handled when
+        MESSAGE_TAGS is overridden in tests.
+        """
+        CUSTOM_LEVEL = 60
+        request = RequestFactory().get("/")
+        # The session-based storage requires a session attribute.
+        request.session = MagicMock()
+        request._messages = FallbackStorage(request)
+
+        with override_settings(MESSAGE_TAGS={CUSTOM_LEVEL: "custom"}):
+            messages.add_message(request, CUSTOM_LEVEL, "A custom message.")
+            stored_messages = list(request._messages)
+            self.assertEqual(stored_messages[0].level_tag, "custom")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/messages/apps\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_message_settings
cat coverage.cover
git checkout 9a6e2df3a8f01ea761529bec48e5a8dc0ea9575b
git apply /root/pre_state.patch
