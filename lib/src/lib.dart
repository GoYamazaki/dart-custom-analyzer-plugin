// ignore_for_file: implementation_imports
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/src/dart/analysis/file_byte_store.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:path/path.dart';

import 'analyzer/analyzer.dart';
import 'analyzer/options/options.dart';

typedef ContextStartHook = void Function(
  AnalysisContext context,
);
typedef ContextDoneHook = void Function(
  AnalysisContext context,
  Iterable<AnalysisErrorFixes> errorFixes,
);

/// Paths may contain files or directories
Future<Iterable<AnalysisErrorFixes>> analyze(
  Iterable<String> paths,
) async {
  final resourceProvider = PhysicalResourceProvider.INSTANCE;
  final contextCollection = AnalysisContextCollectionImpl(
    includedPaths: paths.map(canonicalize).toList(),
    resourceProvider: resourceProvider,
    byteStore: _createByteStore(resourceProvider),
  );

  final errors = <AnalysisErrorFixes>[];
  for (final context in contextCollection.contexts) {
    final enabledRules = getRulesFromDriver(context.driver);
    if (enabledRules.isNotEmpty) {
      for (final file in context.contextRoot
          .analyzedFiles()
          .where((file) => file.endsWith('.dart'))) {
        final resolvedUnit = await context.currentSession.getResolvedUnit(file);
        if (resolvedUnit is ResolvedUnitResult) {
          errors.addAll(analyzeResult(resolvedUnit, enabledRules));
        }
      }
    }
  }
  return errors;
}

/// If the state location can be accessed, return the file byte store,
/// otherwise return the memory byte store.
ByteStore _createByteStore(PhysicalResourceProvider resourceProvider) {
  const M = 1024 * 1024 /*1 MiB*/;
  const G = 1024 * 1024 * 1024 /*1 GiB*/;

  const memoryCacheSize = M * 128;

  final stateLocation =
      resourceProvider.getStateLocation('.dart-custom-analyzer-plugin');
  if (stateLocation != null) {
    return MemoryCachingByteStore(
      EvictingFileByteStore(stateLocation.path, G),
      memoryCacheSize,
    );
  }

  return MemoryCachingByteStore(NullByteStore(), memoryCacheSize);
}
