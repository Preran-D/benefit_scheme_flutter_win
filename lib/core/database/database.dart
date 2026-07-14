import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@DataClassName('CustomerEntity')
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
}

@DataClassName('SchemeEntity')
class Schemes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  RealColumn get monthlyAmount => real()();
  RealColumn get totalPaid => real().withDefault(const Constant(0.0))();
  TextColumn get lastPaymentDate => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get notes => text().nullable()();
  TextColumn get closedDate => text().nullable()();
  TextColumn get createdAt => text().nullable()();
}

@DataClassName('PaymentEntity')
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get schemeId => integer().references(Schemes, #id)();
  TextColumn get paymentDate => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get paymentModes => text()(); // Store as JSON array string
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();
}

@DriftDatabase(tables: [Customers, Schemes, Payments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'benefit_scheme.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
