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
        backgroundColor: Colors.green,
        scaffoldBackgroundColor: Colors.green,
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
  static const factor = 12;
  static const pixelSize = 2.5;

  List<List<List<bool>>> digitModels;

  // TODO use
  List<List<List<int>>> digitDistances;
  int hourFirst;
  int hourSecond;
  int minuteFirst;
  int minuteSecond;

  @override
  void initState() {
    super.initState();
    setImages();
    digitModels = getDigits();
    digitDistances = List<List<List<int>>>();
    for (int i = 0; i < digitModels.length; i++) {
      digitModels[i] = increaseDensity(digitModels[i], factor);
      addPadding(digitModels[i]);
      digitDistances.add(getDistances(digitModels[i]));
    }
    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();
  }

  Future<void> setImages() async {
    for (int i = 0; i < 10; i++) {
      final pixels = await getImagePixels(i, 30, 30);
      addPadding(pixels);
      final distances = getDistances(pixels);
      digitModels[i] = pixels;
      digitDistances[i] = distances;
    }
    setState(() {});
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

    _timer = Timer(
      Duration(seconds: 1) - Duration(milliseconds: _dateTime.millisecond),
      _updateTime,
    );

    final hour = _dateTime.hour;
    final minute = _dateTime.second;
    final int firstDigit = (hour / 10).floor();
    final int secondDigit = hour % 10;
    final int thirdDigit = (minute / 10).floor();
    final int fourthDigit = minute % 10;
    setState(() {
      hourFirst = firstDigit;
      hourSecond = secondDigit;
      minuteFirst = thirdDigit;
      minuteSecond = fourthDigit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>();
    for (int i = 0; i < 4; i++) {
      children.add(
        Digit(
          notifier: digitsNotifiers[i],
          models: digitModels,
          digitIndex: i,
          distances: digitDistances,
          pixelSize: pixelSize,
        ),
      );
    }
    children.insert(
      2,
      Divider(
        size: pixelSize,
        height: digitModels[0].length,
        width: (digitModels[0].length / 4).floor(),
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        )
      ],
    );
  }
}

class Divider extends StatelessWidget {
  Divider({this.height, this.width, this.size});

  final int height;
  final int width;
  final double size;

  static const dimensionFactor = 5;

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>();
    final midpointWidth = width / 2;
    final topPoint = height * 3 / 4;
    final bottomPoint = height / 4;
    for (int i = 0; i < height; i++) {
      final values = List<Widget>();
      for (int j = 0; j < width; j++) {
        final withinWidth = j > (midpointWidth - width / dimensionFactor) &&
            j < (midpointWidth + width / dimensionFactor);
        final withinTop = (i > (topPoint - width / dimensionFactor)) &&
            i < (topPoint + width / dimensionFactor);
        final withinBottom = (i > (bottomPoint - width / dimensionFactor)) &&
            i < (bottomPoint + width / dimensionFactor);
        values.add(
          Padding(
            padding: EdgeInsets.all(0),
            child: Container(
              height: size,
              width: size,
              decoration: BoxDecoration(
                color: withinWidth && (withinTop || withinBottom)
                    ? Colors.blue
                    : Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }
      children.add(
        Row(
          children: values,
        ),
      );
    }
    return Column(children: children);
  }
}

class Digit extends StatelessWidget {
  Digit({
    this.notifier,
    this.models,
    this.digitIndex,
    this.distances,
    this.pixelSize,
  });

  final DigitNotifier notifier;
  final List<List<List<bool>>> models;
  final List<List<List<int>>> distances;
  final int digitIndex;
  final double pixelSize;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: notifier.transition,
      builder: (_, val, _2) {
        final height = models[0].length;
        final width = models[0][0].length;
        final prevDigit = models[notifier.prevDigit];
        final curDigit = models[notifier.curDigit];
        final prevDistances = distances[notifier.prevDigit];
        final curDistances = distances[notifier.curDigit];

        final children = List<Widget>();
        for (int i = 0; i < height; i++) {
          final values = List<Widget>();
          for (int j = 0; j < width; j++) {
            final nextDouble = Random().nextDouble();
            final on = getNormalFade(
              curDigit[i][j],
              prevDigit[i][j],
              curDistances[i][j],
              prevDistances[i][j],
              val,
              numTicks,
              nextDouble,
            );

            values.add(
              Padding(
                padding: EdgeInsets.all(0),
                child: Container(
                  height: pixelSize,
                  width: pixelSize,
                  decoration: BoxDecoration(
                    color: on ? Colors.blue : Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }
          children.add(
            Row(
              children: values,
            ),
          );
        }
        return Column(children: children);
      },
    );
  }
}

bool getNormalFade(
  bool curOn,
  bool prevOn,
  int curMinDistance,
  int prevMinDistance,
  int tick,
  int numTicks,
  double nextDouble,
) {
  final max = (numTicks / 3).ceil();
  final double proportion = tick / numTicks;

  if (proportion > 0.8 && curMinDistance == 0) {
    return true;
  }

  if (proportion < 0.5 && prevMinDistance < max) {
    return (proportion * max).floor() == prevMinDistance;
  }
  if (proportion >= 0.5 && curMinDistance < max) {
    return ((1 - proportion) * max).floor() == curMinDistance;
  }
  return false;
}

bool getThreshold(
  bool curOn,
  bool prevOn,
  int curMinDistance,
  int prevMinDistance,
  int tick,
  int numTicks,
  double nextDouble,
) {
  const max = 2;
  final double proportion = tick / numTicks;
  if (proportion < 0.5 && prevMinDistance < max) {
    // proportion of 0 and prevMinDistance of 0 -> 0
    // proportion of 0 and prevMinDistance of half -> 0.5
    // proportion of 0 and prevMinDistance of max -> 1
    // proportion of 0.5 and prevMinDistance of 0 -> 0.5
    // proportion of 0.5 and prevMinDistance of half -> 0.5
    // proportion of 0.5 and prevMinDistance of max -> 0.5

    return nextDouble > (proportion + (prevMinDistance / max));
  }
  if (proportion >= 0.5 && curMinDistance < max) {
    return nextDouble > ((proportion - 0.5) + (curMinDistance / max));
  }
  return false;
}

bool getFadeThreshold(
  bool curOn,
  bool prevOn,
  int curMinDistance,
  int prevMinDistance,
  int tick,
  int numTicks,
  double nextDouble,
) {
  final prevScore = prevOn ? tick / numTicks : 1.0;
  final curScore = curOn ? 1 - tick / numTicks : 1.0;
  return nextDouble > min(prevScore, curScore);
}
