// Copyright 2026 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gltf/gltf.dart';
import 'package:gltf/src/errors.dart';
import 'package:test/test.dart';

Future<void> main() async {
  const path = 'test/ext/KHR_character/data/valid_complete.gltf';
  const expressionSet = 'https://example.com/expressions/v1';
  const skeletonSet = 'https://example.com/skeleton/v1';

  Future<Map<String, Object>> loadMap() async =>
      (jsonDecode(await File(path).readAsString()) as Map)
          .cast<String, Object>();

  Future<GltfJsonReader> readMap(Map<String, Object> map) async {
    final reader =
        GltfJsonReader(Stream<List<int>>.value(utf8.encode(jsonEncode(map))));
    await reader.read();
    return reader;
  }

  Future<GltfJsonReader> readMapWithResources(Map<String, Object> map) async {
    final reader =
        GltfJsonReader(Stream<List<int>>.value(utf8.encode(jsonEncode(map))));
    final result = await reader.read();
    if (result?.gltf != null) {
      await ResourcesLoader(reader.context, result.gltf,
          externalBytesFetch: ([uri]) => null,
          externalStreamFetch: (uri) => null).load();
    }
    return reader;
  }

  int addFloatAccessor(
      Map<String, Object> map, List<double> values, String type, int count) {
    final data = ByteData(values.length * 4);
    for (var i = 0; i < values.length; ++i) {
      data.setFloat32(i * 4, values[i], Endian.little);
    }
    final buffers = map['buffers'] as List<Object>;
    final bufferViews = map['bufferViews'] as List<Object>;
    final accessors = map['accessors'] as List<Object>;
    final bufferIndex = buffers.length;
    final bufferViewIndex = bufferViews.length;
    buffers.add(<String, Object>{
      'byteLength': data.lengthInBytes,
      'uri':
          'data:application/octet-stream;base64,${base64Encode(data.buffer.asUint8List())}'
    });
    bufferViews.add(<String, Object>{
      'buffer': bufferIndex,
      'byteLength': data.lengthInBytes
    });
    accessors.add(<String, Object>{
      'bufferView': bufferViewIndex,
      'componentType': 5126,
      'count': count,
      'type': type
    });
    return accessors.length - 1;
  }

  int addNormalizedUnsignedByteAccessor(
      Map<String, Object> map, List<int> values, String type, int count) {
    final buffers = map['buffers'] as List<Object>;
    final bufferViews = map['bufferViews'] as List<Object>;
    final accessors = map['accessors'] as List<Object>;
    final bufferIndex = buffers.length;
    final bufferViewIndex = bufferViews.length;
    buffers.add(<String, Object>{
      'byteLength': values.length,
      'uri': 'data:application/octet-stream;base64,${base64Encode(values)}'
    });
    bufferViews.add(
        <String, Object>{'buffer': bufferIndex, 'byteLength': values.length});
    accessors.add(<String, Object>{
      'bufferView': bufferViewIndex,
      'componentType': 5121,
      'normalized': true,
      'count': count,
      'type': type
    });
    return accessors.length - 1;
  }

  test('complete character family has no extension support diagnostics',
      () async {
    final reader = GltfJsonReader(File(path).openRead());
    final result = await reader.read();

    expect(result.gltf, isNotNull);
    expect(
        reader.context.issues.where((issue) =>
            issue.type == LinkError.unsupportedExtension ||
            issue.type == LinkError.incompleteExtensionSupport),
        isEmpty);
    expect(reader.context.errors, isEmpty);

    final character = result.gltf.extensions[KHR_CHARACTER] as KhrCharacter;
    expect(character.rootNode, same(result.gltf.nodes[0]));

    final expressions = result.gltf.extensions[KHR_CHARACTER_EXPRESSION]
        as KhrCharacterExpression;
    final entry = expressions.expressions[0];
    expect(entry.animation, same(result.gltf.animations[0]));
    expect(entry.extensions[KHR_CHARACTER_EXPRESSION_JOINT],
        isA<KhrCharacterExpressionJoint>());
    expect(entry.extensions[KHR_CHARACTER_EXPRESSION_MORPHTARGET],
        isA<KhrCharacterExpressionMorphTarget>());
    expect(entry.extensions[KHR_CHARACTER_EXPRESSION_TEXTURE],
        isA<KhrCharacterExpressionTexture>());
    expect(entry.extensions[KHR_CHARACTER_EXPRESSION_MASK],
        isA<KhrCharacterExpressionMask>());
    final mask = entry.extensions[KHR_CHARACTER_EXPRESSION_MASK]
        as KhrCharacterExpressionMask;
    expect(mask.masks[0].target, same(entry));
    expect(mask.masks[0].name, 'customSmile');
    final mapping = result.gltf.extensions[KHR_CHARACTER_EXPRESSION_MAPPING]
        as KhrCharacterExpressionMapping;
    expect(mapping.expressionSetMappings[expressionSet]['Smile'][0].source,
        same(entry));
    expect(mapping.expressionSetMappings[expressionSet]['Smile'][0].name,
        'customSmile');
    expect(mapping.expressionSetInputMappings[expressionSet]['Smile'][0].target,
        same(entry));
    expect(mapping.expressionSetInputMappings[expressionSet]['Smile'][0].name,
        'customSmile');
    final skeleton = result.gltf.extensions[KHR_CHARACTER_SKELETON_MAPPING]
        as KhrCharacterSkeletonMapping;
    expect(skeleton.skeletalRigMappings[skeletonSet]['joint'].node,
        same(result.gltf.nodes[1]));
    expect(skeleton.skeletalRigMappings[skeletonSet]['joint'].name, 'Joint');
    expect(result.gltf.animations[1].extensions[KHR_CHARACTER_REFERENCE_POSE],
        isA<KhrCharacterReferencePose>());
    expect(result.gltf.nodes[0].extensions[KHR_NODE_CAMERA_HINT],
        isA<KhrNodeCameraHint>());
    expect(result.gltf.nodes[1].extensions[KHR_NODE_LOOKAT_TARGET],
        isA<KhrNodeLookAtTarget>());
    expect(result.gltf.nodes[2].extensions[KHR_NODE_VISIBILITY_HINT],
        isA<KhrNodeVisibilityHint>());
    expect(
        result.gltf.meshes[0].primitives[0]
            .extensions[KHR_MESH_PRIMITIVE_VISIBILITY_HINT],
        isA<KhrMeshPrimitiveVisibilityHint>());
  });

  test('character has no XMP dependency', () async {
    final map = await loadMap();
    final reader = await readMap(map);
    expect(
        reader.context.issues
            .where((issue) => issue.type == SchemaError.unsatisfiedDependency),
        isEmpty);
  });

  test('expression channels resolve against the selected animation', () async {
    final map = await loadMap();
    (map['animations'] as List<Object>).add(<String, Object>{
      'channels': <Object>[
        <String, Object>{
          'sampler': 0,
          'target': <String, Object>{'node': 2, 'path': 'weights'}
        }
      ],
      'samplers': <Object>[
        <String, Object>{'input': 0, 'output': 4}
      ]
    });
    final extensions = map['extensions'] as Map<String, Object>;
    final expressionRoot =
        extensions[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
    final expressions = expressionRoot['expressions'] as List<Object>;
    (expressions[0] as Map<String, Object>)['animation'] = 2;
    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterInvalidExpressionTarget));
  });

  test('camera hints cannot target their containing node', () async {
    final map = await loadMap();
    final nodes = map['nodes'] as List<Object>;
    final node = nodes[0] as Map<String, Object>;
    final extensions = node['extensions'] as Map<String, Object>;
    (extensions[KHR_NODE_CAMERA_HINT] as Map<String, Object>)['targetNode'] = 0;
    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrNodeCameraHintSelfReference));
  });

  test('root, animation, channel, skeleton, camera, and node indices resolve',
      () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    (extensions[KHR_CHARACTER] as Map<String, Object>)['rootNode'] = 99;
    final expressionRoot =
        extensions[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
    final expressions = expressionRoot['expressions'] as List<Object>;
    final entry = expressions[0] as Map<String, Object>;
    entry['animation'] = 99;
    final skeleton =
        extensions[KHR_CHARACTER_SKELETON_MAPPING] as Map<String, Object>;
    skeleton['skeletalRigMappings'] = <String, Object>{
      skeletonSet: <String, Object>{
        'joint': <String, Object>{'node': 99}
      }
    };
    final nodes = map['nodes'] as List<Object>;
    final node = nodes[0] as Map<String, Object>;
    final nodeExtensions = node['extensions'] as Map<String, Object>;
    (nodeExtensions[KHR_NODE_CAMERA_HINT] as Map<String, Object>)
      ..['camera'] = 99
      ..['targetNode'] = 99;
    final reader = await readMap(map);
    expect(
        reader.context.issues
            .where((issue) => issue.type == LinkError.unresolvedReference)
            .length,
        greaterThanOrEqualTo(5));
  });

  test('mapping and mask expression indices must resolve', () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    final expressionRoot =
        extensions[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
    final expressions = expressionRoot['expressions'] as List<Object>;
    final entry = expressions[0] as Map<String, Object>;
    final entryExtensions = entry['extensions'] as Map<String, Object>;
    final mask =
        entryExtensions[KHR_CHARACTER_EXPRESSION_MASK] as Map<String, Object>;
    final masks = mask['masks'] as List<Object>;
    (masks[0] as Map<String, Object>)['target'] = 99;

    final mapping =
        extensions[KHR_CHARACTER_EXPRESSION_MAPPING] as Map<String, Object>;
    final sets = mapping['expressionSetMappings'] as Map<String, Object>;
    final example = sets[expressionSet] as Map<String, Object>;
    final sources = example['Smile'] as List<Object>;
    (sources[0] as Map<String, Object>)['source'] = 99;

    final inputSets =
        mapping['expressionSetInputMappings'] as Map<String, Object>;
    final inputExample = inputSets[expressionSet] as Map<String, Object>;
    final targets = inputExample['Smile'] as List<Object>;
    (targets[0] as Map<String, Object>)['target'] = 99;

    final reader = await readMap(map);
    expect(
        reader.context.issues
            .where((issue) => issue.type == LinkError.unresolvedReference),
        hasLength(3));
  });

  test('optional reference names must exactly match resolved objects',
      () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    final expressionRoot =
        extensions[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
    final expressions = expressionRoot['expressions'] as List<Object>;
    final entry = expressions[0] as Map<String, Object>;
    final entryExtensions = entry['extensions'] as Map<String, Object>;
    final mask =
        entryExtensions[KHR_CHARACTER_EXPRESSION_MASK] as Map<String, Object>;
    ((mask['masks'] as List<Object>)[0] as Map<String, Object>)['name'] =
        'wrongMaskName';

    final mapping =
        extensions[KHR_CHARACTER_EXPRESSION_MAPPING] as Map<String, Object>;
    final sets = mapping['expressionSetMappings'] as Map<String, Object>;
    final example = sets[expressionSet] as Map<String, Object>;
    ((example['Smile'] as List<Object>)[0] as Map<String, Object>)['name'] =
        'wrongMappingName';

    final inputSets =
        mapping['expressionSetInputMappings'] as Map<String, Object>;
    final inputExample = inputSets[expressionSet] as Map<String, Object>;
    ((inputExample['Smile'] as List<Object>)[0]
        as Map<String, Object>)['name'] = 'wrongInputMappingName';

    final skeleton =
        extensions[KHR_CHARACTER_SKELETON_MAPPING] as Map<String, Object>;
    final rigs = skeleton['skeletalRigMappings'] as Map<String, Object>;
    final joints = rigs[skeletonSet] as Map<String, Object>;
    (joints['joint'] as Map<String, Object>)['name'] = 'wrongNodeName';

    final reader = await readMap(map);
    expect(
        reader.context.issues.where((issue) =>
            issue.type == LinkError.khrCharacterReferenceNameMismatch),
        hasLength(4));
  });

  test('reference names remain optional', () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    final expressionRoot =
        extensions[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
    final expressions = expressionRoot['expressions'] as List<Object>;
    final entry = expressions[0] as Map<String, Object>;
    final entryExtensions = entry['extensions'] as Map<String, Object>;
    final mask =
        entryExtensions[KHR_CHARACTER_EXPRESSION_MASK] as Map<String, Object>;
    ((mask['masks'] as List<Object>)[0] as Map<String, Object>).remove('name');
    final mapping =
        extensions[KHR_CHARACTER_EXPRESSION_MAPPING] as Map<String, Object>;
    final sets = mapping['expressionSetMappings'] as Map<String, Object>;
    final example = sets[expressionSet] as Map<String, Object>;
    ((example['Smile'] as List<Object>)[0] as Map<String, Object>)
        .remove('name');
    final inputSets =
        mapping['expressionSetInputMappings'] as Map<String, Object>;
    final inputExample = inputSets[expressionSet] as Map<String, Object>;
    ((inputExample['Smile'] as List<Object>)[0] as Map<String, Object>)
        .remove('name');
    final skeleton =
        extensions[KHR_CHARACTER_SKELETON_MAPPING] as Map<String, Object>;
    final rigs = skeleton['skeletalRigMappings'] as Map<String, Object>;
    final joints = rigs[skeletonSet] as Map<String, Object>;
    (joints['joint'] as Map<String, Object>).remove('name');

    final reader = await readMap(map);
    expect(reader.context.errors, isEmpty);
  });

  test('required members and nonempty arrays are enforced', () async {
    final missingRoot = await loadMap();
    final rootExtensions = missingRoot['extensions'] as Map<String, Object>;
    (rootExtensions[KHR_CHARACTER] as Map<String, Object>).remove('rootNode');

    final emptyExpressions = await loadMap();
    final expressionExtensions =
        emptyExpressions['extensions'] as Map<String, Object>;
    (expressionExtensions[KHR_CHARACTER_EXPRESSION]
        as Map<String, Object>)['expressions'] = <Object>[];

    final emptyChannels = await loadMap();
    final extensions = emptyChannels['extensions'] as Map<String, Object>;
    final expressionRoot =
        extensions[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
    final expressions = expressionRoot['expressions'] as List<Object>;
    final entry = expressions[0] as Map<String, Object>;
    final entryExtensions = entry['extensions'] as Map<String, Object>;
    (entryExtensions[KHR_CHARACTER_EXPRESSION_JOINT]
        as Map<String, Object>)['channels'] = <Object>[];

    for (final map in <Map<String, Object>>[
      missingRoot,
      emptyExpressions,
      emptyChannels
    ]) {
      final reader = await readMap(map);
      expect(reader.context.errors, isNotEmpty);
    }
  });

  test('expression channel arrays require unique indices', () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    final expressionRoot =
        extensions[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
    final expressions = expressionRoot['expressions'] as List<Object>;
    final entry = expressions[0] as Map<String, Object>;
    final entryExtensions = entry['extensions'] as Map<String, Object>;
    (entryExtensions[KHR_CHARACTER_EXPRESSION_JOINT]
        as Map<String, Object>)['channels'] = <Object>[0, 0];
    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(SchemaError.arrayDuplicateElements));
  });

  test('expression labels are nonempty but need not be unique', () async {
    final invalid = await loadMap();
    final invalidExpressionRoot =
        (invalid['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
            as Map<String, Object>;
    final invalidEntry = (invalidExpressionRoot['expressions']
        as List<Object>)[0] as Map<String, Object>;
    invalidEntry['expression'] = '';
    final invalidReader = await readMap(invalid);
    expect(invalidReader.context.issues.map((issue) => issue.type),
        contains(SchemaError.patternMismatch));

    final duplicate = await loadMap();
    final duplicateExpressionRoot = (duplicate['extensions']
            as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
        as Map<String, Object>;
    (duplicateExpressionRoot['expressions'] as List<Object>)
        .add(<String, Object>{'expression': 'customSmile', 'animation': 0});
    final duplicateReader = await readMap(duplicate);
    expect(duplicateReader.context.errors, isEmpty);
  });

  test('every referenced expression sampler has at least two keys', () async {
    final map = await loadMap();
    final animation =
        (map['animations'] as List<Object>)[0] as Map<String, Object>;
    ((animation['samplers'] as List<Object>)[0] as Map<String, Object>)
      ..['input'] = 0
      ..['output'] = 1;

    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionSamplerTooFewKeys));
  });

  test('expression channels require concrete property targets', () async {
    final map = await loadMap();
    final animation =
        (map['animations'] as List<Object>)[0] as Map<String, Object>;
    final channel =
        (animation['channels'] as List<Object>)[0] as Map<String, Object>;
    channel['target'] = <String, Object>{'path': 'translation'};

    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionNonConcreteTarget));
  });

  test('expression pointer targets cannot resolve into extras', () async {
    final map = await loadMap();
    final node = (map['nodes'] as List<Object>)[1] as Map<String, Object>;
    node['extras'] = <String, Object>{'expressionValue': 0};
    final animation =
        (map['animations'] as List<Object>)[0] as Map<String, Object>;
    final channel =
        (animation['channels'] as List<Object>)[2] as Map<String, Object>;
    channel['target'] = <String, Object>{
      'path': 'pointer',
      'extensions': <String, Object>{
        KHR_ANIMATION_POINTER: <String, Object>{
          'pointer': '/nodes/1/extras/expressionValue'
        }
      }
    };

    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionExtrasTarget));
  });

  test('unsupported expression target semantics are reported as incomplete',
      () async {
    final map = await loadMap();
    final expressionRoot =
        (map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
            as Map<String, Object>;
    final entry = (expressionRoot['expressions'] as List<Object>)[0]
        as Map<String, Object>;
    (entry['extensions'] as Map<String, Object>)
        .remove(KHR_CHARACTER_EXPRESSION_TEXTURE);
    final animation =
        (map['animations'] as List<Object>)[0] as Map<String, Object>;
    final channel =
        (animation['channels'] as List<Object>)[2] as Map<String, Object>;
    channel['target'] = <String, Object>{
      'path': 'pointer',
      'extensions': <String, Object>{
        KHR_ANIMATION_POINTER: <String, Object>{
          'pointer': '/materials/0/pbrMetallicRoughness/roughnessFactor'
        }
      }
    };
    ((animation['samplers'] as List<Object>)[2]
        as Map<String, Object>)['output'] = 9;

    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionValidationIncomplete));
    expect(reader.context.errors, isEmpty);
  });

  test('a channel cannot occur in two typed expression classifiers', () async {
    final map = await loadMap();
    final expressionRoot =
        (map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
            as Map<String, Object>;
    final entry = (expressionRoot['expressions'] as List<Object>)[0]
        as Map<String, Object>;
    final entryExtensions = entry['extensions'] as Map<String, Object>;
    (entryExtensions[KHR_CHARACTER_EXPRESSION_MORPHTARGET]
        as Map<String, Object>)['channels'] = <Object>[1, 0];

    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionClassifierOverlap));
  });

  test('unclassified expression channels remain valid', () async {
    final map = await loadMap();
    final expressionRoot =
        (map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
            as Map<String, Object>;
    final entry = (expressionRoot['expressions'] as List<Object>)[0]
        as Map<String, Object>;
    (entry['extensions'] as Map<String, Object>)
        .remove(KHR_CHARACTER_EXPRESSION_JOINT);

    final reader = await readMap(map);
    expect(reader.context.errors, isEmpty);
  });

  test('complete expression resources satisfy initial-state validation',
      () async {
    final reader = await readMapWithResources(await loadMap());
    final issues = reader.context.issues.map((issue) => issue.type);
    expect(issues,
        isNot(contains(DataError.khrCharacterExpressionInitialValueMismatch)));
    expect(issues,
        isNot(contains(LinkError.khrCharacterExpressionValidationIncomplete)));
    expect(reader.context.errors, isEmpty);
  });

  test('expression samples must begin at the authored initial state', () async {
    final map = await loadMap();
    final node = (map['nodes'] as List<Object>)[1] as Map<String, Object>;
    node['translation'] = <Object>[1, 0, 0];

    final reader = await readMapWithResources(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(DataError.khrCharacterExpressionInitialValueMismatch));
  });

  test('opposite-sign quaternions are equivalent initial values', () async {
    final map = await loadMap();
    final animation =
        (map['animations'] as List<Object>)[0] as Map<String, Object>;
    final channel =
        (animation['channels'] as List<Object>)[0] as Map<String, Object>;
    channel['target'] = <String, Object>{'node': 1, 'path': 'rotation'};
    final output =
        addFloatAccessor(map, <double>[0, 0, 0, -1, 0, 0, 0, -1], 'VEC4', 2);
    ((animation['samplers'] as List<Object>)[0]
        as Map<String, Object>)['output'] = output;

    final reader = await readMapWithResources(map);
    expect(reader.context.issues.map((issue) => issue.type),
        isNot(contains(DataError.khrCharacterExpressionInitialValueMismatch)));
    expect(reader.context.errors, isEmpty);
  });

  test('cubic expression initial checks use value records, not tangents',
      () async {
    final map = await loadMap();
    final animation =
        (map['animations'] as List<Object>)[0] as Map<String, Object>;
    final output = addFloatAccessor(
        map,
        <double>[
          100,
          100,
          100,
          0,
          0,
          0,
          100,
          100,
          100,
          100,
          100,
          100,
          0,
          0,
          0,
          100,
          100,
          100
        ],
        'VEC3',
        6);
    ((animation['samplers'] as List<Object>)[0] as Map<String, Object>)
      ..['output'] = output
      ..['interpolation'] = 'CUBICSPLINE';

    final reader = await readMapWithResources(map);
    expect(reader.context.issues.map((issue) => issue.type),
        isNot(contains(DataError.khrCharacterExpressionInitialValueMismatch)));
    expect(reader.context.errors, isEmpty);
  });

  test('normalized integer initial values use the specified allowance',
      () async {
    for (final encodedValue in <int>[128, 129]) {
      final map = await loadMap();
      final node = (map['nodes'] as List<Object>)[2] as Map<String, Object>;
      node['weights'] = <Object>[0.5];
      final output = addNormalizedUnsignedByteAccessor(
          map, <int>[encodedValue, encodedValue], 'SCALAR', 2);
      final animation =
          (map['animations'] as List<Object>)[0] as Map<String, Object>;
      ((animation['samplers'] as List<Object>)[1]
          as Map<String, Object>)['output'] = output;

      final reader = await readMapWithResources(map);
      final hasMismatch = reader.context.issues.any((issue) =>
          issue.type == DataError.khrCharacterExpressionInitialValueMismatch);
      expect(hasMismatch, encodedValue == 129, reason: '$encodedValue');
    }
  });

  test('missing expression resources make validation incomplete', () async {
    final map = await loadMap();
    final buffer = (map['buffers'] as List<Object>)[0] as Map<String, Object>;
    buffer['uri'] = 'missing.bin';

    final reader = await readMapWithResources(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionValidationIncomplete));
  });

  test('mask ranges and open vocabularies are validated', () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    final expressionRoot =
        extensions[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
    final expressions = expressionRoot['expressions'] as List<Object>;
    final entry = expressions[0] as Map<String, Object>;
    final entryExtensions = entry['extensions'] as Map<String, Object>;
    final mask =
        entryExtensions[KHR_CHARACTER_EXPRESSION_MASK] as Map<String, Object>;
    final masks = mask['masks'] as List<Object>;
    (masks[0] as Map<String, Object>)
      ..['type'] = ''
      ..['amount'] = 1.1
      ..['threshold'] = -0.1;
    final reader = await readMap(map);
    expect(reader.context.errors.length, greaterThanOrEqualTo(3));
  });

  test('mask types and optional names follow the proposal grammar', () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    final expressionRoot =
        extensions[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
    final expressions = expressionRoot['expressions'] as List<Object>;
    final entry = expressions[0] as Map<String, Object>;
    final entryExtensions = entry['extensions'] as Map<String, Object>;
    final mask =
        entryExtensions[KHR_CHARACTER_EXPRESSION_MASK] as Map<String, Object>;
    final masks = mask['masks'] as List<Object>;
    (masks[0] as Map<String, Object>)
      ..['type'] = 'ACME_InvalidSuffix'
      ..['name'] = '';

    final reader = await readMap(map);
    expect(
        reader.context.issues
            .where((issue) => issue.type == SchemaError.patternMismatch),
        hasLength(2));
  });

  test('mask arrays are required and custom companions must be declared',
      () async {
    final missing = await loadMap();
    final missingExpressionRoot =
        (missing['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
            as Map<String, Object>;
    final missingEntry = (missingExpressionRoot['expressions']
        as List<Object>)[0] as Map<String, Object>;
    final missingEntryExtensions =
        missingEntry['extensions'] as Map<String, Object>;
    (missingEntryExtensions[KHR_CHARACTER_EXPRESSION_MASK]
            as Map<String, Object>)
        .remove('masks');
    final missingReader = await readMap(missing);
    expect(missingReader.context.issues.map((issue) => issue.type),
        contains(SchemaError.undefinedProperty));

    final companion = await loadMap();
    final companionExpressionRoot = (companion['extensions']
            as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
        as Map<String, Object>;
    final companionEntry = (companionExpressionRoot['expressions']
        as List<Object>)[0] as Map<String, Object>;
    final companionEntryExtensions =
        companionEntry['extensions'] as Map<String, Object>;
    final companionMask =
        companionEntryExtensions[KHR_CHARACTER_EXPRESSION_MASK]
            as Map<String, Object>;
    ((companionMask['masks'] as List<Object>)[0] as Map<String, Object>)
      ..['type'] = 'ACME_expression_mask_curve'
      ..['extensions'] = <String, Object>{
        'ACME_expression_mask_curve': <String, Object>{}
      };
    final companionReader = await readMap(companion);
    expect(companionReader.context.issues.map((issue) => issue.type),
        contains(LinkError.undeclaredExtension));
  });

  test('empty skeleton dictionaries are rejected', () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    (extensions[KHR_CHARACTER_SKELETON_MAPPING]
        as Map<String, Object>)['skeletalRigMappings'] = <String, Object>{};
    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(SchemaError.emptyEntity));
  });

  test('mapping accepts either independent direction and rejects neither',
      () async {
    final forwardOnly = await loadMap();
    ((forwardOnly['extensions']
                as Map<String, Object>)[KHR_CHARACTER_EXPRESSION_MAPPING]
            as Map<String, Object>)
        .remove('expressionSetInputMappings');
    final forwardReader = await readMap(forwardOnly);
    expect(forwardReader.context.errors, isEmpty);

    final inputOnly = await loadMap();
    ((inputOnly['extensions']
                as Map<String, Object>)[KHR_CHARACTER_EXPRESSION_MAPPING]
            as Map<String, Object>)
        .remove('expressionSetMappings');
    final inputReader = await readMap(inputOnly);
    expect(inputReader.context.errors, isEmpty);

    final neither = await loadMap();
    ((neither['extensions']
            as Map<String, Object>)[KHR_CHARACTER_EXPRESSION_MAPPING]
        as Map<String, Object>)
      ..remove('expressionSetMappings')
      ..remove('expressionSetInputMappings');
    final neitherReader = await readMap(neither);
    expect(neitherReader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionMappingMissingOperation));
  });

  test('mapping validates set URIs, nonempty data, and weights', () async {
    final map = await loadMap();
    final mapping = (map['extensions']
            as Map<String, Object>)[KHR_CHARACTER_EXPRESSION_MAPPING]
        as Map<String, Object>;
    mapping['expressionSetMappings'] = <String, Object>{
      'relative-profile': <String, Object>{
        '': <Object>[
          <String, Object>{'source': 0, 'weight': 1.1}
        ]
      }
    };
    mapping['expressionSetInputMappings'] = <String, Object>{};

    final reader = await readMap(map);
    final issues = reader.context.issues.map((issue) => issue.type);
    expect(issues,
        contains(LinkError.khrCharacterMappingSetIdentifierNotAbsolute));
    expect(issues, contains(SchemaError.emptyEntity));
    expect(issues, contains(SchemaError.valueNotInRange));
  });

  test('skeleton mappings use conventional glTF index parsing', () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    final skeleton =
        extensions[KHR_CHARACTER_SKELETON_MAPPING] as Map<String, Object>;
    skeleton['skeletalRigMappings'] = <String, Object>{
      skeletonSet: <String, Object>{
        'joint': <String, Object>{'node': 1.0}
      }
    };
    final reader = await readMap(map);
    expect(reader.context.errors, isEmpty);
  });

  test('legacy integer skeleton associations are rejected', () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    final skeleton =
        extensions[KHR_CHARACTER_SKELETON_MAPPING] as Map<String, Object>;
    skeleton['skeletalRigMappings'] = <String, Object>{
      skeletonSet: <String, Object>{'joint': 1}
    };
    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(SchemaError.typeMismatch));
  });

  test('skeleton mappings require absolute set URIs and nonempty roles',
      () async {
    final map = await loadMap();
    final extensions = map['extensions'] as Map<String, Object>;
    final skeleton =
        extensions[KHR_CHARACTER_SKELETON_MAPPING] as Map<String, Object>;
    skeleton['skeletalRigMappings'] = <String, Object>{
      'relative-profile': <String, Object>{
        '': <String, Object>{'node': 1}
      }
    };

    final reader = await readMap(map);
    final issues = reader.context.issues.map((issue) => issue.type);
    expect(issues,
        contains(LinkError.khrCharacterMappingSetIdentifierNotAbsolute));
    expect(issues, contains(SchemaError.emptyEntity));
  });

  test('reference poses require nonempty labels and static TRS channels',
      () async {
    final map = await loadMap();
    final animations = map['animations'] as List<Object>;
    final pose = animations[1] as Map<String, Object>;
    final poseExtensions = pose['extensions'] as Map<String, Object>;
    (poseExtensions[KHR_CHARACTER_REFERENCE_POSE]
        as Map<String, Object>)['poseType'] = '';
    final channels = pose['channels'] as List<Object>;
    (channels[0] as Map<String, Object>)['target'] = <String, Object>{
      'node': 2,
      'path': 'weights'
    };
    final sampler =
        (pose['samplers'] as List<Object>)[0] as Map<String, Object>;
    sampler['interpolation'] = 'CUBICSPLINE';
    final inputIndex = sampler['input'] as int;
    ((map['accessors'] as List<Object>)[inputIndex]
        as Map<String, Object>)['count'] = 2;

    final reader = await readMap(map);
    final issues = reader.context.issues.map((issue) => issue.type);
    expect(issues, contains(LinkError.khrCharacterReferencePoseInvalidTarget));
    expect(issues, contains(LinkError.khrCharacterReferencePoseInputCount));
    expect(issues,
        contains(LinkError.khrCharacterReferencePoseInvalidInterpolation));
    expect(reader.context.errors, isNotEmpty);
  });

  test('dependent extensions require the character root object', () async {
    final map = await loadMap();
    (map['extensions'] as Map<String, Object>).remove(KHR_CHARACTER);
    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(SchemaError.unsatisfiedDependency));
  });

  test('texture expressions require pointer and transform declarations',
      () async {
    for (final dependency in <String>[
      KHR_ANIMATION_POINTER,
      KHR_TEXTURE_TRANSFORM
    ]) {
      final map = await loadMap();
      (map['extensionsUsed'] as List<Object>).remove(dependency);
      final reader = await readMap(map);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(SchemaError.unsatisfiedDependency),
          reason: dependency);
    }
  });

  test('morph expressions accept ordinary and node pointer weight targets',
      () async {
    final ordinary = await readMap(await loadMap());
    expect(
        ordinary.context.issues.where((issue) =>
            issue.type == LinkError.khrCharacterInvalidExpressionTarget),
        isEmpty);

    final map = await loadMap();
    final animation =
        (map['animations'] as List<Object>)[0] as Map<String, Object>;
    final channels = animation['channels'] as List<Object>;
    (channels[1] as Map<String, Object>)['target'] = <String, Object>{
      'path': 'pointer',
      'extensions': <String, Object>{
        KHR_ANIMATION_POINTER: <String, Object>{'pointer': '/nodes/2/weights/0'}
      }
    };
    final pointer = await readMap(map);
    expect(
        pointer.context.issues.where((issue) =>
            issue.type == LinkError.khrCharacterInvalidExpressionTarget),
        isEmpty);
  });

  test('morph expressions reject mesh weight pointers', () async {
    final map = await loadMap();
    final animation =
        (map['animations'] as List<Object>)[0] as Map<String, Object>;
    final channels = animation['channels'] as List<Object>;
    (channels[1] as Map<String, Object>)['target'] = <String, Object>{
      'path': 'pointer',
      'extensions': <String, Object>{
        KHR_ANIMATION_POINTER: <String, Object>{
          'pointer': '/meshes/0/weights/0'
        }
      }
    };
    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterInvalidExpressionTarget));
  });

  test('texture expressions require a texture-transform pointer', () async {
    final map = await loadMap();
    final animation =
        (map['animations'] as List<Object>)[0] as Map<String, Object>;
    final channels = animation['channels'] as List<Object>;
    final target =
        (channels[2] as Map<String, Object>)['target'] as Map<String, Object>;
    final targetExtensions = target['extensions'] as Map<String, Object>;
    (targetExtensions[KHR_ANIMATION_POINTER]
            as Map<String, Object>)['pointer'] =
        '/materials/0/pbrMetallicRoughness/roughnessFactor';
    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterInvalidTextureExpressionPointer));
  });

  test('invalid extension locations are diagnosed', () async {
    final map = await loadMap();
    final nodes = map['nodes'] as List<Object>;
    final node = nodes[0] as Map<String, Object>;
    final extensions = node['extensions'] as Map<String, Object>;
    extensions[KHR_CHARACTER_REFERENCE_POSE] = <String, Object>{};
    final reader = await readMap(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.unexpectedExtensionObject));
  });
}
