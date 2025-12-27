#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fbe82f82555bc25dccb476c749ca062f0b522be3 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fbe82f82555bc25dccb476c749ca062f0b522be3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/related.py b/django/db/models/fields/related.py
--- a/django/db/models/fields/related.py
+++ b/django/db/models/fields/related.py
@@ -914,7 +914,7 @@ def validate(self, value, model_instance):
             return
 
         using = router.db_for_read(self.remote_field.model, instance=model_instance)
-        qs = self.remote_field.model._default_manager.using(using).filter(
+        qs = self.remote_field.model._base_manager.using(using).filter(
             **{self.remote_field.field_name: value}
         )
         qs = qs.complex_filter(self.get_limit_choices_to())

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_bug.py b/tests/test_bug.py
new file mode 100644
index 0000000000..922e9776cb
--- /dev/null
+++ b/tests/test_bug.py
@@ -0,0 +1 @@
+# Please add the bug reproducing code here
\ No newline at end of file

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/related\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_bug
cat coverage.cover
git checkout fbe82f82555bc25dccb476c749ca062f0b522be3
git apply /root/pre_state.patch
