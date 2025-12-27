#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d746f28949c009251a8741ba03d156964050717f >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d746f28949c009251a8741ba03d156964050717f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_readonlypasswordhashfield.py b/tests/auth_tests/test_readonlypasswordhashfield.py
new file mode 100644
index 0000000000..858961d653
--- /dev/null
+++ b/tests/auth_tests/test_readonlypasswordhashfield.py
@@ -0,0 +1,32 @@
+from django.contrib.auth import get_user_model
+from django.contrib.auth.forms import ReadOnlyPasswordHashField
+from django.forms import ModelForm
+from django.test import TestCase
+
+User = get_user_model()
+
+
+class ReadOnlyPasswordHashFieldDisablesTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.user = User.objects.create_user("test_user", password="password")
+
+    def test_readonlypasswordhashfield_disabled(self):
+        """
+        ReadOnlyPasswordHashField should be disabled by default to prevent
+        password tampering.
+        """
+
+        class CustomUserChangeForm(ModelForm):
+            password = ReadOnlyPasswordHashField()
+
+            class Meta:
+                model = User
+                fields = ("username", "password")
+
+        form = CustomUserChangeForm(instance=self.user)
+        initial_password = form.initial["password"]
+        post_data = {"username": "test_user", "password": "new-password"}
+        form = CustomUserChangeForm(post_data, instance=self.user)
+        self.assertTrue(form.is_valid())
+        self.assertEqual(form.cleaned_data["password"], initial_password)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/forms\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_readonlypasswordhashfield
cat coverage.cover
git checkout d746f28949c009251a8741ba03d156964050717f
git apply /root/pre_state.patch
