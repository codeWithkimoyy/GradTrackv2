import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against the RuntimeReload "NOT NORMALIZED" crash caused by
/// DataTable( dataRowMinHeight: 52 ) with the default dataRowMaxHeight of 48.
/// The merchant-verified layout (nested vertical + horizontal scroll with
/// icon-button action cells) only hits the failing intrinsic-layout path when
/// the table is given unbounded width, so this test reproduces that exact
/// structure.
void main() {
  testWidgets('alumni registry DataTable renders without constraint errors',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 50,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 72,
                  columns: const [
                    DataColumn(label: Text('Alumni ID')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Course')),
                    DataColumn(label: Text('Graduation Year')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final name in ['Juan Dela Cruz', 'Maria Santos'])
                      DataRow(cells: [
                        const DataCell(Text('BISU-2020-001')),
                        DataCell(Text(name)),
                        const DataCell(Text('BS Computer Science')),
                        const DataCell(Text('2021')),
                        const DataCell(Text('active')),
                        const DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.edit_outlined, size: 18),
                                onPressed: _noop,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.lock_outline, size: 18),
                                onPressed: _noop,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.password_rounded, size: 18),
                                onPressed: _noop,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.delete_outline, size: 18),
                                onPressed: _noop,
                              ),
                            ],
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

void _noop() {}