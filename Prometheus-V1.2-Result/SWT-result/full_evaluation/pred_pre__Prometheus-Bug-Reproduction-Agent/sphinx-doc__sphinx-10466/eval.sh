#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD cab2d93076d0cca7c53fac885f927dde3e2a5fec >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff cab2d93076d0cca7c53fac885f927dde3e2a5fec
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_build_gettext_catalog.py b/tests/test_build_gettext_catalog.py
new file mode 100644
index 000000000..9ff37c8b6
--- /dev/null
+++ b/tests/test_build_gettext_catalog.py
@@ -0,0 +1,31 @@
+import pytest
+from unittest.mock import Mock
+
+from sphinx.builders.gettext import Catalog
+
+
+def test_message_locations_are_deduplicated():
+    """Test that duplicate locations in a message are removed."""
+    catalog = Catalog()
+    msgid = "Type"
+
+    # Simulate multiple origins pointing to the same file and line,
+    # as described in the bug report.
+    locations = [
+        ('../../manual/render/shader_nodes/vector/vector_rotate.rst', 38),
+        ('../../manual/modeling/hair.rst', 0),
+        ('../../manual/modeling/hair.rst', 0),
+        ('../../manual/modeling/hair.rst', 0),
+        ('../../manual/modeling/metas/properties.rst', 92),
+    ]
+
+    for i, (source, line) in enumerate(locations):
+        origin = Mock(source=source, line=line, uid=f'uid{i}')
+        catalog.add(msgid, origin)
+
+    messages = list(catalog)
+    message = messages[0]
+
+    # Before fix, message.locations has 5 items because of duplicates.
+    # After fix, it should have 3 unique items.
+    assert len(message.locations) == 3

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/builders/gettext\.py)' -m tox -epy39 -v -- tests/test_build_gettext_catalog.py
cat coverage.cover
git checkout cab2d93076d0cca7c53fac885f927dde3e2a5fec
git apply /root/pre_state.patch
