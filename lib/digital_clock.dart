// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:digital_clock/data_provider.dart';

class DigitalClock extends StatelessWidget {
  const DigitalClock(this.model);

  final ClockModel model;

  @override
  Widget build(BuildContext context) {
    return Theme(
      child: SciFiClock(model),
      data: ThemeData(
        primaryColor: Colors.black,
        backgroundColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
      ),
    );
  }
}

class SciFiClock extends StatefulWidget {
  const SciFiClock(this.model);

  final ClockModel model;

  @override
  _SciFiClockState createState() => _SciFiClockState();
}

class _SciFiClockState extends State<SciFiClock> {
  DateTime _dateTime = DateTime.now();
  Timer _timer;

  // A grid of bools for each digit 0-9 representing which pixel should be 'on'
  // to form that digit.
  List<List<List<bool>>> digitModels;

  // The colors currently being displayed on the pixels on the screen.
  List<List<ValueNotifier<Color>>> pixelColors;

  // The colors currently being displayed in the spaces between the pixels in
  // the screen.
  List<List<ValueNotifier<Color>>> paddingColors;

  // Whether the assets have been loaded and parsed into the models.
  bool loaded = false;

  // How many pixels to display across the width of the screen.
  static const pixelsWide = 50;

  // The ratio of the width to height of the screen.
  static const heightRatio = 5 / 3;

  // The width in pixels of the divider between the hours and minutes.
  static const dividerPixelsWide = 10;

  // The padding between digits.
  final digitPadding = 1;

  // The padding above and below the digits of the clock.
  final verticalPadding = 2;

  // The padding to the left and right of the clock.
  final horizontalPadding = 2;

  // How long the wave takes to get across the screen.
  static const sineWaveDurationSeconds = 6;

  // How many pixels wide is the flare wave.
  static const waveWidth = 2;

  ValueNotifier<int> hour;
  ValueNotifier<int> minute;

  static const onColor = Colors.white;
  static const offColor = Colors.black;
  static const waveColor = Colors.blue;

  int firstDigit = 0;
  int secondDigit = 0;
  int thirdDigit = 0;
  int fourthDigit = 0;

  // When the wave effect started, in milliseconds since epoch.
  int firstDigitWaveStartMs = 0;
  int secondDigitWaveStartMs = 0;
  int thirdDigitWaveStartMs = 0;
  int fourthDigitWaveStartMs = 0;

  @override
  void initState() {
    super.initState();
    setImages();

    hour = ValueNotifier<int>(0);
    minute = ValueNotifier<int>(0);

    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();
  }

  // The width in pixels of every digit in the clock.
  int _digitPixelsWide() {
    return ((pixelsWide -
                dividerPixelsWide -
                digitPadding * 2 -
                horizontalPadding * 2) /
            4)
        .floor();
  }

  // The height in pixels of every digit in the clock.
  int _digitPixelsHigh() {
    final pixelsHigh = (pixelsWide / heightRatio).floor();
    return pixelsHigh - digitPadding * 2 - verticalPadding * 2;
  }

  // Load digit models from assets and format them into the correct shape for
  // screen.
  Future<void> setImages() async {
    final digitPixelsWide = _digitPixelsWide();
    final digitPixelsHigh = _digitPixelsHigh();
    digitModels = List<List<List<bool>>>(10);
    pixelColors = List<List<ValueNotifier<Color>>>();
    paddingColors = List<List<ValueNotifier<Color>>>();
    for (int i = 0; i < 10; i++) {
      final pixels = await getImagePixels(i, digitPixelsHigh, digitPixelsWide);
      digitModels[i] = pixels;
    }

    final pixelsHigh = (pixelsWide / heightRatio).floor();
    for (int i = 0; i < pixelsWide; i++) {
      pixelColors.add(List<ValueNotifier<Color>>());
      paddingColors.add(List<ValueNotifier<Color>>());
      for (int j = 0; j < pixelsHigh; j++) {
        pixelColors[i].add(ValueNotifier<Color>(offColor));
        paddingColors[i].add(ValueNotifier<Color>(offColor));
      }
    }
    _writeDivider();
    setState(() {
      loaded = true;
    });
  }

  @override
  void didUpdateWidget(SciFiClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    widget.model.dispose();
    super.dispose();
  }

  void _updateModel() {
    setState(() {});
  }

