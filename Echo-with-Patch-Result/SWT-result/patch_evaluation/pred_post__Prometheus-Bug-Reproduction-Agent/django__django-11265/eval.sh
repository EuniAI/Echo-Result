#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 21aa2a5e785eef1f47beb1c3760fdd7d8915ae09 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 21aa2a5e785eef1f47beb1c3760fdd7d8915ae09
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/query.py b/django/db/models/sql/query.py
--- a/django/db/models/sql/query.py
+++ b/django/db/models/sql/query.py
@@ -1666,6 +1666,7 @@ def split_exclude(self, filter_expr, can_reuse, names_with_path):
             filter_expr = (filter_lhs, OuterRef(filter_rhs.name))
         # Generate the inner query.
         query = Query(self.model)
+        query._filtered_relations = self._filtered_relations
         query.add_filter(filter_expr)
         query.clear_ordering(True)
         # Try to have as simple as possible subquery -> trim leading joins from
@@ -2140,9 +2141,13 @@ def trim_start(self, names_with_path):
             join_field.foreign_related_fields[0].name)
         trimmed_prefix = LOOKUP_SEP.join(trimmed_prefix)
         # Lets still see if we can trim the first join from the inner query
-        # (that is, self). We can't do this for LEFT JOINs because we would
-        # miss those rows that have nothing on the outer side.
-        if self.alias_map[lookup_tables[trimmed_paths + 1]].join_type != LOUTER:
+        # (that is, self). We can't do this for:
+        # - LEFT JOINs because we would miss those rows that have nothing on
+        #   the outer side,
+        # - INNER JOINs from filtered relations because we would miss their
+        #   filters.
+        first_join = self.alias_map[lookup_tables[trimmed_paths + 1]]
+        if first_join.join_type != LOUTER and not first_join.filtered_relation:
             select_fields = [r[0] for r in join_field.related_fields]
             select_alias = lookup_tables[trimmed_paths + 1]
             self.unref_alias(lookup_tables[trimmed_paths])

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/filtered_relation/tests.py b/filtered_relation/tests.py
new file mode 100644
index 0000000000..f363bfee6a
--- /dev/null
+++ b/filtered_relation/tests.py
@@ -0,0 +1,322 @@
+from django.db import connection, transaction
+from django.db.models import Case, Count, F, FilteredRelation, Q, When
+from django.test import TestCase
+from django.test.testcases import skipUnlessDBFeature
+
+from .models import Author, Book, Borrower, Editor, RentalSession, Reservation
+
+
+class FilteredRelationTests(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.author1 = Author.objects.create(name='Alice')
+        cls.author2 = Author.objects.create(name='Jane')
+        cls.editor_a = Editor.objects.create(name='a')
+        cls.editor_b = Editor.objects.create(name='b')
+        cls.book1 = Book.objects.create(
+            title='Poem by Alice',
+            editor=cls.editor_a,
+            author=cls.author1,
+        )
+        cls.book1.generic_author.set([cls.author2])
+        cls.book2 = Book.objects.create(
+            title='The book by Jane A',
+            editor=cls.editor_b,
+            author=cls.author2,
+        )
+        cls.book3 = Book.objects.create(
+            title='The book by Jane B',
+            editor=cls.editor_b,
+            author=cls.author2,
+        )
+        cls.book4 = Book.objects.create(
+            title='The book by Alice',
+            editor=cls.editor_a,
+            author=cls.author1,
+        )
+        cls.author1.favorite_books.add(cls.book2)
+        cls.author1.favorite_books.add(cls.book3)
+
+    def test_exclude_on_filtered_relation_annotation(self):
+        qs = Author.objects.annotate(
+            book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+        ).exclude(book_alice__isnull=False)
+        self.assertSequenceEqual(qs, [self.author2])
+
+    def test_select_related(self):
+        qs = Author.objects.annotate(
+            book_join=FilteredRelation('book'),
+        ).select_related('book_join__editor').order_by('pk', 'book_join__pk')
+        with self.assertNumQueries(1):
+            self.assertQuerysetEqual(qs, [
+                (self.author1, self.book1, self.editor_a, self.author1),
+                (self.author1, self.book4, self.editor_a, self.author1),
+                (self.author2, self.book2, self.editor_b, self.author2),
+                (self.author2, self.book3, self.editor_b, self.author2),
+            ], lambda x: (x, x.book_join, x.book_join.editor, x.book_join.author))
+
+    def test_select_related_with_empty_relation(self):
+        qs = Author.objects.annotate(
+            book_join=FilteredRelation('book', condition=Q(pk=-1)),
+        ).select_related('book_join').order_by('pk')
+        self.assertSequenceEqual(qs, [self.author1, self.author2])
+
+    def test_select_related_foreign_key(self):
+        qs = Book.objects.annotate(
+            author_join=FilteredRelation('author'),
+        ).select_related('author_join').order_by('pk')
+        with self.assertNumQueries(1):
+            self.assertQuerysetEqual(qs, [
+                (self.book1, self.author1),
+                (self.book2, self.author2),
+                (self.book3, self.author2),
+                (self.book4, self.author1),
+            ], lambda x: (x, x.author_join))
+
+    @skipUnlessDBFeature('has_select_for_update', 'has_select_for_update_of')
+    def test_select_related_foreign_key_for_update_of(self):
+        with transaction.atomic():
+            qs = Book.objects.annotate(
+                author_join=FilteredRelation('author'),
+            ).select_related('author_join').select_for_update(of=('self',)).order_by('pk')
+            with self.assertNumQueries(1):
+                self.assertQuerysetEqual(qs, [
+                    (self.book1, self.author1),
+                    (self.book2, self.author2),
+                    (self.book3, self.author2),
+                    (self.book4, self.author1),
+                ], lambda x: (x, x.author_join))
+
+    def test_without_join(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+            ),
+            [self.author1, self.author2]
+        )
+
+    def test_with_join(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+            ).filter(book_alice__isnull=False),
+            [self.author1]
+        )
+
+    def test_with_join_and_complex_condition(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_alice=FilteredRelation(
+                    'book', condition=Q(
+                        Q(book__title__iexact='poem by alice') |
+                        Q(book__state=Book.RENTED)
+                    ),
+                ),
+            ).filter(book_alice__isnull=False),
+            [self.author1]
+        )
+
+    def test_internal_queryset_alias_mapping(self):
+        queryset = Author.objects.annotate(
+            book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+        ).filter(book_alice__isnull=False)
+        self.assertIn(
+            'INNER JOIN {} book_alice ON'.format(connection.ops.quote_name('filtered_relation_book')),
+            str(queryset.query)
+        )
+
+    def test_with_multiple_filter(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_editor_a=FilteredRelation(
+                    'book',
+                    condition=Q(book__title__icontains='book', book__editor_id=self.editor_a.pk),
+                ),
+            ).filter(book_editor_a__isnull=False),
+            [self.author1]
+        )
+
+    def test_multiple_times(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_title_alice=FilteredRelation('book', condition=Q(book__title__icontains='alice')),
+            ).filter(book_title_alice__isnull=False).filter(book_title_alice__isnull=False).distinct(),
+            [self.author1]
+        )
+
+    def test_exclude_relation_with_join(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_alice=FilteredRelation('book', condition=~Q(book__title__icontains='alice')),
+            ).filter(book_alice__isnull=False).distinct(),
+            [self.author2]
+        )
+
+    def test_with_m2m(self):
+        qs = Author.objects.annotate(
+            favorite_books_written_by_jane=FilteredRelation(
+                'favorite_books', condition=Q(favorite_books__in=[self.book2]),
+            ),
+        ).filter(favorite_books_written_by_jane__isnull=False)
+        self.assertSequenceEqual(qs, [self.author1])
+
+    def test_with_m2m_deep(self):
+        qs = Author.objects.annotate(
+            favorite_books_written_by_jane=FilteredRelation(
+                'favorite_books', condition=Q(favorite_books__author=self.author2),
+            ),
+        ).filter(favorite_books_written_by_jane__title='The book by Jane B')
+        self.assertSequenceEqual(qs, [self.author1])
+
+    def test_with_m2m_multijoin(self):
+        qs = Author.objects.annotate(
+            favorite_books_written_by_jane=FilteredRelation(
+                'favorite_books', condition=Q(favorite_books__author=self.author2),
+            )
+        ).filter(favorite_books_written_by_jane__editor__name='b').distinct()
+        self.assertSequenceEqual(qs, [self.author1])
+
+    def test_values_list(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+            ).filter(book_alice__isnull=False).values_list('book_alice__title', flat=True),
+            ['Poem by Alice']
+        )
+
+    def test_values(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+            ).filter(book_alice__isnull=False).values(),
+            [{'id': self.author1.pk, 'name': 'Alice', 'content_type_id': None, 'object_id': None}]
+        )
+
+    def test_extra(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+            ).filter(book_alice__isnull=False).extra(where=['1 = 1']),
+            [self.author1]
+        )
+
+    @skipUnlessDBFeature('supports_select_union')
+    def test_union(self):
+        qs1 = Author.objects.annotate(
+            book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+        ).filter(book_alice__isnull=False)
+        qs2 = Author.objects.annotate(
+            book_jane=FilteredRelation('book', condition=Q(book__title__iexact='the book by jane a')),
+        ).filter(book_jane__isnull=False)
+        self.assertSequenceEqual(qs1.union(qs2), [self.author1, self.author2])
+
+    @skipUnlessDBFeature('supports_select_intersection')
+    def test_intersection(self):
+        qs1 = Author.objects.annotate(
+            book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+        ).filter(book_alice__isnull=False)
+        qs2 = Author.objects.annotate(
+            book_jane=FilteredRelation('book', condition=Q(book__title__iexact='the book by jane a')),
+        ).filter(book_jane__isnull=False)
+        self.assertSequenceEqual(qs1.intersection(qs2), [])
+
+    @skipUnlessDBFeature('supports_select_difference')
+    def test_difference(self):
+        qs1 = Author.objects.annotate(
+            book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+        ).filter(book_alice__isnull=False)
+        qs2 = Author.objects.annotate(
+            book_jane=FilteredRelation('book', condition=Q(book__title__iexact='the book by jane a')),
+        ).filter(book_jane__isnull=False)
+        self.assertSequenceEqual(qs1.difference(qs2), [self.author1])
+
+    def test_select_for_update(self):
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_jane=FilteredRelation('book', condition=Q(book__title__iexact='the book by jane a')),
+            ).filter(book_jane__isnull=False).select_for_update(),
+            [self.author2]
+        )
+
+    def test_defer(self):
+        # One query for the list and one query for the deferred title.
+        with self.assertNumQueries(2):
+            self.assertQuerysetEqual(
+                Author.objects.annotate(
+                    book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+                ).filter(book_alice__isnull=False).select_related('book_alice').defer('book_alice__title'),
+                ['Poem by Alice'], lambda author: author.book_alice.title
+            )
+
+    def test_only_not_supported(self):
+        msg = 'only() is not supported with FilteredRelation.'
+        with self.assertRaisesMessage(ValueError, msg):
+            Author.objects.annotate(
+                book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+            ).filter(book_alice__isnull=False).select_related('book_alice').only('book_alice__state')
+
+    def test_as_subquery(self):
+        inner_qs = Author.objects.annotate(
+            book_alice=FilteredRelation('book', condition=Q(book__title__iexact='poem by alice')),
+        ).filter(book_alice__isnull=False)
+        qs = Author.objects.filter(id__in=inner_qs)
+        self.assertSequenceEqual(qs, [self.author1])
+
+    def test_with_foreign_key_error(self):
+        msg = (
+            "FilteredRelation's condition doesn't support nested relations "
+            "(got 'author__favorite_books__author')."
+        )
+        with self.assertRaisesMessage(ValueError, msg):
+            list(Book.objects.annotate(
+                alice_favorite_books=FilteredRelation(
+                    'author__favorite_books',
+                    condition=Q(author__favorite_books__author=self.author1),
+                )
+            ))
+
+    def test_with_foreign_key_on_condition_error(self):
+        msg = (
+            "FilteredRelation's condition doesn't support nested relations "
+            "(got 'book__editor__name__icontains')."
+        )
+        with self.assertRaisesMessage(ValueError, msg):
+            list(Author.objects.annotate(
+                book_edited_by_b=FilteredRelation('book', condition=Q(book__editor__name__icontains='b')),
+            ))
+
+    def test_with_empty_relation_name_error(self):
+        with self.assertRaisesMessage(ValueError, 'relation_name cannot be empty.'):
+            FilteredRelation('', condition=Q(blank=''))
+
+    def test_with_condition_as_expression_error(self):
+        msg = 'condition argument must be a Q() instance.'
+        expression = Case(
+            When(book__title__iexact='poem by alice', then=True), default=False,
+        )
+        with self.assertRaisesMessage(ValueError, msg):
+            FilteredRelation('book', condition=expression)
+
+    def test_with_prefetch_related(self):
+        msg = 'prefetch_related() is not supported with FilteredRelation.'
+        qs = Author.objects.annotate(
+            book_title_contains_b=FilteredRelation('book', condition=Q(book__title__icontains='b')),
+        ).filter(
+            book_title_contains_b__isnull=False,
+        )
+        with self.assertRaisesMessage(ValueError, msg):
+            qs.prefetch_related('book_title_contains_b')
+        with self.assertRaisesMessage(ValueError, msg):
+            qs.prefetch_related('book_title_contains_b__editor')
+
+    def test_with_generic_foreign_key(self):
+        self.assertSequenceEqual(
+            Book.objects.annotate(
+                generic_authored_book=FilteredRelation(
+                    'generic_author',
+                    condition=Q(generic_author__isnull=False)
+                ),
+            ).filter(generic_authored_book__isnull=False),
+            [self.book1]
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 filtered_relation.tests
cat coverage.cover
git checkout 21aa2a5e785eef1f47beb1c3760fdd7d8915ae09
git apply /root/pre_state.patch
