import 'package:hive/hive.dart';

part 'order_status.g.dart';

@HiveType(typeId: 2)
enum OrderStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  ready,

  @HiveField(2)
  done,
}