  void _updateTime() {
    _dateTime = DateTime.now();

    // Update every 100 milliseconds to keep up to date values for the sine wave
    // and flare wave.
    _timer = Timer(
      Duration(milliseconds: 100) -
          Duration(microseconds: _dateTime.microsecond),
      _updateTime,
    );

    hour.value =
        widget.model.is24HourFormat ? _dateTime.hour : _dateTime.hour % 12;
    minute.value = _dateTime.minute;
    final int nextFirstDigit = (hour.value / 10).floor();
    final int nextSecondDigit = hour.value % 10;
    final int nextThirdDigit = (minute.value / 10).floor();
    final int nextFourthDigit = minute.value % 10;

    if (loaded) {
      _writeSineWave(_dateTime.second, _dateTime.millisecond);

      _updateDigits(
          nextFirstDigit, nextSecondDigit, nextThirdDigit, nextFourthDigit);

      _writeTime(firstDigit, secondDigit, thirdDigit, fourthDigit);
    }
  }

  void _updateDigits(int nextFirstDigit, int nextSecondDigit,
      int nextThirdDigit, int nextFourthDigit) {
    final digitPixelsWide = _digitPixelsWide();
    final msSinceEpoch = _dateTime.millisecondsSinceEpoch;

    if (firstDigit != nextFirstDigit) {
      firstDigit = nextFirstDigit;
      firstDigitWaveStartMs = msSinceEpoch;
    }
    _writeFlareWave(digitPixelsWide * 0.5 + horizontalPadding, msSinceEpoch,
        firstDigitWaveStartMs);

    if (secondDigit != nextSecondDigit) {
      secondDigit = nextSecondDigit;
      secondDigitWaveStartMs = msSinceEpoch;
    }
    _writeFlareWave(digitPixelsWide * 1.5 + horizontalPadding, msSinceEpoch,
        secondDigitWaveStartMs);

    if (thirdDigit != nextThirdDigit) {
      thirdDigit = nextThirdDigit;
      thirdDigitWaveStartMs = msSinceEpoch;
    }
    _writeFlareWave(
        digitPixelsWide * 2.5 + dividerPixelsWide + horizontalPadding,
        msSinceEpoch,
        thirdDigitWaveStartMs);

    if (fourthDigit != nextFourthDigit) {
      fourthDigit = nextFourthDigit;
      fourthDigitWaveStartMs = msSinceEpoch;
    }
    _writeFlareWave(
        digitPixelsWide * 3.5 + dividerPixelsWide + horizontalPadding,
        msSinceEpoch,
        fourthDigitWaveStartMs);
  }

  // Writes a pulsating sine wave across the bottom of the clock.
  _writeSineWave(int second, int millisecond) {
    final pixelsHigh = (pixelsWide / heightRatio).floor();
    for (int i = 0; i < pixelsWide; i++) {
      final msSinceLastUpdate =
          (second % sineWaveDurationSeconds) * 1000 + millisecond;
      final secondProportion =
          (msSinceLastUpdate / sineWaveDurationSeconds / 1000) * pi * 2;
      final xProportion = i / pixelsWide * pi;
      final height =
          (1 + sin(xProportion + secondProportion)) * pixelsHigh * 0.2;
      for (int j = 0; j < pixelsHigh; j++) {
        final val = paddingColors[i][pixelsHigh - j - 1].value;
        if (j < height && val != waveColor) {
          paddingColors[i][pixelsHigh - j - 1].value = waveColor;
        } else if (j >= height && val != offColor) {
          paddingColors[i][pixelsHigh - j - 1].value = offColor;
        }
      }
    }
  }

  // Writes an expanding circle around a changed digit which changes color as
  // it expands.
  void _writeFlareWave(double centerX, curMs, waveStartMs) {
    if (waveStartMs == 0) {
      return;
    }
    final pixelsHigh = (pixelsWide / heightRatio).floor();
    final centerY = pixelsHigh / 2;
    bool shouldStop = true;
    final curTime = (curMs - waveStartMs) / 25;
    for (int i = 0; i < pixelsWide; i++) {
      for (int j = 0; j < pixelsHigh; j++) {
        final distance = sqrt(pow(i - centerX, 2) + pow(j - centerY, 2));
        final on = curTime <= distance + waveWidth / 2 &&
            curTime >= distance - waveWidth / 2;

        if (on) {
          shouldStop = false;
          final red = _getColorFromDistance(distance, 0);
          final green = _getColorFromDistance(distance, 2);
          final blue = _getColorFromDistance(distance, 4);
          paddingColors[i][j].value = Color.fromARGB(255, red, green, blue);
        }
      }
    }
    if (shouldStop) {
      waveStartMs = 0;
    }
  }

