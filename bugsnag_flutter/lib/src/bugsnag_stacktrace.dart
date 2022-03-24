import 'package:bugsnag_flutter/bugsnag.dart';
import 'package:flutter/foundation.dart';

// This file is heavily based on:
// https://github.com/dart-lang/sdk/blob/main/pkg/native_stack_traces/lib/src/convert.dart
// the primary difference is that we're only interested in the virtual address

final _traceLineRE =
    RegExp(r'\s*#(\d+) abs [\da-f]+(?: virt (?<virtual>[\da-f]+))? .*$');

final _buildIdRegExp = RegExp(r"build_id: \'([a-f0-9]+)\'");

// Try to parse the build_id from the line, returning it's value if it existed
String? _parseBuildId(String line) {
  final match = _buildIdRegExp.firstMatch(line);
  return match?.group(1);
}

int? _retrievePCOffset(String line) {
  final match = _traceLineRE.firstMatch(line);
  if (match == null) return null;
  // If all other cases failed, check for a virtual address. Until this package
  // depends on a version of Dart which only prints virtual addresses when the
  // virtual addresses in the snapshot are the same as in separately saved
  // debugging information, the other methods should be tried first.
  final virtualString = match.namedGroup('virtual');
  if (virtualString != null) {
    final address = int.parse(virtualString, radix: 16);
    return address;
  }
  return null;
}

Stacktrace? _parseStackTrace(String stackTraceString) {
  try {
    return StackFrame.fromStackTrace(StackTrace.fromString(stackTraceString))
        .map(Stackframe.fromStackFrame)
        .toList();
  } catch (e) {
    return null;
  }
}

/// If possible parse the given [stackTrace] as an obfuscated native stackTrace.
/// If the given `stackTrace` is not a valid native stack trace return `null`.
Stacktrace? parseNativeStackTrace(String stackTrace) {
  final stackTraceLines = stackTrace.split('\n');

  String? buildId;

  List<Stackframe> stacktrace = [];

  for (final line in stackTraceLines) {
    buildId ??= _parseBuildId(line);
    final pcOffset = _retrievePCOffset(line);

    if (pcOffset != null) {
      stacktrace.add(Stackframe(
        frameAddress: '0x' + pcOffset.toRadixString(16),
        codeIdentifier: buildId,
      ));
    }
  }

  return buildId != null ? stacktrace : null;
}

Stacktrace? parseStackTraceString(String stackTrace) {
  return parseNativeStackTrace(stackTrace) ?? _parseStackTrace(stackTrace);
}
