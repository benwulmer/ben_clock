import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:image/image.dart';
import 'package:tuple/tuple.dart';

/*
 * This data provider is a set of utility tools for reading assets and parsing
 * them into grids of bools.
 */

// Loads a digit asset and parses it into a grid of bools of size
// heightResolution by widthResoltution. A bool in this grid will be true if
// the area of the asset corresponding to that bool has more 'light' pixels
// (pixels with a luminance equal or greater to 128) than 'dark' pixels.
Future<List<List<bool>>> getImagePixels(
  int digit,
  int heightResolution,
  int widthResolution,
) async {
  ByteData bytes = await rootBundle.load('assets/$digit.png');
  final image = Image.from(decodeImage(bytes.buffer.asUint8List()));
  final newGrid = List<List<bool>>();
  for (int i = 0; i < heightResolution; i++) {
    final row = List<bool>.filled(widthResolution, false, growable: true);
    newGrid.add(row);
  }

  final heightFactor = (image.height / heightResolution).floor();
  final widthFactor = (image.width / widthResolution).floor();

  for (int i = 0; i < heightResolution; i++) {
    for (int j = 0; j < widthResolution; j++) {
      int numBlack = 0;
      for (int k = 0; k < heightFactor; k++) {
        for (int l = 0; l < widthFactor; l++) {
          final y = i * heightFactor + k;
          final x = j * widthFactor + l;
          final pixel = image.getPixel(x, y);
          int r = getRed(pixel);
          int b = getBlue(pixel);
          int g = getGreen(pixel);
          if (r * 0.3 + g * 0.59 + b * 0.11 < 128) {
            numBlack++;
          }
        }
      }
      if (numBlack > heightFactor * widthFactor / 2) {
        newGrid[i][j] = true;
      }
    }
  }
  return newGrid;
}

// Adds a padding of false around a grid of bool.
void addPadding(List<List<bool>> grid) {
  for (final row in grid) {
    row.add(false);
    row.insert(0, false);
  }
  final width = grid[0].length;
  final row = List<bool>.filled(width, false, growable: true);
  grid.add(row);
  grid.insert(0, row);
}

// Increases resolution of a grid of bools; for example a 3x3 grid that was
// increased by a factor of 3 would become a 9x9 grid.
List<List<bool>> increaseResolution(List<List<bool>> grid, int factor) {
  final height = grid.length;
  final width = grid[0].length;
  final newGrid = List<List<bool>>();
  for (int i = 0; i < height * factor; i++) {
    final row = List<bool>.filled(width * factor, false, growable: true);
    newGrid.add(row);
  }
  for (int i = 0; i < height; i++) {
    for (int j = 0; j < width; j++) {
      if (grid[i][j]) {
        for (int k = 0; k < factor; k++) {
          for (int l = 0; l < factor; l++) {
            newGrid[i * factor + l][j * factor + k] = true;
          }
        }
      }
    }
  }
  return newGrid;
}

// Returns of grids of ints, where each int is the number of steps required to
// reach the closes true value to the passed in grid.
List<List<int>> getDistances(List<List<bool>> grid) {
  final newGrid = List<List<int>>();
  for (int i = 0; i < grid.length; i++) {
    final row = List<int>.filled(grid[0].length, 0, growable: true);
    newGrid.add(row);
  }
  for (int i = 0; i < newGrid.length; i++) {
    for (int j = 0; j < newGrid[0].length; j++) {
      newGrid[i][j] = getDistance(i, j, grid);
    }
  }
  return newGrid;
}

// Returns the distance between a point and the closest true value in a grid of
// bools.
int getDistance(int y, int x, List<List<bool>> grid) {
  if (grid[y][x]) {
    return 0;
  }
  final height = grid.length;
  final width = grid[0].length;
  final seen = Set<Tuple2<int, int>>();
  final queue = Queue<Tuple3<int, int, int>>();
  queue.add(Tuple3<int, int, int>(x, y, 0));
  while (queue.isNotEmpty) {
    final curPoint = queue.removeFirst();
    final curX = curPoint.item1;
    final curY = curPoint.item2;
    final curDistance = curPoint.item3;

    if (grid[curY][curX]) {
      return curDistance;
    }
    if (validPoint(curX - 1, curY, width, height, seen)) {
      seen.add(Tuple2<int, int>(curX - 1, curY));
      queue.add(Tuple3<int, int, int>(curX - 1, curY, curDistance + 1));
    }
    if (validPoint(curX, curY - 1, width, height, seen)) {
      seen.add(Tuple2<int, int>(curX, curY - 1));
      queue.add(Tuple3<int, int, int>(curX, curY - 1, curDistance + 1));
    }
    if (validPoint(curX + 1, curY, width, height, seen)) {
      seen.add(Tuple2<int, int>(curX + 1, curY));
      queue.add(Tuple3<int, int, int>(curX + 1, curY, curDistance + 1));
    }
    if (validPoint(curX, curY + 1, width, height, seen)) {
      seen.add(Tuple2<int, int>(curX, curY + 1));
      queue.add(Tuple3<int, int, int>(curX, curY + 1, curDistance + 1));
    }
  }
  return -1;
}

bool validPoint(
  int x,
  int y,
  int width,
  int height,
  Set<Tuple2<int, int>> seen,
) {
  if (x < 0 || x >= width) {
    return false;
  }
  if (y < 0 || y >= height) {
    return false;
  }
  return !seen.contains(Tuple2<int, int>(x, y));
}
