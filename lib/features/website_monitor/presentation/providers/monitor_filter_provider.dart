import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MonitorFilter { all, up, down }

final monitorFilterProvider = NotifierProvider<MonitorFilterNotifier, MonitorFilter>(MonitorFilterNotifier.new);

class MonitorFilterNotifier extends Notifier<MonitorFilter> {
  @override
  MonitorFilter build() => MonitorFilter.all;

  void set(MonitorFilter filter) => state = filter;
}
