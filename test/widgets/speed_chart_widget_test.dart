import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/speed_chart_settings_service.dart';
import 'package:hanabi_download_managerx/widgets/speed_chart_widget.dart';

void main() {
  test('normalizes invalid chart colors to blue', () {
    expect(SpeedChartSettingsService.normalizeColor('pink'), 'pink');
    expect(SpeedChartSettingsService.normalizeColor(' PINK '), 'pink');
    expect(SpeedChartSettingsService.normalizeColor('unknown'), 'blue');
    expect(SpeedChartColors.fromName('pink'), const Color(0xFFEC4899));
  });

  testWidgets('renders a chart from current speed before history exists',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 80,
          child: SpeedChartWidget(
            taskId: 'speed-chart-widget-test-current-speed',
            currentSpeed: 1024,
            colorName: 'pink',
          ),
        ),
      ),
    );

    expect(find.byType(SpeedChartWidget), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    expect(find.byType(SizedBox), findsWidgets);
  });
}
