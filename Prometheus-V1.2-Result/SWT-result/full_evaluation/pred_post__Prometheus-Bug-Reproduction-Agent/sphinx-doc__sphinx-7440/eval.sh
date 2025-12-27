#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9bb204dcabe6ba0fc422bf4a45ad0c79c680d90b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9bb204dcabe6ba0fc422bf4a45ad0c79c680d90b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/domains/std.py b/sphinx/domains/std.py
--- a/sphinx/domains/std.py
+++ b/sphinx/domains/std.py
@@ -305,7 +305,7 @@ def make_glossary_term(env: "BuildEnvironment", textnodes: Iterable[Node], index
         term['ids'].append(node_id)
 
     std = cast(StandardDomain, env.get_domain('std'))
-    std.note_object('term', termtext.lower(), node_id, location=term)
+    std.note_object('term', termtext, node_id, location=term)
 
     # add an index entry too
     indexnode = addnodes.index()
@@ -565,7 +565,7 @@ class StandardDomain(Domain):
         # links to tokens in grammar productions
         'token':   TokenXRefRole(),
         # links to terms in glossary
-        'term':    XRefRole(lowercase=True, innernodeclass=nodes.inline,
+        'term':    XRefRole(innernodeclass=nodes.inline,
                             warn_dangling=True),
         # links to headings or arbitrary labels
         'ref':     XRefRole(lowercase=True, innernodeclass=nodes.inline,

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_directive_glossary.py b/tests/test_directive_glossary.py
new file mode 100644
index 000000000..cdc53c8d1
--- /dev/null
+++ b/tests/test_directive_glossary.py
@@ -0,0 +1,25 @@
+import pytest
+
+from docutils import nodes
+from docutils.nodes import definition, definition_list, definition_list_item, term
+
+from sphinx import addnodes
+from sphinx.addnodes import glossary, index
+from sphinx.testing import restructuredtext
+from sphinx.testing.util import assert_node
+
+
+def test_glossary_duplicate_term_with_different_case(app, status, warning):
+    """
+    Tests that the glossary directive does not incorrectly report duplicate
+    terms when they differ in case.
+    """
+    text = (".. glossary::\n"
+            "\n"
+            "   mysql\n"
+            "       A relational database management system.\n"
+            "\n"
+            "   MySQL\n"
+            "       A relational database management system.\n")
+    restructuredtext.parse(app, text)
+    assert warning.getvalue() == ""

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/domains/std\.py)' -m tox -epy39 -v -- tests/test_directive_glossary.py
cat coverage.cover
git checkout 9bb204dcabe6ba0fc422bf4a45ad0c79c680d90b
git apply /root/pre_state.patch
