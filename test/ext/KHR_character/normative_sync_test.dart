// Copyright 2026 The Khronos Group Inc.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gltf/gltf.dart';
import 'package:gltf/src/errors.dart';
import 'package:test/test.dart';

Future<void> main() async {
  Future<Map<String, Object>> asset() async =>
      (jsonDecode(await File('test/ext/KHR_character/data/valid_complete.gltf')
              .readAsString()) as Map)
          .cast<String, Object>();

  Future<GltfJsonReader> validate(Map<String, Object> map,
      {Context context, bool resources = false}) async {
    final reader = GltfJsonReader(
        Stream<List<int>>.value(utf8.encode(jsonEncode(map))), context);
    final result = await reader.read();
    if (resources && result?.gltf != null) {
      await ResourcesLoader(reader.context, result.gltf,
          externalBytesFetch: ([uri]) => null,
          externalStreamFetch: (uri) => null).load();
    }
    return reader;
  }

  Map<String, Object> entry(Map<String, Object> map) =>
      (((map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
              as Map<String, Object>)['expressions'] as List<Object>)[0]
          as Map<String, Object>;

  Map<String, Object> animation(Map<String, Object> map) =>
      (map['animations'] as List<Object>)[0] as Map<String, Object>;

  Map<String, Object> pointer(String path) => <String, Object>{
        'path': 'pointer',
        'extensions': <String, Object>{
          KHR_ANIMATION_POINTER: <String, Object>{'pointer': path}
        }
      };

  int output(Map<String, Object> map, List<num> values, String type, int count,
      {int componentType = 5126}) {
    final size = componentType == 5121 ? 1 : 4;
    final data = ByteData(values.length * size);
    for (var i = 0; i < values.length; ++i) {
      if (componentType == 5121) {
        data.setUint8(i, values[i].toInt());
      } else if (componentType == 5125) {
        data.setUint32(i * 4, values[i].toInt(), Endian.little);
      } else {
        data.setFloat32(i * 4, values[i].toDouble(), Endian.little);
      }
    }
    final buffers = map['buffers'] as List<Object>;
    final views = map['bufferViews'] as List<Object>;
    final accessors = map['accessors'] as List<Object>;
    views.add(<String, Object>{
      'buffer': buffers.length,
      'byteLength': data.lengthInBytes
    });
    buffers.add(<String, Object>{
      'byteLength': data.lengthInBytes,
      'uri':
          'data:application/octet-stream;base64,${base64Encode(data.buffer.asUint8List())}'
    });
    accessors.add(<String, Object>{
      'bufferView': views.length - 1,
      'componentType': componentType,
      'count': count,
      'type': type
    });
    return accessors.length - 1;
  }

  void singleChannel(
      Map<String, Object> map, Map<String, Object> target, int outputIndex,
      {String classifier, String interpolation = 'LINEAR'}) {
    final a = animation(map);
    a['channels'] = <Object>[
      <String, Object>{'sampler': 0, 'target': target}
    ];
    a['samplers'] = <Object>[
      <String, Object>{
        'input': 7,
        'output': outputIndex,
        'interpolation': interpolation
      }
    ];
    entry(map)['extensions'] = <String, Object>{
      if (classifier != null)
        classifier: <String, Object>{
          'channels': <Object>[0]
        }
    };
  }

  Context customProperty(String path, AnimationPointerValueType type) =>
      Context()
        ..registerExtensions(<Extension>[
          Extension(
              'ACME_expression_target', const <Type, ExtensionDescriptor>{},
              init: (context) => context.animationPointerProperties.add(
                  AnimationPointerProperty(
                      path,
                      type,
                      (_, __) =>
                          const AnimationPointerResolution(exists: true))))
        ]);

  test('native name duplicates report the later property and first index',
      () async {
    for (final sameAnimation in <bool>[false, true]) {
      final map = await asset();
      final exts = map['extensions'] as Map<String, Object>;
      final root = exts[KHR_CHARACTER_EXPRESSION] as Map<String, Object>;
      final first = entry(map);
      final duplicate =
          (jsonDecode(jsonEncode(first)) as Map).cast<String, Object>();
      if (!sameAnimation) {
        final animations = map['animations'] as List<Object>;
        animations.add(jsonDecode(jsonEncode(animation(map))));
        duplicate['animation'] = animations.length - 1;
      }
      final expressions = root['expressions'] as List<Object>;
      expressions.add(<String, Object>{'name': 'otherNative', 'animation': 0});
      final later = expressions.length;
      expressions.add(duplicate);
      final reader = await validate(map);
      final issues = reader.context.issues
          .where((issue) =>
              issue.type == LinkError.khrCharacterExpressionDuplicateName)
          .toList();
      expect(issues, hasLength(1));
      expect(issues.single.pointer,
          '/extensions/KHR_character_expression/expressions/$later/name');
      expect(issues.single.toString(), contains('expressions/0/name'));
    }
  });

  test('native names compare exactly and permit independent shared animations',
      () async {
    final map = await asset();
    final root =
        (map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
            as Map<String, Object>;
    root['expressions'] = <Object>[
      for (final name in <String>[
        'smile',
        'Smile',
        ' smile',
        'smile ',
        'é',
        'e\u0301',
        '__proto__',
        'toString'
      ])
        <String, Object>{'name': name, 'animation': 0}
    ];
    (map['extensions'] as Map<String, Object>)
        .remove(KHR_CHARACTER_EXPRESSION_MAPPING);
    final reader = await validate(map, resources: true);
    expect(reader.context.errors, isEmpty);
  });

  test('native duplicates remain invalid on unsupported expression entries',
      () async {
    final map = await asset();
    final root =
        (map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
            as Map<String, Object>;
    final duplicate =
        (jsonDecode(jsonEncode(entry(map))) as Map).cast<String, Object>();
    duplicate['extensions'] = <String, Object>{
      'ACME_future_expression': <String, Object>{}
    };
    (root['expressions'] as List<Object>).add(duplicate);
    final reader = await validate(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionDuplicateName));
  });

  test('marker has no root or metadata dependency', () async {
    final map = <String, Object>{
      'asset': <String, Object>{'version': '2.0'},
      'extensionsUsed': <Object>[KHR_CHARACTER],
      'extensionsRequired': <Object>[KHR_CHARACTER],
      'extensions': <String, Object>{KHR_CHARACTER: <String, Object>{}}
    };
    final reader = await validate(map, resources: true);
    expect(reader.context.errors, isEmpty);
    expect(reader.context.warnings, isEmpty);
  });

  test(
      'non-URI sets, duplicate associations, names and source entries are valid',
      () async {
    final map = await asset();
    final exts = map['extensions'] as Map<String, Object>;
    (exts[KHR_CHARACTER_EXPRESSION_MAPPING]
        as Map<String, Object>)['expressionSetMappings'] = <String, Object>{
      'vrm1_expressions': <String, Object>{
        'happy': <Object>[
          <String, Object>{'source': 0, 'name': 'Independent', 'weight': 0.75},
          <String, Object>{'source': 0, 'name': '', 'weight': 0},
          <String, Object>{'source': 0, 'weight': 0.75}
        ]
      }
    };
    (exts[KHR_CHARACTER_SKELETON_MAPPING]
        as Map<String, Object>)['skeletalRigMappings'] = <String, Object>{
      'vrm1_humanoid': <String, Object>{
        'hips': <String, Object>{'node': 1, 'name': 'Not a node name'},
        'customRole': <String, Object>{'node': 1, 'name': ''}
      }
    };
    entry(map)['name'] = '\n';
    final reader = await validate(map, resources: true);
    expect(reader.context.errors, isEmpty);
    expect(reader.context.warnings, isEmpty);
  });

  test(
      'mapping rejects missing source/weight, invalid indices and empty identifiers',
      () async {
    for (final bad in <Map<String, Object>>[
      <String, Object>{'target': 0, 'weight': 1},
      <String, Object>{'source': 0},
      <String, Object>{'source': 99, 'weight': 1},
      <String, Object>{'source': 0, 'weight': -0.1},
      <String, Object>{'source': 0, 'weight': 1.1}
    ]) {
      final map = await asset();
      final mapping = (map['extensions']
              as Map<String, Object>)[KHR_CHARACTER_EXPRESSION_MAPPING]
          as Map<String, Object>;
      mapping['expressionSetMappings'] = <String, Object>{
        'vrm1_expressions': <String, Object>{
          'happy': <Object>[bad]
        }
      };
      final reader = await validate(map);
      expect(reader.context.errors, isNotEmpty, reason: jsonEncode(bad));
    }
    for (final isSkeleton in <bool>[false, true]) {
      final map = await asset();
      final ext = (map['extensions'] as Map<String, Object>)[isSkeleton
          ? KHR_CHARACTER_SKELETON_MAPPING
          : KHR_CHARACTER_EXPRESSION_MAPPING] as Map<String, Object>;
      ext[isSkeleton ? 'skeletalRigMappings' : 'expressionSetMappings'] =
          <String, Object>{'': <String, Object>{}};
      final reader = await validate(map);
      expect(reader.context.errors, isNotEmpty);
    }
  });

  test('reference-pose type is required, with no assumed TPose default',
      () async {
    final map = await asset();
    final pose = (map['animations'] as List<Object>)[1] as Map<String, Object>;
    ((pose['extensions'] as Map<String, Object>)[KHR_CHARACTER_REFERENCE_POSE]
            as Map<String, Object>)
        .remove('poseType');
    final reader = await validate(map);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(SchemaError.undefinedProperty));
  });

  test('all core and pointer joint TRS classifications resolve', () async {
    for (final path in <String>['translation', 'rotation', 'scale']) {
      final map = await asset();
      final values = path == 'rotation'
          ? <num>[0, 0, 0, 1, 0, 0, 0, -1]
          : <num>[1, 1, 1, 2, 2, 2];
      final index =
          output(map, values, path == 'rotation' ? 'VEC4' : 'VEC3', 2);
      singleChannel(map, pointer('/nodes/1/$path'), index,
          classifier: KHR_CHARACTER_EXPRESSION_JOINT);
      final reader = await validate(map, resources: true);
      expect(reader.context.errors, isEmpty, reason: path);
    }
  });

  test(
      'matrix-node translation is allowed by base AOM but forbidden for expressions',
      () async {
    final map = await asset();
    final node = (map['nodes'] as List<Object>)[1] as Map<String, Object>;
    node['matrix'] = <num>[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
    singleChannel(map, pointer('/nodes/1/translation'), 8);
    // The unrelated reference pose must not also target this matrix node.
    (map['animations'] as List<Object>).removeAt(1);
    final expression = await validate(map);
    expect(expression.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionNonConcreteTarget));
    (map['extensions'] as Map<String, Object>).remove(KHR_CHARACTER_EXPRESSION);
    (map['extensions'] as Map<String, Object>)
        .remove(KHR_CHARACTER_EXPRESSION_MAPPING);
    final ordinary = await validate(map);
    expect(ordinary.context.errors, isEmpty);
  });

  test(
      'shared node translation, quaternion, scale, morph and UV responses are valid',
      () async {
    final cases = <String, List<num>>{
      '/nodes/1/translation': <num>[1, 0, 0, 3, 0, 0],
      '/nodes/1/rotation': <num>[0, 0, 0, 1, 0, 0, 0, -1],
      '/nodes/1/scale': <num>[1, 1, 1, 2, 2, 2],
      '/nodes/2/weights': <num>[0, 1],
      '/nodes/2/weights/0': <num>[0, 1],
      '/materials/0/pbrMetallicRoughness/baseColorTexture/extensions/KHR_texture_transform/offset':
          <num>[0, 0, 1, 1],
      '/materials/0/pbrMetallicRoughness/baseColorTexture/extensions/KHR_texture_transform/rotation':
          <num>[0, 12.5663706],
      '/materials/0/pbrMetallicRoughness/baseColorTexture/extensions/KHR_texture_transform/scale':
          <num>[1, 1, 2, 2]
    };
    for (final c in cases.entries) {
      final map = await asset();
      final n = c.value.length ~/ 2;
      final type = n == 4
          ? 'VEC4'
          : n == 3
              ? 'VEC3'
              : n == 2
                  ? 'VEC2'
                  : 'SCALAR';
      final cls = c.key.contains('KHR_texture_transform')
          ? KHR_CHARACTER_EXPRESSION_TEXTURE_TRANSFORM
          : c.key.contains('weights')
              ? KHR_CHARACTER_EXPRESSION_MORPHTARGET
              : KHR_CHARACTER_EXPRESSION_JOINT;
      singleChannel(map, pointer(c.key), output(map, c.value, type, 2),
          classifier: cls);
      final animations = map['animations'] as List<Object>;
      animations.add(jsonDecode(jsonEncode(animation(map))));
      final root =
          (map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
              as Map<String, Object>;
      final duplicate =
          (jsonDecode(jsonEncode(entry(map))) as Map).cast<String, Object>();
      duplicate['name'] = 'sharedTarget';
      duplicate['animation'] = animations.length - 1;
      (root['expressions'] as List<Object>).add(duplicate);
      final reader = await validate(map, resources: true);
      expect(reader.context.errors, isEmpty, reason: c.key);
      expect(reader.context.issues.map((issue) => issue.type),
          isNot(contains(LinkError.khrCharacterExpressionValidationIncomplete)),
          reason: c.key);
    }
  });

  test(
      'within-animation core/pointer and complete-array/element overlaps remain invalid',
      () async {
    for (final weights in <bool>[false, true]) {
      final map = await asset();
      singleChannel(
          map,
          <String, Object>{
            'node': weights ? 2 : 1,
            'path': weights ? 'weights' : 'translation'
          },
          weights ? 9 : 8);
      (animation(map)['channels'] as List<Object>).add(<String, Object>{
        'sampler': 0,
        'target':
            pointer(weights ? '/nodes/2/weights/0' : '/nodes/1/translation')
      });
      final reader = await validate(map);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.animationDuplicateTargets));
    }
  });

  test(
      'shared Boolean and integer properties remain valid while STEP/type gates apply',
      () async {
    for (final integer in <bool>[false, true]) {
      final map = await asset();
      final target = integer
          ? '/nodes/1/extras/discrete'
          : '/nodes/1/extensions/KHR_node_visibility/visible';
      final node = (map['nodes'] as List<Object>)[1] as Map<String, Object>;
      if (integer) {
        node['extras'] = <String, Object>{'discrete': 0};
        (map['extensionsUsed'] as List<Object>).add('ACME_expression_target');
      } else {
        (map['extensionsUsed'] as List<Object>).add(KHR_NODE_VISIBILITY);
        (node['extensions'] as Map<String, Object>)[KHR_NODE_VISIBILITY] =
            <String, Object>{};
      }
      singleChannel(
          map,
          pointer(target),
          output(map, <num>[0, 1], 'SCALAR', 2,
              componentType: integer ? 5125 : 5121),
          interpolation: 'STEP');
      final root =
          (map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
              as Map<String, Object>;
      (root['expressions'] as List<Object>)
          .add(<String, Object>{'name': 'sameAnimation', 'animation': 0});
      final context = integer
          ? customProperty(target, AnimationPointerValueType.integer)
          : null;
      final valid = await validate(map, context: context, resources: true);
      expect(valid.context.errors, isEmpty, reason: target);
      ((animation(map)['samplers'] as List<Object>)[0]
          as Map<String, Object>)['interpolation'] = 'LINEAR';
      final invalid = await validate(map,
          context: integer
              ? customProperty(target, AnimationPointerValueType.integer)
              : null);
      expect(invalid.context.issues.map((issue) => issue.type),
          contains(LinkError.khrAnimationPointerInvalidInterpolation));
    }
  });

  test('registered extras semantics replace the obsolete blanket ban',
      () async {
    final map = await asset();
    (map['extensionsUsed'] as List<Object>).add('ACME_expression_target');
    ((map['nodes'] as List<Object>)[1] as Map<String, Object>)['extras'] =
        <String, Object>{'response': 0};
    singleChannel(map, pointer('/nodes/1/extras/response'),
        output(map, <num>[0, 1], 'SCALAR', 2));
    final reader = await validate(map,
        context: customProperty(
            '/nodes/1/extras/response', AnimationPointerValueType.float),
        resources: true);
    expect(reader.context.errors, isEmpty);
    expect(reader.context.issues.map((issue) => issue.type),
        isNot(contains(LinkError.khrCharacterExpressionValidationIncomplete)));
  });

  test(
      'unsupported declared target extensions are incomplete, including when required',
      () async {
    for (final required in <bool>[false, true]) {
      final map = await asset();
      (map['extensionsUsed'] as List<Object>).add('ACME_target');
      if (required) map['extensionsRequired'] = <Object>['ACME_target'];
      ((map['nodes'] as List<Object>)[1] as Map<String, Object>)['extensions'] =
          <String, Object>{
        'ACME_target': <String, Object>{'value': 0}
      };
      singleChannel(map, pointer('/nodes/1/extensions/ACME_target/value'),
          output(map, <num>[0, 1], 'SCALAR', 2));
      final reader = await validate(map, resources: true);
      expect(reader.context.errors, isEmpty);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.khrCharacterExpressionValidationIncomplete));
    }
  });

  test(
      'unknown textureInfo owners are incomplete but non-UV paths remain invalid',
      () async {
    final map = await asset();
    (map['extensionsUsed'] as List<Object>).add('ACME_material');
    final material =
        (map['materials'] as List<Object>)[0] as Map<String, Object>;
    material['extensions'] = <String, Object>{
      'ACME_material': <String, Object>{
        'texture': <String, Object>{
          'index': 0,
          'extensions': <String, Object>{
            KHR_TEXTURE_TRANSFORM: <String, Object>{
              'offset': <num>[0, 0]
            }
          }
        },
        'value': 0
      }
    };
    singleChannel(
        map,
        pointer(
            '/materials/0/extensions/ACME_material/texture/extensions/KHR_texture_transform/offset'),
        10,
        classifier: KHR_CHARACTER_EXPRESSION_TEXTURE_TRANSFORM);
    final unknownOwner = await validate(map);
    expect(unknownOwner.context.errors, isEmpty);
    expect(unknownOwner.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionValidationIncomplete));
    singleChannel(
        map, pointer('/materials/0/extensions/ACME_material/value'), 9,
        classifier: KHR_CHARACTER_EXPRESSION_TEXTURE_TRANSFORM);
    final nonUv = await validate(map);
    expect(nonUv.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterInvalidTextureExpressionPointer));
  });

  test('complete arrays and individual elements may overlap across expressions',
      () async {
    final map = await asset();
    singleChannel(map, <String, Object>{'node': 2, 'path': 'weights'}, 9,
        classifier: KHR_CHARACTER_EXPRESSION_MORPHTARGET);
    final second =
        (jsonDecode(jsonEncode(animation(map))) as Map).cast<String, Object>();
    ((second['channels'] as List<Object>)[0] as Map<String, Object>)['target'] =
        pointer('/nodes/2/weights/0');
    final animations = map['animations'] as List<Object>;
    animations.add(second);
    final root =
        (map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
            as Map<String, Object>;
    (root['expressions'] as List<Object>).add(<String, Object>{
      'name': 'element',
      'animation': animations.length - 1,
      'extensions': <String, Object>{
        KHR_CHARACTER_EXPRESSION_MORPHTARGET: <String, Object>{
          'channels': <Object>[0]
        }
      }
    });
    final reader = await validate(map, resources: true);
    expect(reader.context.errors, isEmpty);
  });

  test('unknown entry extensions leave classifier uniqueness incomplete',
      () async {
    final map = await asset();
    (map['extensionsUsed'] as List<Object>).add('ACME_expression_classifier');
    (entry(map)['extensions']
            as Map<String, Object>)['ACME_expression_classifier'] =
        <String, Object>{
      'channels': <Object>[0]
    };
    final reader = await validate(map);
    expect(reader.context.errors, isEmpty);
    expect(reader.context.issues.map((issue) => issue.type),
        contains(LinkError.khrCharacterExpressionValidationIncomplete));
  });

  test(
      'UV classifier rejects missing objects, false owners and scalar type mismatch',
      () async {
    for (final bad in <int>[0, 1, 2]) {
      final map = await asset();
      final material =
          (map['materials'] as List<Object>)[0] as Map<String, Object>;
      final info = (material['pbrMetallicRoughness']
          as Map<String, Object>)['baseColorTexture'] as Map<String, Object>;
      if (bad == 0)
        (info['extensions'] as Map<String, Object>)
            .remove(KHR_TEXTURE_TRANSFORM);
      if (bad == 1) {
        material['extras'] = <String, Object>{
          'extensions': <String, Object>{
            KHR_TEXTURE_TRANSFORM: <String, Object>{
              'offset': <num>[0, 0]
            }
          }
        };
        singleChannel(
            map,
            pointer(
                '/materials/0/extras/extensions/KHR_texture_transform/offset'),
            10,
            classifier: KHR_CHARACTER_EXPRESSION_TEXTURE_TRANSFORM);
      }
      if (bad == 2) {
        singleChannel(
            map,
            pointer(
                '/materials/0/pbrMetallicRoughness/baseColorTexture/extensions/KHR_texture_transform/rotation'),
            10,
            classifier: KHR_CHARACTER_EXPRESSION_TEXTURE_TRANSFORM);
      }
      final reader = await validate(map);
      expect(reader.context.errors, isNotEmpty, reason: '$bad');
    }
  });

  test(
      'blend thresholds warn, custom tokens and self/cyclic/duplicate suppressions are valid',
      () async {
    final map = await asset();
    final root =
        (map['extensions'] as Map<String, Object>)[KHR_CHARACTER_EXPRESSION]
            as Map<String, Object>;
    (root['expressions'] as List<Object>).add(<String, Object>{
      'name': 'B',
      'animation': 0,
      'extensions': <String, Object>{
        KHR_CHARACTER_EXPRESSION_SUPPRESSION: <String, Object>{
          'suppressions': <Object>[
            <String, Object>{'target': 0, 'type': 'block'}
          ]
        }
      }
    });
    (entry(map)['extensions']
            as Map<String, Object>)[KHR_CHARACTER_EXPRESSION_SUPPRESSION] =
        <String, Object>{
      'suppressions': <Object>[
        <String, Object>{'target': 0, 'threshold': 0.4},
        <String, Object>{'target': 1, 'type': 'ACME_custom'},
        <String, Object>{'target': 1, 'type': 'block'},
        <String, Object>{'target': 1, 'type': 'block'}
      ]
    };
    final reader = await validate(map);
    expect(reader.context.errors, isEmpty);
    expect(
        reader.context.issues.where((issue) =>
            issue.type == LinkError.khrCharacterSuppressionIgnoredThreshold),
        hasLength(1));
  });

  test(
      'ancestor conflicts, always and unsupported roles are valid visibility metadata',
      () async {
    for (final ancestor in <String>[
      'first_person',
      'third_person',
      'always',
      'CUSTOM_hidden'
    ]) {
      final map = await asset();
      final nodes = map['nodes'] as List<Object>;
      ((nodes[0] as Map<String, Object>)['extensions']
          as Map<String, Object>)[KHR_NODE_VISIBILITY_HINT] = <String, Object>{
        'role': ancestor
      };
      ((nodes[2] as Map<String, Object>)['extensions']
          as Map<String, Object>)[KHR_NODE_VISIBILITY_HINT] = <String, Object>{
        'role': 'first_person'
      };
      final primitive = (((map['meshes'] as List<Object>)[0]
              as Map<String, Object>)['primitives'] as List<Object>)[0]
          as Map<String, Object>;
      (primitive['extensions']
              as Map<String, Object>)[KHR_MESH_PRIMITIVE_VISIBILITY_HINT] =
          <String, Object>{'role': 'always'};
      (map['extensionsUsed'] as List<Object>).add(KHR_NODE_VISIBILITY);
      ((nodes[2] as Map<String, Object>)['extensions']
          as Map<String, Object>)[KHR_NODE_VISIBILITY] = <String, Object>{
        'visible': false
      };
      final reader = await validate(map);
      expect(reader.context.errors, isEmpty, reason: ancestor);
    }
  });

  test('undefined camera pose from zero scale does not invalidate a hint',
      () async {
    final map = await asset();
    ((map['nodes'] as List<Object>)[0] as Map<String, Object>)['scale'] = <num>[
      0,
      1,
      1
    ];
    final reader = await validate(map);
    expect(reader.context.errors, isEmpty);
  });

  test(
      'relaxed neutral rules retain invalid quaternion and decoded input checks',
      () async {
    final map = await asset();
    singleChannel(map, pointer('/nodes/1/rotation'),
        output(map, <num>[0, 0, 0, 0, 0, 0, 0, 0], 'VEC4', 2),
        classifier: KHR_CHARACTER_EXPRESSION_JOINT);
    final reader = await validate(map, resources: true);
    expect(reader.context.errors, isNotEmpty);
    final inputs = await asset();
    final input = output(inputs, <num>[1, 0], 'SCALAR', 2);
    ((inputs['accessors'] as List<Object>)[input] as Map<String, Object>)
      ..['min'] = <num>[0]
      ..['max'] = <num>[1];
    ((animation(inputs)['samplers'] as List<Object>)[0]
        as Map<String, Object>)['input'] = input;
    final inputReader = await validate(inputs, resources: true);
    expect(inputReader.context.issues.map((issue) => issue.type),
        contains(DataError.accessorAnimationInputNonIncreasing));
  });
}
