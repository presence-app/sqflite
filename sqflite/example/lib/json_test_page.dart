import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
// ignore: implementation_imports
import 'package:sqflite/utils/utils.dart';
import 'package:sqflite_example/src/item_widget.dart';
import 'package:sqflite_example/utils.dart';

// ignore_for_file: avoid_print

import 'database/database.dart';
import 'model/item.dart';

/// Json test page.
class JsonTestPage extends StatefulWidget {
  /// Test page.
  const JsonTestPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _JsonTestPageState createState() => _JsonTestPageState();
}

class _JsonTestPageState extends State<JsonTestPage> {
  Database? database;
  static const String dbName = 'json_test.db';

  late List<SqfMenuItem> items;
  late List<ItemWidget> itemWidgets;

  Future<bool> pop() async {
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    items = <SqfMenuItem>[
      SqfMenuItem('SQLite version', () async {
        final db = await openDatabase(inMemoryDatabasePath);
        final results = await db.rawQuery('select sqlite_version()');
        print('select sqlite_version(): $results');
        var version = results.first.values.first;
        print('sqlite version: $version');
        await db.close();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('select sqlite_version(): $version')));
        }
      }, summary: 'select sqlite_version()'),
      //json_extract
      SqfMenuItem('json_extract', () async {
        final path = await initDeleteDb(dbName);
        final db = await openDatabase(path, version: 1,
            onCreate: (Database db, int version) async {
          await db.execute(
              'CREATE TABLE Test (id INTEGER PRIMARY KEY, value BLOB, json TEXT)');
        });
        //insert
        await db.transaction((txn) async {
          await txn.rawInsert('INSERT INTO Test(json) VALUES( ?)', [
            jsonEncode(<String, dynamic>{
              'id': 1,
              'name': 'foo',
              'age': 41,
            }),
          ]);
        });
        await db.transaction((txn) async {
          await txn.rawInsert('INSERT INTO Test(json) VALUES( ?)', [
            jsonEncode(<String, dynamic>{
              'id': 2,
              'name': 'bar',
              'age': 42,
            })
          ]);
        });

        final results = await db.rawQuery(
            "select json_extract(json, '\$.name') as name, json_extract(json, '\$.age') as age from Test");
        print('select json_extract(): $results');
        await db.close();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('select json_extract(): $results')));
        }
      }, summary: 'select json_extract()'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    itemWidgets = items
        .map((item) => ItemWidget(
              item,
              (item) async {
                final stopwatch = Stopwatch()..start();
                final future = (item as SqfMenuItem).run();
                setState(() {});
                await future;
                // always add a small delay
                final elapsed = stopwatch.elapsedMilliseconds;
                if (elapsed < 300) {
                  await sleep(300 - elapsed);
                }
                setState(() {});
              },
              summary: item.summary,
            ))
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Json tests'),
      ),
      body: WillPopScope(
        onWillPop: pop,
        child: ListView(
          children: itemWidgets,
        ),
      ),
    );
  }
}

/// Multiple db test page.
class MultipleDbTestPage extends StatelessWidget {
  /// Test page.
  const MultipleDbTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget dbTile(String name) {
      return ListTile(
        title: Text(name),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) {
            return SimpleDbTestPage(
              dbName: name,
            );
          }));
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiple databases'),
      ),
      body: ListView(
        children: <Widget>[
          dbTile('data1.db'),
          dbTile('data2.db'),
          dbTile('data3.db')
        ],
      ),
    );
  }
}

/// Simple db test page.
class SimpleDbTestPage extends StatefulWidget {
  /// Simple db test page.
  const SimpleDbTestPage({Key? key, required this.dbName}) : super(key: key);

  /// db name.
  final String dbName;

  @override
  // ignore: library_private_types_in_public_api
  _SimpleDbTestPageState createState() => _SimpleDbTestPageState();
}

class _SimpleDbTestPageState extends State<SimpleDbTestPage> {
  Database? database;

  Future<Database> _openDatabase() async {
    // await Sqflite.devSetOptions(SqfliteOptions(logLevel: sqfliteLogLevelVerbose));
    return database ??= await databaseFactory.openDatabase(widget.dbName,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('CREATE TABLE Test (value TEXT)');
            }));
  }

  Future _closeDatabase() async {
    await database?.close();
    database = null;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Simple db ${widget.dbName}'),
        ),
        body: Builder(
          builder: (context) {
            Widget menuItem(String title, void Function() onTap,
                {String? summary}) {
              return ListTile(
                title: Text(title),
                subtitle: summary == null ? null : Text(summary),
                onTap: onTap,
              );
            }

            Future countRecord() async {
              final db = await _openDatabase();
              final result =
                  firstIntValue(await db.query('test', columns: ['COUNT(*)']));
              // Temp for nnbd successfull lint
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$result records'),
                  duration: const Duration(milliseconds: 700),
                ));
              }
            }

            final items = <Widget>[
              menuItem('open Database', () async {
                await _openDatabase();
              }, summary: 'Open the database'),
              menuItem('Add record', () async {
                final db = await _openDatabase();
                await db.insert('test', {'value': 'some_value'});
                await countRecord();
              }, summary: 'Add one record. Open the database if needed'),
              menuItem('Count record', () async {
                await countRecord();
              }, summary: 'Count records. Open the database if needed'),
              menuItem(
                'Close Database',
                () async {
                  await _closeDatabase();
                },
              ),
              menuItem(
                'Delete database',
                () async {
                  await databaseFactory.deleteDatabase(widget.dbName);
                },
              ),
            ];
            return ListView(
              children: items,
            );
          },
        ));
  }
}