  // Gets color for a flare wave that is a distance away from the focus.
  int _getColorFromDistance(double distance, int phase) {
    return (sin(distance / pixelsWide * 4 + phase) * 128 + 128).floor();
  }

  // Writes the time displayed on the clock.
  void _writeTime(
      int firstDigit, int secondDigit, int thirdDigit, int fourthDigit) {
    final pixelWidth =
        ((pixelsWide - dividerPixelsWide - horizontalPadding * 2) / 4).floor();
    _writeDigit(horizontalPadding, firstDigit);
    _writeDigit(pixelWidth + horizontalPadding, secondDigit);
    _writeDigit(
        pixelWidth * 2 + dividerPixelsWide + horizontalPadding, thirdDigit);
    _writeDigit(
        pixelWidth * 3 + dividerPixelsWide + horizontalPadding, fourthDigit);
  }

  // Writes a digit into a position on the clock.
  _writeDigit(int horizontalOffset, int digitValue) {
    final digit = digitModels[digitValue];
    for (int i = 0; i < digit.length; i++) {
      for (int j = 0; j < digit.first.length; j++) {
        final on = digit[i][j];
        final val =
            pixelColors[j + horizontalOffset][i + verticalPadding].value;
        if (on && val != onColor) {
          pixelColors[j + horizontalOffset][i + verticalPadding].value =
              onColor;
        } else if (!on && val != offColor) {
          pixelColors[j + horizontalOffset][i + verticalPadding].value =
              offColor;
        }
      }
    }
  }

  // Writes the divider (:) between the hours and minutes
  void _writeDivider() {
    final height =
        pixelColors.first.length - digitPadding * 2 - verticalPadding * 2;
    final dividerOffset = (1 / 4 * height).floor();
    final dividerDotDimension = (dividerPixelsWide / 3).floor();
    final dividerStart = ((pixelsWide - dividerDotDimension) / 2).floor();
    for (int i = 0; i < dividerDotDimension; i++) {
      for (int j = dividerOffset; j < height - dividerOffset; j++) {
        final isBottomDot = j < dividerOffset + dividerDotDimension;
        final isTopDot = j >= height - dividerOffset - dividerDotDimension;
        if (isBottomDot || isTopDot) {
          pixelColors[i + dividerStart][j + digitPadding + verticalPadding]
              .value = onColor;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return Container();
    }
    final size = MediaQuery.of(context).size;
    final pixelSize = (size.width) / (pixelsWide + 1);
    final cols = List<Widget>();
    for (int i = 0; i < pixelColors.length; i++) {
      final pixels = List<Widget>();
      for (int j = 0; j < pixelColors.first.length; j++) {
        pixels.add(Pixel(
          pixelNotifier: pixelColors[i][j],
          paddingNotifier: paddingColors[i][j],
          height: pixelSize,
          width: pixelSize,
        ));
      }
      cols.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: pixels,
        ),
      );
    }

    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: cols,
        ),
        ValueListenableBuilder(
          valueListenable: hour,
          builder: (context, hour, _) {
            return ValueListenableBuilder(
              valueListenable: minute,
              builder: (context, minute, _) {
                return AccessibilityHelper(
                  hour: hour,
                  minute: minute,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// A class to help screen readers voice the current time.
class AccessibilityHelper extends StatelessWidget {
  AccessibilityHelper({this.hour, this.minute});

  final int hour;
  final int minute;

  @override
  Widget build(BuildContext context) {
    print("$hour $minute");
    return Semantics(
      child: Container(
        child: SizedBox.expand(
          child: Container(),
        ),
      ),
      label: '$hour $minute',
    );
  }
}

// An individual pixel on the screen.
class Pixel extends StatelessWidget {
  Pixel({this.pixelNotifier, this.paddingNotifier, this.height, this.width});

  final ValueNotifier<Color> pixelNotifier;
  final ValueNotifier<Color> paddingNotifier;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: paddingNotifier,
      builder: (BuildContext context, Color paddingColor, Widget child) {
        return Container(
          color: paddingColor,
          child: ValueListenableBuilder(
            valueListenable: pixelNotifier,
            builder: (BuildContext context, Color pixelColor, Widget child) {
              return Padding(
                padding: EdgeInsets.all(0.4),
                child: Container(
                  height: height - 0.8,
                  width: width - 0.8,
                  color: pixelColor,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
