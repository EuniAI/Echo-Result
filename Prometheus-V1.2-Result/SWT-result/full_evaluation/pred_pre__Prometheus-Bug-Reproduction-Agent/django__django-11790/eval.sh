#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b1d6b35e146aea83b171c1b921178bbaae2795ed >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b1d6b35e146aea83b171c1b921178bbaae2795ed
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_authentication_form.py b/tests/auth_tests/test_authentication_form.py
new file mode 100644
index 0000000000..205c714e8e
--- /dev/null
+++ b/tests/auth_tests/test_authentication_form.py
@@ -0,0 +1,12 @@
+from django.contrib.auth.forms import AuthenticationForm
+from django.test import SimpleTestCase
+
+
+class AuthenticationFormTests(SimpleTestCase):
+    def test_username_maxlength_rendered(self):
+        """
+        The AuthenticationForm's username field should render with a
+        maxlength attribute.
+        """
+        form = AuthenticationForm()
+        self.assertEqual(form.fields['username'].widget.attrs['maxlength'], str(form.fields['username'].max_length))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/forms\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_authentication_form
cat coverage.cover
git checkout b1d6b35e146aea83b171c1b921178bbaae2795ed
git apply /root/pre_state.patch
