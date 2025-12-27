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
diff --git a/tests/test_readonlypasswordhashfield.py b/tests/test_readonlypasswordhashfield.py
new file mode 100644
index 0000000000..c45312a2aa
--- /dev/null
+++ b/tests/test_readonlypasswordhashfield.py
@@ -0,0 +1,29 @@
+from django import forms
+from django.contrib.auth.forms import ReadOnlyPasswordHashField
+from django.contrib.auth.models import User
+from django.test import TestCase
+
+
+class ReadOnlyPasswordHashFieldFormTest(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.user = User.objects.create_user(username='testuser', password='password')
+
+    def test_password_is_not_changeable(self):
+        """
+        ReadOnlyPasswordHashField should ignore posted data because it should
+        be disabled by default.
+        """
+        class CustomUserChangeForm(forms.Form):
+            password = ReadOnlyPasswordHashField()
+
+        # The submitted data for 'password' should be ignored.
+        post_data = {'password': 'new-hacked-password'}
+        form = CustomUserChangeForm(data=post_data, initial={'password': self.user.password})
+
+        self.assertTrue(form.is_valid())
+        # Before the fix, cleaned_data contains the posted data.
+        # After the fix, it contains the initial data because the field is
+        # disabled by default.
+        self.assertEqual(form.cleaned_data['password'], self.user.password)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/forms\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_readonlypasswordhashfield
cat coverage.cover
git checkout d746f28949c009251a8741ba03d156964050717f
git apply /root/pre_state.patch
